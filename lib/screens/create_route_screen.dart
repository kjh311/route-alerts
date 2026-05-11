import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_polyline_algorithm/google_polyline_algorithm.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../theme/design_system.dart';
import '../logic/route_cubit.dart';
import '../models/route_model.dart';
import '../core/constants.dart';
import '../widgets/location_search_field.dart';
import '../services/maps_service.dart';
import '../services/google_maps_loader.dart';
import '../services/weather_service.dart';
import '../services/notification_service.dart';

class CreateRouteScreen extends StatefulWidget {
  final RouteModel? initialRoute;
  const CreateRouteScreen({super.key, this.initialRoute});

  @override
  State<CreateRouteScreen> createState() => _CreateRouteScreenState();
}

class _CreateRouteScreenState extends State<CreateRouteScreen> {
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();
  final MapsService _mapsService = MapsService();
  final WeatherService _weatherService = WeatherService();
  
  Map<String, dynamic>? _startData;
  Map<String, dynamic>? _endData;

  // Map related state
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  List<Map<String, dynamic>> _generatedWaypoints = [];
  String _encodedPolyline = '';
  int _totalDistanceMiles = 0;
  int _totalDurationMinutes = 0;
  bool _isGeneratingRoute = false;
  bool _isMapsApiLoaded = !kIsWeb;

  TimeOfDay _startTime = const TimeOfDay(hour: 6, minute: 0);
  double _duration = 11.5;
  int _alertLeadTime = 30;
  List<int> _selectedDays = [];

  final List<String> _daysOfWeek = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final NotificationService _notificationService = NotificationService();

  Future<bool> _ensurePermissions() async {
    // 1. Check Notification Permission
    bool hasNotify = await Permission.notification.isGranted;
    if (!hasNotify) {
      final status = await _notificationService.requestNotificationPermission();
      if (!status) {
        _showPermissionDeniedSnackbar('Notification');
        return false;
      }
    }

    // 2. Check Exact Alarm Permission (Android 13+)
    if (!kIsWeb && Platform.isAndroid) {
      bool hasExact = await _notificationService.requestExactAlarmsPermission();
      if (!hasExact) {
        _showPermissionDeniedSnackbar('Exact Alarm');
        return false;
      }
    }

    return true;
  }

  void _showPermissionDeniedSnackbar(String type) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$type permission is required for shift alerts.'),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'SETTINGS',
          onPressed: () => openAppSettings(),
        ),
      ),
    );
  }

  Future<void> _showPermissionExplanationDialog() async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppDesignSystem.surfaceContainerHigh,
        title: Text('ENABLE ALERTS', style: AppDesignSystem.headlineMedium),
        content: Text(
          'Route Alerts needs permission to send your daily weather and safety summary before your shift.',
          style: AppDesignSystem.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CANCEL', style: TextStyle(color: AppDesignSystem.outline)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: AppDesignSystem.primary),
            child: Text('GRANT ACCESS', style: TextStyle(color: AppDesignSystem.onPrimary)),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _initMaps();
    if (widget.initialRoute != null) {
      final route = widget.initialRoute!;
      _startController.text = route.originName;
      _endController.text = route.destinationName;
      _alertLeadTime = route.alertLeadMinutes;
      _generatedWaypoints = List<Map<String, dynamic>>.from(route.waypoints);
      _encodedPolyline = route.routePolyline;
      _selectedDays = List<int>.from(route.drivingDays);
      _duration = route.shiftDuration;
      
      // Parse departure time string HH:mm:ss
      final parts = route.departureTime.split(':');
      if (parts.length >= 2) {
        _startTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
      
      // Extract stats from waypoints if possible
      if (_generatedWaypoints.isNotEmpty) {
        final lastWp = _generatedWaypoints.last;
        _totalDistanceMiles = lastWp['distance_from_origin_miles'] ?? 0;
        // Estimate duration if not stored: dist / 60mph * 60 min
        _totalDurationMinutes = (_totalDistanceMiles / 60 * 60).round();
      }
      
      // Setup map data
      _startData = {'description': route.originName};
      _endData = {'description': route.destinationName};
      
      // Initialize markers and polylines
      final points = _decodeEncodedPolyline(_encodedPolyline);
      _updateMarkers();


      // Schedule fitBounds after map controller is ready
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Ensure we pass the decoded points to fitBounds
        _fitBounds(points);
      });
    }
  }

  Future<void> _initMaps() async {
    if (kIsWeb) {
      try {
        await GoogleMapsLoader.ensureLoaded();
        if (mounted) setState(() => _isMapsApiLoaded = true);
      } catch (e) {
        debugPrint('DEBUG: Failed to load Maps API: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isViewing = widget.initialRoute != null;

    return BlocProvider(
      create: (context) => RouteCubit(),
      child: BlocConsumer<RouteCubit, RouteState>(
        listener: (context, state) {
          if (state is RouteSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Route saved & activated!')),
            );
            Navigator.pop(context);
          } else if (state is RouteFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: ${state.error}')),
            );
          }
        },
        builder: (context, state) {
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: AppDesignSystem.primary),
              ),
              title: Text(isViewing ? 'VIEW ROUTE' : 'CREATE ROUTE'),
              actions: [
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.more_vert, color: Colors.grey),
                ),
              ],
            ),
            body: ListView(
              padding: const EdgeInsets.symmetric(horizontal: AppDesignSystem.marginEdge),
              children: [
                const SizedBox(height: 24),
                // Header
                Text(isViewing ? 'Saved Dedicated Route' : 'New Dedicated Route', style: AppDesignSystem.headlineLarge.copyWith(color: AppDesignSystem.primaryVariant)),
                Text(isViewing ? 'Monitoring parameters for this haul' : 'Configure your long-haul parameters', style: AppDesignSystem.bodyMedium.copyWith(color: AppDesignSystem.onSurfaceVariant)),
                const SizedBox(height: AppDesignSystem.gutter),

                // Bento Input Section
                _buildBentoCard(
                  label: 'Starting Point',
                  child: LocationSearchField(
                    controller: _startController,
                    label: 'Origin',
                    icon: Icons.location_on,
                    iconColor: AppDesignSystem.secondary,
                    hintText: 'Enter origin city or terminal',
                    onSelected: (desc, lat, lng) {
                      _handleLocationSelection(true, desc, lat, lng);
                    },
                  ),
                ),
                const SizedBox(height: AppDesignSystem.stackGap),
                _buildBentoCard(
                  label: 'Destination',
                  child: LocationSearchField(
                    controller: _endController,
                    label: 'Destination',
                    icon: Icons.flag,
                    iconColor: AppDesignSystem.primary,
                    hintText: 'Enter destination city or port',
                    onSelected: (desc, lat, lng) {
                      _handleLocationSelection(false, desc, lat, lng);
                    },
                  ),
                ),
                const SizedBox(height: AppDesignSystem.stackGap),



                // Map Preview & Route Points (Hidden until both endpoints are set)
                if (_startData != null && _endData != null) ...[
                  if (_isGeneratingRoute)
                    _buildLoadingBento()
                  else
                    _buildMapPreview(),
                  const SizedBox(height: AppDesignSystem.gutter),

                  // Route Points List (Hidden until data is available)
                  if (_generatedWaypoints.isNotEmpty) ...[
                    _buildBentoCard(
                      label: 'Route Points',
                      headerAction: Row(
                        children: [
                          Text('${_generatedWaypoints.length} STOPS FOUND', style: const TextStyle(color: AppDesignSystem.outline, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      child: Column(
                        children: _generatedWaypoints.asMap().entries.map((entry) {
                          final index = entry.key;
                          final wp = entry.value;
                          final isFirst = index == 0;
                          final isLast = index == _generatedWaypoints.length - 1;
                          

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppDesignSystem.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(AppDesignSystem.radiusDefault),
                                border: Border(left: BorderSide(color: isFirst ? AppDesignSystem.secondary : (isLast ? AppDesignSystem.primary : AppDesignSystem.outline), width: 4)),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isFirst ? Icons.location_on : (isLast ? Icons.flag : Icons.circle), 
                                    color: isFirst ? AppDesignSystem.secondary : (isLast ? AppDesignSystem.primary : AppDesignSystem.outline), 
                                    size: 20
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(child: Text(wp['name'], style: AppDesignSystem.bodyLarge)),
                                            if (wp['weather'] != null) ...[
                                              Image.network(
                                                'https://openweathermap.org/img/wn/${wp['weather']['icon']}@2x.png',
                                                width: 24,
                                                height: 24,
                                                errorBuilder: (_, __, ___) => const Icon(Icons.wb_sunny, size: 16),
                                              ),
                                              const SizedBox(width: 4),
                                              Text('${(wp['weather']['temp'] as num).round()}°', 
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                            ],
                                          ],
                                        ),
                                        Row(
                                          children: [
                                            if (!isFirst)
                                              Text('${wp['distance_from_origin_miles']} mi from origin', 
                                                style: TextStyle(fontSize: 10, color: AppDesignSystem.outline.withOpacity(0.8))),
                                            const Spacer(),
                                            if (wp['weather'] != null && wp['weather']['hazard'] != '')
                                              Text(wp['weather']['hazard'], 
                                                style: const TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: AppDesignSystem.gutter),
                  ],
                ],

                // Time and Duration
                _buildBentoCard(
                  label: 'Shift Start Time',
                  child: InkWell(
                    onTap: () => _selectTime(context),
                    child: Container(
                      height: AppDesignSystem.touchTargetMin,
                      decoration: BoxDecoration(
                        color: AppDesignSystem.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(AppDesignSystem.radiusSmall),
                        border: Border.all(color: AppDesignSystem.outline.withOpacity(0.2)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.schedule, color: AppDesignSystem.primary),
                          const SizedBox(width: 8),
                          Text(
                            _startTime.format(context).toUpperCase(),
                            style: AppDesignSystem.headlineMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppDesignSystem.stackGap),
                _buildBentoCard(
                  label: 'Shift Duration',
                  trailingLabel: '${_duration} Hours',
                  child: Column(
                    children: [
                      Slider(
                        value: _duration,
                        min: 0,
                        max: 14,
                        divisions: 28,
                        onChanged: (v) => setState(() => _duration = v),
                      ),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('0H', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppDesignSystem.outline)),
                          Text('7H', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppDesignSystem.outline)),
                          Text('14H', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppDesignSystem.outline)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppDesignSystem.gutter),

                // Alert Lead Time
                _buildBentoCard(
                  label: 'Alert Lead Time',
                  child: Container(
                    height: AppDesignSystem.touchTargetMin,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppDesignSystem.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(AppDesignSystem.radiusSmall),
                    ),
                      child: Row(
                        children: [
                          const Icon(Icons.notifications_active, color: Colors.orange),
                          const Spacer(),
                        DropdownButton<int>(
                          value: _alertLeadTime,
                          underline: const SizedBox(),
                          dropdownColor: AppDesignSystem.surfaceContainerHigh,
                          icon: const Icon(Icons.expand_more, size: 18, color: AppDesignSystem.outline),
                          items: ([15, 30, 45, 50, 60, 90, 120, _alertLeadTime].toSet().toList()..sort()).map((int value) {
                            String label;
                            if (value >= 60) {
                              final h = value ~/ 60;
                              final m = value % 60;
                              label = m == 0 ? '$h ${h == 1 ? 'hour' : 'hours'} before' : '$h hr $m mins before';
                            } else {
                              label = '$value mins before';
                            }
                            return DropdownMenuItem<int>(
                              value: value,
                              child: Text(
                                label,
                                style: const TextStyle(color: AppDesignSystem.primary, fontWeight: FontWeight.bold),
                              ),
                            );
                          }).toList(),
                          onChanged: (v) => setState(() => _alertLeadTime = v!),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppDesignSystem.gutter),

                _buildBentoCard(
                  label: 'Days of the Week',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [1, 2, 3, 4, 5, 6, 7].map((dayNum) {
                      final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                      final dayName = dayNames[dayNum - 1];
                      final isSelected = _selectedDays.contains(dayNum);
                      return FilterChip(
                        label: Text(dayName, style: TextStyle(
                          color: isSelected ? AppDesignSystem.onPrimary : AppDesignSystem.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        )),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedDays.add(dayNum);
                            } else {
                              _selectedDays.remove(dayNum);
                            }
                          });
                        },
                        selectedColor: AppDesignSystem.primary,
                        checkmarkColor: AppDesignSystem.onPrimary,
                        backgroundColor: AppDesignSystem.surfaceContainerLow,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppDesignSystem.radiusSmall),
                          side: BorderSide(color: isSelected ? AppDesignSystem.primary : AppDesignSystem.outline.withOpacity(0.2)),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: AppDesignSystem.gutter),

                const SizedBox(height: 32),
                const SizedBox(height: 32),
                // Save / Update Button
                ElevatedButton(
                  onPressed: state is RouteLoading ? null : () => _saveRoute(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppDesignSystem.primaryVariant,
                    minimumSize: const Size.fromHeight(64),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (state is RouteLoading)
                        const CircularProgressIndicator(color: AppDesignSystem.onPrimary)
                      else ...[
                        const Icon(Icons.save),
                        const SizedBox(width: 12),
                        Text(isViewing ? 'UPDATE ROUTE' : 'SAVE & ACTIVATE ROUTE'),
                      ]
                    ],
                  ),
                ),
                const SizedBox(height: 48),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBentoCard({required String label, String? trailingLabel, required Widget child, Widget? headerAction}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppDesignSystem.surfaceContainer,
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusDefault),
        border: Border.all(color: AppDesignSystem.outline.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label.toUpperCase(), style: AppDesignSystem.labelBold.copyWith(color: AppDesignSystem.outline, letterSpacing: 1.2)),
              if (trailingLabel != null)
                Text(trailingLabel, style: AppDesignSystem.bodyLarge.copyWith(color: AppDesignSystem.primary, fontWeight: FontWeight.bold)),
              if (headerAction != null) headerAction,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }


  InputDecoration _inputDecoration(String hint, IconData icon, Color iconColor) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: iconColor),
    );
  }

  Widget _buildMapPreview() {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(
          color: AppDesignSystem.surfaceContainer,
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusLarge),
          border: Border.all(color: AppDesignSystem.outline.withOpacity(0.2)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            if (_isMapsApiLoaded)
              GoogleMap(
                initialCameraPosition: const CameraPosition(target: LatLng(39.8283, -98.5795), zoom: 3),
                onMapCreated: (controller) {
                  _mapController = controller;
                  // You can set map style here if needed: controller.setMapStyle(_darkMapStyle);
                },
                markers: _markers,
                polylines: _polylines,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
              )
            else
              const Center(child: CircularProgressIndicator(color: AppDesignSystem.primary)),
            if (_generatedWaypoints.isNotEmpty)
              Positioned(
                bottom: 12,
                left: 12,
                right: 12,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppDesignSystem.radiusDefault),
                  child: BackdropFilter(
                    filter: ColorFilter.mode(Colors.black.withOpacity(0.5), BlendMode.darken),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      color: AppDesignSystem.surfaceContainerHigh.withOpacity(0.9),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Total Distance', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppDesignSystem.onSurface)),
                              Text('$_totalDistanceMiles mi', style: AppDesignSystem.headlineLarge.copyWith(color: AppDesignSystem.primary, height: 1)),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Est. Transit', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppDesignSystem.onSurface)),
                              Text('${_totalDurationMinutes ~/ 60}h ${_totalDurationMinutes % 60}m', style: AppDesignSystem.headlineMedium.copyWith(color: AppDesignSystem.secondary, height: 1)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingBento() {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(
          color: AppDesignSystem.surfaceContainer,
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusLarge),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppDesignSystem.primary),
            const SizedBox(height: 16),
            Text('OPTIMIZING HAUL ROUTE...', style: AppDesignSystem.labelBold.copyWith(color: AppDesignSystem.outline)),
            const SizedBox(height: 4),
            const Text('Sampling points and identifying weather stations', style: TextStyle(fontSize: 10, color: AppDesignSystem.outline)),
          ],
        ),
      ),
    );
  }

  void _handleLocationSelection(bool isStart, String desc, double? lat, double? lng) {
    setState(() {
      if (isStart) {
        _startData = {'description': desc, 'lat': lat, 'lng': lng};
      } else {
        _endData = {'description': desc, 'lat': lat, 'lng': lng};
      }
    });

    debugPrint('DEBUG: City selection - Start: ${_startData?['description']} at ${_startData?['lat']},${_startData?['lng']}');
    debugPrint('DEBUG: City selection - End: ${_endData?['description']} at ${_endData?['lat']},${_endData?['lng']}');

    if (_startData != null && _endData != null) {
      _generateRoute();
    }
  }

  Future<void> _generateRoute() async {
    if (_startData?['lat'] == null || _endData?['lat'] == null) return;

    setState(() => _isGeneratingRoute = true);

    try {
      final result = await _mapsService.generateIntelligentWaypoints(
        startLat: _startData!['lat'],
        startLng: _startData!['lng'],
        endLat: _endData!['lat'],
        endLng: _endData!['lng'],
        startName: _startData!['name'],
        endName: _endData!['name'],
      );

      debugPrint('DEBUG: Route Result received: $result');
      
      _encodedPolyline = result['polyline'] ?? '';
      _generatedWaypoints = List<Map<String, dynamic>>.from(result['waypoints'] ?? []);
      _totalDistanceMiles = (result['total_distance_miles'] as num?)?.toInt() ?? 0;
      _totalDurationMinutes = (result['total_duration_minutes'] as num?)?.toInt() ?? 0;

      debugPrint('DEBUG: Parsed stats - Distance: $_totalDistanceMiles, Duration: $_totalDurationMinutes');

      if (_encodedPolyline.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No route found between these locations. Check your API key and connection.')),
        );
      }

      // Update Markers
      _updateMarkers();

      // NEW: Run Weather Audit for these waypoints
      if (_generatedWaypoints.isNotEmpty) {
        final weatherResult = await _weatherService.auditRouteWeather(
          departureTime: DateTime(
            DateTime.now().year,
            DateTime.now().month,
            DateTime.now().day,
            _startTime.hour,
            _startTime.minute,
          ),
          waypoints: _generatedWaypoints,
          shiftDurationHours: _duration,
          totalDistanceMiles: _totalDistanceMiles,
        );
        
        setState(() {
          // Merge weather alerts back into waypoints for display
          final alerts = weatherResult['alerts'] as List<dynamic>;
          for (var i = 0; i < _generatedWaypoints.length; i++) {
            if (i < alerts.length) {
              _generatedWaypoints[i]['weather'] = alerts[i];
            }
          }
        });
      }

      setState(() {
        _isGeneratingRoute = false;
        // Immediate polyline update
        _polylines.clear();
        _polylines.add(Polyline(
          polylineId: const PolylineId('route'),
          points: _decodeEncodedPolyline(_encodedPolyline),
          color: AppDesignSystem.primary,
          width: 5,
        ));
      });
      
      final points = _decodeEncodedPolyline(_encodedPolyline);
      // Give the map a moment to render the polyline before zooming
      Future.delayed(const Duration(milliseconds: 300), () => _fitBounds(points));


    } catch (e) {
      setState(() => _isGeneratingRoute = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Route generation failed: $e')));
    }
  }

  List<LatLng> _decodeEncodedPolyline(String encoded) {
    // Re-use logic or import from utility
    final List<List<num>> coords = decodePolyline(encoded);
    return coords.map((c) => LatLng(c[0].toDouble(), c[1].toDouble())).toList();
  }

  void _fitBounds(List<LatLng> points) async {
    if (points.isEmpty) return;

    // Retry loop to wait for map controller and bounds readiness
    for (int i = 0; i < 5; i++) {
      if (_mapController != null) {
        try {
          LatLngBounds bounds;
          if (points.length == 1) {
            bounds = LatLngBounds(southwest: points.first, northeast: points.first);
          } else {
            double minLat = points.first.latitude;
            double maxLat = points.first.latitude;
            double minLng = points.first.longitude;
            double maxLng = points.first.longitude;

            for (var p in points) {
              if (p.latitude < minLat) minLat = p.latitude;
              if (p.latitude > maxLat) maxLat = p.latitude;
              if (p.longitude < minLng) minLng = p.longitude;
              if (p.longitude > maxLng) maxLng = p.longitude;
            }
            bounds = LatLngBounds(
              southwest: LatLng(minLat, minLng),
              northeast: LatLng(maxLat, maxLng),
            );
          }

          await _mapController!.animateCamera(
            CameraUpdate.newLatLngBounds(bounds, 50.0),
          );
          return; // Success
        } catch (e) {
          debugPrint('DEBUG: fitBounds attempt ${i+1} failed: $e');
        }
      }
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }




  final String _darkMapStyle = '''[]'''; // Placeholder for dark mode JSON


  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (picked != null && picked != _startTime) {
      setState(() {
        _startTime = picked;
      });
    }
  }

  Future<void> _saveRoute(BuildContext context) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please log in first')));
      return;
    }

    final startTimeStr = '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}:00';

    if (_selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select at least one driving day')));
      return;
    }

    // Check permissions first
    final hasNotify = await Permission.notification.isGranted;
    if (!hasNotify) {
      await _showPermissionExplanationDialog();
    }
    
    final permitted = await _ensurePermissions();
    if (!permitted) return;

    final route = RouteModel(
      id: widget.initialRoute?.id,
      userId: userId,
      originName: _startController.text,
      destinationName: _endController.text,
      departureTime: startTimeStr,
      alertLeadMinutes: _alertLeadTime,
      waypoints: _generatedWaypoints,
      routePolyline: _encodedPolyline,
      drivingDays: _selectedDays,
      weatherCondition: null,
      shiftDuration: _duration,
    );

    context.read<RouteCubit>().saveRoute(route);
  }

  void _updateMarkers() {
    setState(() {
      _markers.clear();
      for (int i = 0; i < _generatedWaypoints.length; i++) {
        final wp = _generatedWaypoints[i];
        final isStart = i == 0;
        final isEnd = i == _generatedWaypoints.length - 1;
        
        _markers.add(
          Marker(
            markerId: MarkerId(wp['name'] ?? 'Stop-$i'),
            position: LatLng(
              (wp['lat'] as num?)?.toDouble() ?? 0.0, 
              (wp['lng'] as num?)?.toDouble() ?? 0.0
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              isStart ? BitmapDescriptor.hueGreen : (isEnd ? BitmapDescriptor.hueRed : BitmapDescriptor.hueAzure)
            ),
            infoWindow: InfoWindow(
              title: wp['name'] ?? 'Unknown Stop',
              snippet: isStart ? 'Origin' : (isEnd ? 'Destination' : '${wp['distance_from_origin_miles'] ?? 0} mi from start'),
            ),
          ),
        );
      }
      
      if (_encodedPolyline.isNotEmpty) {
        final points = _decodeEncodedPolyline(_encodedPolyline);
        _polylines.clear();
        _polylines.add(Polyline(
          polylineId: const PolylineId('route'),
          points: points,
          color: AppDesignSystem.primary,
          width: 5,
        ));
      }
    });
  }
}
