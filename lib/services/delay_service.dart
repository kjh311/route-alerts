import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';
import 'maps_service.dart';

class DelayService {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));
  
  final MapsService _mapsService = MapsService();
  final SupabaseClient _supabase = Supabase.instance.client;
  final String _apiKey = AppConstants.googleMapsApiKey;

  /// Orchestrates the dual-direction evaluation and persistence check
  Future<Map<String, dynamic>> evaluateRouteDelayPipeline({
    required String routeId,
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
    required DateTime shiftStart,
  }) async {
    try {
      // 1. Dual-Direction Parallel Requests
      final results = await Future.wait([
        _mapsService.generateIntelligentWaypoints(
          startLat: startLat, startLng: startLng, 
          endLat: endLat, endLng: endLng
        ),
        _mapsService.generateIntelligentWaypoints(
          startLat: endLat, startLng: endLng, // Inverse Direction
          endLat: startLat, endLng: startLng
        ),
      ]);

      final forwardData = results[0];
      final reverseData = results[1];

      // 2. Process Detected Incidents (Example logic for pulling from Google or DOT)
      // For this pipe, we simulate the detection of incidents from a 511/DOT Feed provider
      final List<Map<String, dynamic>> rawIncidents = await _fetchDetectedIncidents(forwardData['polyline']);
      final List<Map<String, dynamic>> processedIncidents = [];

      for (var incident in rawIncidents) {
        // A. Bearing & Heading Calculation
        final double bearing = _calculateBearing(
          LatLng(incident['lat'], incident['lng']), 
          LatLng(incident['lat_end'] ?? incident['lat'] + 0.01, incident['lng_end'] ?? incident['lng'])
        );
        final String heading = _getHeading(bearing);

        // B. Mile Marker Resolution via SNAP-TO-ROAD
        final mileMarkerData = await _resolveMileMarker(
          lat: incident['lat'], 
          lng: incident['lng'], 
          heading: heading
        );

        // C. Historical Comparison (Yesterday's Time-Window Aggregation)
        final bool isPersistent = await _checkPersistence(
          routeId: routeId,
          shiftStart: shiftStart,
          highway: mileMarkerData['highway'],
          mileMarker: mileMarkerData['marker'],
          heading: heading,
        );

        processedIncidents.add({
          ...incident,
          'heading': heading,
          'bearing': bearing,
          'mile_marker': mileMarkerData['marker'],
          'highway': mileMarkerData['highway'],
          'is_persistent': isPersistent,
          'is_new': !isPersistent,
          'description': '${mileMarkerData['highway']} $heading, MM ${mileMarkerData['marker']}: ${incident['summary']}',
        });
      }

      return {
        'forward_total_delay': forwardData['total_duration_minutes'], // In a real app, this would be compared to base time
        'reverse_total_delay': reverseData['total_duration_minutes'],
        'incidents': processedIncidents,
        'timestamp': DateTime.now().toIso8601String(),
      };

    } catch (e) {
      debugPrint('CRITICAL: Delay Pipeline Failed: $e');
      rethrow;
    }
  }

  /// Calculates the bearing between two coordinates
  double _calculateBearing(LatLng start, LatLng end) {
    final double lat1 = start.latitude * pi / 180;
    final double lon1 = start.longitude * pi / 180;
    final double lat2 = end.latitude * pi / 180;
    final double lon2 = end.longitude * pi / 180;

    final double dLon = lon2 - lon1;
    final double y = sin(dLon) * cos(lat2);
    final double x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);
    final double bearing = atan2(y, x) * 180 / pi;
    return (bearing + 360) % 360;
  }

  /// Maps bearing degrees to textual cardinal directions
  String _getHeading(double bearing) {
    if (bearing >= 315 || bearing < 45) return 'Northbound';
    if (bearing >= 45 && bearing < 135) return 'Eastbound';
    if (bearing >= 135 && bearing < 225) return 'Southbound';
    if (bearing >= 225 && bearing < 315) return 'Westbound';
    return 'Unknown';
  }

  /// Resolves coordinates to highway mile markers using Google Roads & Fallback logic
  Future<Map<String, dynamic>> _resolveMileMarker({
    required double lat,
    required double lng,
    required String heading,
  }) async {
    try {
      // 1. Use Roads API for Snap-to-Road
      final response = await _dio.get(
        'https://roads.googleapis.com/v1/snapToRoads',
        queryParameters: {
          'path': '$lat,$lng',
          'interpolate': 'true',
          'key': _apiKey,
        },
      );

      final snappedPoints = response.data['snappedPoints'] as List?;
      if (snappedPoints != null && snappedPoints.isNotEmpty) {
        // In a real environment, we would use the placeId to query a DOT database
        // For now, we simulate the MM resolution from current coords
        // Usually: (Current Lat/Lng matched against static Highway Nodes with MM attributes)
        return {
          'highway': 'I-40', // Hardcoded example for logic proof
          'marker': 120 + (Random().nextInt(10)), // Mocked marker
        };
      }
    } catch (e) {
      debugPrint('WARNING: Mile Marker resolution failed: $e');
    }
    return {'highway': 'Unknown Road', 'marker': 0};
  }

  /// Checks if an incident existed yesterday in the same time window
  Future<bool> _checkPersistence({
    required String routeId,
    required DateTime shiftStart,
    required String highway,
    required int mileMarker,
    required String heading,
  }) async {
    final yesterday = shiftStart.subtract(const Duration(hours: 24));
    final windowStart = yesterday.subtract(const Duration(hours: 1));
    final windowEnd = yesterday.add(const Duration(hours: 1));

    try {
      // Logic: Query Route Audits/Logs for overlaps
      // Note: This assumes a 'route_audits' table exists that logs historical findings
      final response = await _supabase
          .from('route_audits')
          .select('incident_data')
          .eq('route_id', routeId)
          .gte('created_at', windowStart.toIso8601String())
          .lte('created_at', windowEnd.toIso8601String());

      if (response != null && (response as List).isNotEmpty) {
        for (var audit in response) {
          final incidents = audit['incident_data'] as List?;
          if (incidents == null) continue;
          
          for (var inc in incidents) {
            if (inc['highway'] == highway && 
                inc['mile_marker'] == mileMarker && 
                inc['heading'] == heading) {
              return true; // Match found from yesterday
            }
          }
        }
      }
    } catch (e) {
      debugPrint('WARNING: Persistence check failed: $e');
    }
    return false;
  }

  /// Mock for DOT/511 Incident feed acquisition
  Future<List<Map<String, dynamic>>> _fetchDetectedIncidents(String polyline) async {
    // In production, this would call a TIBCO or JSON feed from a 511 system
    return [
      {
        'lat': 35.1067,
        'lng': -106.6056,
        'summary': 'Roadwork',
        'type': 'Construction',
      }
    ];
  }
}
