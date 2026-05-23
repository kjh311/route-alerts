import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, Icons, Material, BlendMode, TimeOfDay, showTimePicker, Theme, ThemeData, ColorScheme;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_polyline_algorithm/google_polyline_algorithm.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../models/route_model.dart';
import '../core/constants.dart';
import '../widgets/location_search_field.dart';
import '../services/maps_service.dart';
import '../services/google_maps_loader.dart';
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
  
  Map<String, dynamic>? _startData;
  Map<String, dynamic>? _endData;

  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  List<Map<String, dynamic>> _generatedWaypoints = [];
  String _encodedPolyline = '';
  int _totalDistanceMiles = 0;
  int _totalDurationMinutes = 0;
  bool _isGeneratingRoute = false;
  bool _isMapsApiLoaded = !kIsWeb;
  bool _isSaving = false;

  Duration _shiftStartTime = const Duration(hours: 6, minutes: 0);
  double _duration = 11.5;
  int _alertLeadTime = 30;
  List<int> _selectedDays = [];

  final List<String> _daysOfWeek = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final NotificationService _notificationService = NotificationService();
  final List<TextEditingController> _waypointControllers = [];

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
      
      final parts = route.departureTime.split(':');
      if (parts.length >= 2) {
        _shiftStartTime = Duration(hours: int.parse(parts[0]), minutes: int.parse(parts[1]));
      }
      
      if (_generatedWaypoints.isNotEmpty) {
        final lastWp = _generatedWaypoints.last;
        _totalDistanceMiles = lastWp['distance_from_origin_miles'] ?? 0;
        _totalDurationMinutes = (_totalDistanceMiles / 60 * 60).round();
      }
      
      _startData = {
        'description': route.originName,
        'name': route.originName,
        'lat': _generatedWaypoints.isNotEmpty ? _generatedWaypoints.first['lat'] : null,
        'lng': _generatedWaypoints.isNotEmpty ? _generatedWaypoints.first['lng'] : null,
      };
      _endData = {
        'description': route.destinationName,
        'name': route.destinationName,
        'lat': _generatedWaypoints.isNotEmpty ? _generatedWaypoints.last['lat'] : null,
        'lng': _generatedWaypoints.isNotEmpty ? _generatedWaypoints.last['lng'] : null,
      };
      
      final points = _decodeEncodedPolyline(_encodedPolyline);
      if (points.isNotEmpty) {
        _polylines.add(Polyline(
          polylineId: PolylineId('route'),
          points: points,
          color: const Color(0xFFE67E22),
          width: 4,
        ));
      }

      for (var wp in _generatedWaypoints) {
        _waypointControllers.add(TextEditingController(text: wp['name']));
      }

      _updateMarkers();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fitBounds(points);
      });
    }
  }

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    for (var controller in _waypointControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _initMaps() async {
    if (kIsWeb) {
      try {
        await GoogleMapsLoader.ensureLoaded();
        if (mounted) setState(() => _isMapsApiLoaded = true);
      } catch (e) {
        debugPrint('Failed to load Maps API: $e');
      }
    }
  }

  Future<void> _showTimePicker() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _shiftStartTime.inHours, minute: _shiftStartTime.inMinutes % 60),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFE67E22), // Dial selection color
              onPrimary: Colors.white,
              surface: Color(0xFF1A1A1A), // Background
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF1A1A1A),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _shiftStartTime = Duration(hours: picked.hour, minutes: picked.minute));
    }
  }

  void _showAlertLeadPicker() {
    final leadTimes = [15, 30, 45, 60, 90, 120];
    int initialIndex = leadTimes.indexOf(_alertLeadTime);
    if (initialIndex == -1) initialIndex = 1;

    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: 250,
        color: const Color(0xFF1C1C1E),
        child: Column(
          children: [
            SizedBox(
              height: 200,
              child: CupertinoPicker(
                itemExtent: 40,
                scrollController: FixedExtentScrollController(initialItem: initialIndex),
                onSelectedItemChanged: (index) {
                  setState(() => _alertLeadTime = leadTimes[index]);
                },
                children: leadTimes.map((t) => Center(
                  child: Text('$t MINS BEFORE', style: const TextStyle(color: CupertinoColors.white)),
                )).toList(),
              ),
            ),
            CupertinoButton(
              child: const Text('DONE', style: TextStyle(color: Color(0xFFE67E22), fontWeight: FontWeight.bold)),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isViewing = widget.initialRoute != null;
    final timeStr = DateFormat('hh:mm a').format(DateTime(2000, 1, 1, _shiftStartTime.inHours, _shiftStartTime.inMinutes % 60));

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(isViewing ? 'UPDATE ROUTE' : 'CREATE ROUTE', style: const TextStyle(color: CupertinoColors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1A1A1A),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.pop(context),
          child: const Icon(CupertinoIcons.back, color: Color(0xFFE67E22)),
        ),
      ),
      child: SafeArea(
        bottom: true,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isViewing ? 'SAVED HAUL' : 'NEW HAUL PARAMETERS',
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFFE67E22)),
              ),
              const SizedBox(height: 8),
              const Text(
                'Configure your route and monitoring schedule.',
                style: TextStyle(fontSize: 14, color: CupertinoColors.systemGrey),
              ),
              const SizedBox(height: 32),

              _buildCard(
                label: 'Starting Point',
                child: LocationSearchField(
                  controller: _startController,
                  label: 'Origin',
                  icon: CupertinoIcons.location,
                  iconColor: CupertinoColors.systemGrey,
                  hintText: 'Enter origin city',
                  onSelected: (desc, lat, lng) => _handleLocationSelection(true, desc, lat, lng),
                ),
              ),
              const SizedBox(height: 16),
              _buildCard(
                label: 'Destination',
                child: LocationSearchField(
                  controller: _endController,
                  label: 'Destination',
                  icon: CupertinoIcons.flag,
                  iconColor: const Color(0xFFE67E22),
                  hintText: 'Enter destination city',
                  onSelected: (desc, lat, lng) => _handleLocationSelection(false, desc, lat, lng),
                ),
              ),
              const SizedBox(height: 16),

              if (_startData != null && _endData != null) ...[
                if (_isGeneratingRoute)
                  _buildLoadingState()
                else
                  _buildMapPreview(),
                const SizedBox(height: 16),

                if (_generatedWaypoints.isNotEmpty)
                  _buildCard(
                    label: 'Calculated Route Points',
                    child: Column(
                      children: [
                        for (int i = 1; i < _generatedWaypoints.length - 1; i++)
                          _buildWaypointTile(_generatedWaypoints[i], i),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
              ],

              _buildCard(
                label: 'Shift Start Time',
                child: GestureDetector(
                  onTap: _showTimePicker,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF000000),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF333333)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(CupertinoIcons.time, color: Color(0xFFE67E22)),
                        const SizedBox(width: 12),
                        Text(timeStr.toUpperCase(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: CupertinoColors.white)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              _buildCard(
                label: 'Shift Duration',
                headerAction: Text('${_duration.toStringAsFixed(1)} HR', style: const TextStyle(color: Color(0xFFE67E22), fontWeight: FontWeight.bold)),
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Background tick dots for each half hour
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(29, (index) => Container(
                              width: 3,
                              height: 3,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _duration >= (index * 0.5) 
                                  ? const Color(0xFFE67E22).withOpacity(0.5) 
                                  : const Color(0xFF444444),
                              ),
                            )),
                          ),
                        ),
                        // The Slider itself
                        SizedBox(
                          width: double.infinity,
                          child: CupertinoSlider(
                            value: _duration,
                            min: 0,
                            max: 14,
                            divisions: 28,
                            activeColor: const Color(0xFFE67E22),
                            onChanged: (v) => setState(() => _duration = v),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              _buildCard(
                label: 'Alert Lead Time',
                child: GestureDetector(
                  onTap: _showAlertLeadPicker,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF000000),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF333333)),
                    ),
                    child: Row(
                      children: [
                        const Icon(CupertinoIcons.bell_fill, color: Color(0xFFE67E22), size: 20),
                        const SizedBox(width: 12),
                        Text('$_alertLeadTime MINS BEFORE SHIFT', style: const TextStyle(fontWeight: FontWeight.bold, color: CupertinoColors.white)),
                        const Spacer(),
                        const Icon(CupertinoIcons.chevron_down, color: CupertinoColors.systemGrey, size: 16),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              _buildCard(
                label: 'Driving Days',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [1, 2, 3, 4, 5, 6, 7].map((dayNum) => _buildDayChip(dayNum)).toList(),
                ),
              ),
              const SizedBox(height: 48),

              SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  onPressed: _isSaving || _isGeneratingRoute ? null : () => _saveRoute(),
                  child: _isSaving 
                    ? const CupertinoActivityIndicator()
                    : Text(isViewing ? 'UPDATE PARAMETERS' : 'SAVE & ACTIVATE HAUL', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard({required String label, required Widget child, Widget? headerAction}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label.toUpperCase(), style: const TextStyle(color: CupertinoColors.systemGrey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              if (headerAction != null) headerAction,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildDayChip(int dayNum) {
    final dayNames = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    final isSelected = _selectedDays.contains(dayNum);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedDays.remove(dayNum);
          } else {
            _selectedDays.add(dayNum);
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE67E22) : const Color(0xFF000000),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? const Color(0xFFE67E22) : const Color(0xFF333333)),
        ),
        child: Text(
          dayNames[dayNum - 1],
          style: TextStyle(
            color: isSelected ? CupertinoColors.black : CupertinoColors.systemGrey,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildWaypointTile(Map<String, dynamic> wp, int index) {
    if (index >= _waypointControllers.length) {
      _waypointControllers.add(TextEditingController(text: wp['name']));
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: LocationSearchField(
              controller: _waypointControllers[index],
              label: 'Point ${index + 1}',
              icon: CupertinoIcons.location,
              iconColor: CupertinoColors.systemGrey,
              hintText: 'Enter waypoint city',
              onSelected: (desc, lat, lng) {
                setState(() {
                  _generatedWaypoints[index] = {
                    ..._generatedWaypoints[index],
                    'name': desc.split(',').first,
                    'lat': lat ?? _generatedWaypoints[index]['lat'],
                    'lng': lng ?? _generatedWaypoints[index]['lng'],
                  };
                  _updateMarkers();
                });
              },
            ),
          ),
          const SizedBox(width: 8),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => _deleteWaypoint(index),
            child: const Icon(CupertinoIcons.trash, color: CupertinoColors.systemRed, size: 20),
          ),
        ],
      ),
    );
  }

  void _deleteWaypoint(int index) {
    setState(() {
      _generatedWaypoints.removeAt(index);
      if (index < _waypointControllers.length) {
        _waypointControllers[index].dispose();
        _waypointControllers.removeAt(index);
      }
      _updateMarkers();
    });
  }

  Widget _buildMapPreview() {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            if (_isMapsApiLoaded)
              GoogleMap(
                initialCameraPosition: const CameraPosition(target: LatLng(39.8283, -98.5795), zoom: 3),
                onMapCreated: (controller) {
                  _mapController = controller;
                  // If we already have points, fit them now that the controller is ready
                  final points = _decodeEncodedPolyline(_encodedPolyline);
                  if (points.isNotEmpty) {
                    Future.delayed(const Duration(milliseconds: 500), () => _fitBounds(points));
                  }
                },
                markers: _markers,
                polylines: _polylines,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
              )
            else
              const Center(child: CupertinoActivityIndicator()),
            
            if (_totalDistanceMiles > 0)
              Positioned(
                bottom: 12, left: 12, right: 12,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xCC1A1A1A),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('$_totalDistanceMiles MILES', style: const TextStyle(color: Color(0xFFE67E22), fontWeight: FontWeight.bold, fontSize: 12)),
                      Text('${_totalDurationMinutes ~/ 60}H ${_totalDurationMinutes % 60}M', style: const TextStyle(color: CupertinoColors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      height: 180,
      decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(12)),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CupertinoActivityIndicator(radius: 12),
          SizedBox(height: 16),
          Text('OPTIMIZING HAUL ROUTE...', style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _handleLocationSelection(bool isStart, String desc, double? lat, double? lng) {
    setState(() {
      if (isStart) {
        _startData = {'description': desc, 'lat': lat, 'lng': lng, 'name': desc.split(',').first};
      } else {
        _endData = {'description': desc, 'lat': lat, 'lng': lng, 'name': desc.split(',').first};
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
        startName: _startData!['name'],
        endName: _endData!['name'],
      );
      
      _encodedPolyline = result['polyline'] ?? '';
      _generatedWaypoints = List<Map<String, dynamic>>.from(result['waypoints'] ?? []);
      _totalDistanceMiles = (result['total_distance_miles'] as num?)?.toInt() ?? 0;
      _totalDurationMinutes = (result['total_duration_minutes'] as num?)?.toInt() ?? 0;

      // Sync controllers
      for (var controller in _waypointControllers) {
        controller.dispose();
      }
      _waypointControllers.clear();
      for (var wp in _generatedWaypoints) {
        _waypointControllers.add(TextEditingController(text: wp['name']));
      }

      final points = _decodeEncodedPolyline(_encodedPolyline);
      _updateMarkers();
      
      _polylines.clear();
      _polylines.add(Polyline(
        polylineId: PolylineId('route'),
        points: points,
        color: const Color(0xFFE67E22),
        width: 4,
      ));

      setState(() => _isGeneratingRoute = false);
      
      // Increased delay to ensure the map widget has rendered before animating
      if (points.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 800), () => _fitBounds(points));
      }

    } catch (e) {
      setState(() => _isGeneratingRoute = false);
      _showToast('Route generation failed: $e');
    }
  }

  void _updateMarkers() {
    if (_startData?['lat'] == null) return;
    setState(() {
      _markers.clear();
      
      // Origin
      _markers.add(Marker(
        markerId: const MarkerId('start'), 
        position: LatLng(_startData!['lat'], _startData!['lng']),
        infoWindow: InfoWindow(title: 'Origin: ${_startData!['name']}'),
      ));

      // In-between points
      for (int i = 0; i < _generatedWaypoints.length; i++) {
        final wp = _generatedWaypoints[i];
        // Skip adding if it's the very first or very last to avoid overlapping with start/end
        if (i == 0 || i == _generatedWaypoints.length - 1) continue;
        
        _markers.add(Marker(
          markerId: MarkerId('wp_$i'),
          position: LatLng(wp['lat'], wp['lng']),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          infoWindow: InfoWindow(title: wp['name']),
        ));
      }

      // Destination
      if (_endData?['lat'] != null) {
        _markers.add(Marker(
          markerId: const MarkerId('end'), 
          position: LatLng(_endData!['lat'], _endData!['lng']),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: 'Destination: ${_endData!['name']}'),
        ));
      }
    });
  }

  List<LatLng> _decodeEncodedPolyline(String encoded) {
    if (encoded.isEmpty) return [];
    final List<List<num>> coords = decodePolyline(encoded);
    return coords.map((c) => LatLng(c[0].toDouble(), c[1].toDouble())).toList();
  }

  void _fitBounds(List<LatLng> points) async {
    if (points.isEmpty || _mapController == null) return;
    double minLat = points.first.latitude, maxLat = points.first.latitude;
    double minLng = points.first.longitude, maxLng = points.first.longitude;
    for (var p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    await _mapController!.animateCamera(CameraUpdate.newLatLngBounds(
      LatLngBounds(southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng)), 
      kIsWeb ? 20.0 : 60.0 // Adjusted padding for mobile/web
    ));
  }

  Future<void> _saveRoute() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      _showToast('Session expired. Please log in again.');
      return;
    }
    if (_startData == null) {
      _showToast('Please select a valid starting point.');
      return;
    }
    if (_endData == null) {
      _showToast('Please select a valid destination.');
      return;
    }
    if (_selectedDays.isEmpty) {
      _showToast('Please select at least one driving day.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final startTimeStr = '${_shiftStartTime.inHours.toString().padLeft(2, '0')}:${(_shiftStartTime.inMinutes % 60).toString().padLeft(2, '0')}:00';
      
      final routeData = {
        'user_id': userId,
        'origin_name': _startData!['name'],
        'destination_name': _endData!['name'],
        'departure_time': startTimeStr,
        'driving_days': _selectedDays,
        'alert_lead_minutes': _alertLeadTime,
        'shift_duration': (_duration * 60).round(), // Convert hours to total minutes (integer)
        'route_polyline': _encodedPolyline,
        'waypoints': _generatedWaypoints,
        'is_active': true,
      };

      if (widget.initialRoute != null) {
        await Supabase.instance.client.from('routes').update(routeData).eq('id', widget.initialRoute!.id!);
      } else {
        await Supabase.instance.client.from('routes').insert(routeData);
      }

      await NotificationService().refreshScheduledNotifications();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showToast('Failed to save: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showToast(String msg) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('NOTICE'),
        content: Text(msg),
        actions: [CupertinoDialogAction(child: const Text('OK'), onPressed: () => Navigator.pop(context))],
      ),
    );
  }
}
