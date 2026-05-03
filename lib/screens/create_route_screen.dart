import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_polyline_algorithm/google_polyline_algorithm.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/design_system.dart';
import '../logic/route_cubit.dart';
import '../models/route_model.dart';
import '../core/constants.dart';
import '../widgets/location_search_field.dart';
import '../services/maps_service.dart';
import '../services/google_maps_loader.dart';

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

  @override
  void initState() {
    super.initState();
    _initMaps();
    if (widget.initialRoute != null) {
      final route = widget.initialRoute!;
      _startController.text = route.originName;
      _endController.text = route.destinationName;
      _startTime = TimeOfDay.fromDateTime(route.departureTime);
      _alertLeadTime = route.alertLeadMinutes;
      _generatedWaypoints = List<Map<String, dynamic>>.from(route.waypoints);
      _encodedPolyline = route.routePolyline;
      
      // Setup map data
      _startData = {'description': route.originName};
      _endData = {'description': route.destinationName};
      
      // Initialize markers and polylines
      final points = _decodeEncodedPolyline(_encodedPolyline);
      _polylines.add(Polyline(
        polylineId: const PolylineId('route'),
        points: points,
        color: AppDesignSystem.primary,
        width: 6,
      ));

      for (var wp in _generatedWaypoints) {
        _markers.add(Marker(
          markerId: MarkerId(wp['name']),
          position: LatLng(wp['lat'], wp['lng']),
          infoWindow: InfoWindow(title: wp['name']),
        ));
      }

      // Schedule fitBounds after map controller is ready
      WidgetsBinding.instance.addPostFrameCallback((_) {
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
                const SizedBox(height: AppDesignSystem.gutter),

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
                      headerAction: Text('${_generatedWaypoints.length} STOPS FOUND', style: const TextStyle(color: AppDesignSystem.outline, fontSize: 10, fontWeight: FontWeight.bold)),
                      child: Column(
                        children: _generatedWaypoints.asMap().entries.map((entry) {
                          final index = entry.key;
                          final wp = entry.value;
                          final isFirst = index == 0;
                          final isLast = index == _generatedWaypoints.length - 1;
                          
                          Color accentColor = AppDesignSystem.outline;
                          IconData icon = Icons.circle;
                          if (isFirst) {
                            accentColor = AppDesignSystem.secondary;
                            icon = Icons.location_on;
                          } else if (isLast) {
                            accentColor = AppDesignSystem.primary;
                            icon = Icons.flag;
                          }

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppDesignSystem.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(AppDesignSystem.radiusDefault),
                                border: Border(left: BorderSide(color: accentColor, width: 4)),
                              ),
                              child: Row(
                                children: [
                                  Icon(icon, color: accentColor, size: 20),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(wp['name'], style: AppDesignSystem.bodyLarge),
                                        if (!isFirst)
                                          Text('${wp['distance_from_origin_miles']} miles from origin', 
                                            style: TextStyle(fontSize: 10, color: AppDesignSystem.outline.withOpacity(0.8))),
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
                          items: [15, 30, 45, 60].map((int value) {
                            return DropdownMenuItem<int>(
                              value: value,
                              child: Text(
                                value == 60 ? '1 hour before' : '$value mins before',
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

                const SizedBox(height: 32),
                // Save Button (Hidden in View mode)
                if (!isViewing)
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
                          const Text('SAVE & ACTIVATE ROUTE'),
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
      );

      _encodedPolyline = result['polyline'];
      _generatedWaypoints = List<Map<String, dynamic>>.from(result['waypoints']);
      _totalDistanceMiles = result['total_distance_miles'];
      _totalDurationMinutes = result['total_duration_minutes'];

      // Update Markers
      _markers.clear();
      for (var wp in _generatedWaypoints) {
        _markers.add(
          Marker(
            markerId: MarkerId(wp['name']),
            position: LatLng(wp['lat'], wp['lng']),
            infoWindow: InfoWindow(title: wp['name'], snippet: '${wp['distance_from_origin_miles']} mi from start'),
          ),
        );
      }

      // Update Polyline
      _polylines.clear();
      // Decode for polyline widget
      final List<LatLng> polyPoints = _decodeEncodedPolyline(_encodedPolyline);
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: polyPoints,
          color: AppDesignSystem.primary,
          width: 5,
        ),
      );

      setState(() => _isGeneratingRoute = false);
      
      // Fit Bounds
      Future.delayed(const Duration(milliseconds: 500), () => _fitBounds(polyPoints));

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

  void _saveRoute(BuildContext context) {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please log in first')));
      return;
    }

    final startTimeStr = '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}:00';

    final departureTime = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
      _startTime.hour,
      _startTime.minute,
    );

    final route = RouteModel(
      userId: userId,
      originName: _startController.text,
      destinationName: _endController.text,
      departureTime: departureTime,
      alertLeadMinutes: _alertLeadTime,
      waypoints: _generatedWaypoints,
      routePolyline: _encodedPolyline,
    );

    context.read<RouteCubit>().saveRoute(route);
  }
}
