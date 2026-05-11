import 'dart:async';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_polyline_algorithm/google_polyline_algorithm.dart';
import 'package:haul_alerts/services/js_stub.dart' if (dart.library.js) 'dart:js' as js;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../core/constants.dart';

class MapsService {
  final Dio _dio = Dio();
  final String _apiKey = AppConstants.googleMapsApiKey;

  /// Main orchestration: Get Directions -> Sample -> Reverse Geocode -> Deduplicate
  Future<Map<String, dynamic>> generateIntelligentWaypoints({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
    String? startName,
    String? endName,
  }) async {
    // 1. Get Directions
    final directions = await _getDirections(startLat, startLng, endLat, endLng);
    if (directions == null) return {'waypoints': [], 'polyline': ''};

    final String encodedPolyline = directions['polyline'];
    final double totalDistanceMeters = (directions['distance_meters'] as num?)?.toDouble() ?? 0.0;
    final double totalDistanceMiles = totalDistanceMeters / 1609.34;

    // 2. Decode Polyline
    final List<LatLng> points = _decodePolyline(encodedPolyline);
    debugPrint('DEBUG: Decoded polyline into ${points.length} points');

    // 3. Determine Sampling Interval (50 miles per user request)
    const double intervalMiles = 50.0;
    final double intervalMeters = intervalMiles * 1609.34;

    // 4. Sample Points along Polyline
    final sampledPoints = _samplePointsAlongPolyline(points, intervalMeters);
    debugPrint('DEBUG: Sampled ${sampledPoints.length} points along route');

    // 5. Reverse Geocode & Deduplicate
    final List<Map<String, dynamic>> waypoints = [];
    final Set<String> seenCities = {};

    // Helper to add a waypoint with proximity and name de-duplication
    Future<void> addWaypoint(double lat, double lng, double distMeters) async {
      try {
        // 1. Try Nearby Search to "snap" to nearest town
        final townData = await _findNearestTownNearby(lat, lng);
        String? cityName = townData?['name'];
        double finalLat = townData != null ? townData['lat'] : lat;
        double finalLng = townData != null ? townData['lng'] : lng;

        if (cityName == null) {
          // Fallback to Geocode
          final cityData = await _getCityFromCoords(lat, lng);
          cityName = cityData?['name'];
        }

        if (cityName != null) {
          // PROXIMITY CHECK: Skip if within 1 mile (1609m) of any existing waypoint
          bool tooClose = false;
          for (var wp in waypoints) {
            double distance = _haversineDistance(LatLng(finalLat, finalLng), LatLng(wp['lat'], wp['lng']));
            if (distance < 1609.34) { 
              tooClose = true;
              break;
            }
          }

          if (!tooClose && !seenCities.contains(cityName)) {
            debugPrint('DEBUG: Adding unique waypoint: $cityName at $finalLat,$finalLng');
            waypoints.add({
              'name': cityName,
              'lat': finalLat,
              'lng': finalLng,
              'distance_from_origin_miles': (distMeters / 1609.34).round(),
            });
            seenCities.add(cityName);
          }
        }
      } catch (e) {
        debugPrint('DEBUG: Error adding waypoint at $lat,$lng: $e');
      }
    }

    // A. Process Start
    await addWaypoint(startLat, startLng, 0.0);

    // B. Process In-Between points
    for (var point in sampledPoints) {
      await addWaypoint(point['lat'], point['lng'], point['distance_from_start']);
    }

    // C. Process End
    await addWaypoint(endLat, endLng, totalDistanceMeters);

    final int totalDistMiles = totalDistanceMiles.isFinite ? totalDistanceMiles.round() : 0;
    final double durationSecs = (directions['duration_seconds'] as num?)?.toDouble() ?? 0.0;
    final int totalDurationMins = (durationSecs / 60).isFinite ? (durationSecs / 60).round() : 0;

    return {
      'waypoints': waypoints,
      'polyline': encodedPolyline,
      'total_distance_miles': totalDistMiles,
      'total_duration_minutes': totalDurationMins,
    };
  }

  Future<Map<String, dynamic>?> _findNearestTownNearby(double lat, double lng) async {
    const double radiusMeters = 32186.9; // 20 miles
    final apiKey = kIsWeb ? _apiKey : (dotenv.env['ANDROID_MAPS_KEY'] ?? _apiKey);

    try {
      final response = await _dio.get(
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json',
        queryParameters: {
          'location': '$lat,$lng',
          'radius': radiusMeters.toString(),
          'type': 'locality',
          'key': apiKey,
        },
        options: Options(
          headers: {
            'X-Android-Package': 'com.jh311.haul_alerts',
            'X-Android-Cert': '86A5EF10AE192D3097FBFD6478648A862CC9E909',
          },
        ),
      );

      if (response.data['status'] == 'OK' && (response.data['results'] as List).isNotEmpty) {
        final result = response.data['results'][0];
        return {
          'name': result['name'],
          'lat': result['geometry']['location']['lat'],
          'lng': result['geometry']['location']['lng'],
        };
      }
    } catch (e) {
      debugPrint('DEBUG: Nearby Search failed: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> _getDirections(double startLat, double startLng, double endLat, double endLng) async {
    if (kIsWeb) {
      return await _getDirectionsWeb(startLat, startLng, endLat, endLng);
    } else {
      return await _getDirectionsMobile(startLat, startLng, endLat, endLng);
    }
  }

  Future<Map<String, dynamic>?> _getDirectionsWeb(double startLat, double startLng, double endLat, double endLng) async {
    final completer = Completer<Map<String, dynamic>?>();
    
    js.context.callMethod('eval', ["""
      (function(sLat, sLng, eLat, eLng) {
        var directionsService = new google.maps.DirectionsService();
        var request = {
          origin: new google.maps.LatLng(sLat, sLng),
          destination: new google.maps.LatLng(eLat, eLng),
          travelMode: 'DRIVING'
        };
        directionsService.route(request, function(result, status) {
          if (status == 'OK') {
            var route = result.routes[0];
            var leg = route.legs[0];
            window.onGoogleDirectionsSuccess(
              route.overview_polyline,
              leg.distance.value,
              leg.duration.value
            );
          } else {
            window.onGoogleDirectionsFailure(status);
          }
        });
      })($startLat, $startLng, $endLat, $endLng)
    """]);

    js.context['onGoogleDirectionsSuccess'] = js.allowInterop((polyline, distance, duration) {
      completer.complete({
        'polyline': polyline as String,
        'distance_meters': (distance as num).toInt(),
        'duration_seconds': (duration as num).toInt(),
      });
    });

    js.context['onGoogleDirectionsFailure'] = js.allowInterop((status) {
      debugPrint('DEBUG: Directions API Failed: $status');
      completer.complete(null);
    });

    return completer.future;
  }

  Future<Map<String, dynamic>?> _getDirectionsMobile(double startLat, double startLng, double endLat, double endLng) async {
    final String apiKey = dotenv.env['ANDROID_MAPS_KEY'] ?? _apiKey;
    
    final response = await _dio.get(
      'https://maps.googleapis.com/maps/api/directions/json',
      queryParameters: {
        'origin': '$startLat,$startLng',
        'destination': '$endLat,$endLng',
        'key': apiKey,
        'mode': 'driving',
      },
      options: Options(
        headers: {
          'X-Android-Package': 'com.jh311.haul_alerts',
          'X-Android-Cert': '86A5EF10AE192D3097FBFD6478648A862CC9E909',
        },
      ),
    );

    debugPrint('DEBUG: Directions API Full Response: ${response.data}');

    final String status = response.data['status'] ?? 'UNKNOWN';

    if (status == 'OK' && (response.data['routes'] as List).isNotEmpty) {
      final route = response.data['routes'][0];
      final legs = route['legs'] as List?;
      if (legs == null || legs.isEmpty) return null;
      
      final leg = legs[0];
      debugPrint('DEBUG: Directions Leg Data: $leg');
      
      return {
        'polyline': route['overview_polyline']['points'],
        'distance_meters': (leg['distance']?['value'] as num?)?.toInt() ?? 0,
        'duration_seconds': (leg['duration']?['value'] as num?)?.toInt() ?? 0,
      };
    } else {
      final String status = response.data['status'] ?? 'UNKNOWN';
      final String errorMessage = response.data['error_message'] ?? 'Check Google Cloud Console for billing and API activation.';
      
      debugPrint('CRITICAL: Directions API Failure');
      debugPrint('STATUS: $status');
      debugPrint('MESSAGE: $errorMessage');
      
      // We throw the specific message so the UI can display it in a snackbar
      throw 'Directions API Error ($status): $errorMessage';
    }
  }

  Future<Map<String, dynamic>?> _getCityFromCoords(double lat, double lng) async {
    if (kIsWeb) {
      return await _getCityFromCoordsWeb(lat, lng);
    } else {
      return await _getCityFromCoordsMobile(lat, lng);
    }
  }

  Future<Map<String, dynamic>?> _getCityFromCoordsWeb(double lat, double lng) async {
    final completer = Completer<Map<String, dynamic>?>();

    js.context.callMethod('eval', ["""
      (function(lat, lng) {
        var geocoder = new google.maps.Geocoder();
        var latlng = { lat: lat, lng: lng };
        geocoder.geocode({ location: latlng }, function(results, status) {
          if (status === 'OK' && results[0]) {
            var cityName = '';
            var stateCode = '';
            var components = results[0].address_components;
            for (var i = 0; i < components.length; i++) {
              var types = components[i].types;
              if (types.indexOf('locality') !== -1) {
                cityName = components[i].long_name;
              } else if (types.indexOf('administrative_area_level_1') !== -1) {
                stateCode = components[i].short_name;
              }
            }
            window.onGoogleGeocodeSuccess(cityName + (stateCode ? ', ' + stateCode : ''));
          } else {
            window.onGoogleGeocodeFailure(status);
          }
        });
      })($lat, $lng)
    """]);

    js.context['onGoogleGeocodeSuccess'] = js.allowInterop((cityState) {
      final cityStr = cityState?.toString() ?? '';
      completer.complete(cityStr.isNotEmpty ? {'name': cityStr} : null);
    });

    js.context['onGoogleGeocodeFailure'] = js.allowInterop((status) {
      completer.complete(null);
    });

    return completer.future;
  }

  Future<Map<String, dynamic>?> _getCityFromCoordsMobile(double lat, double lng) async {
    final String apiKey = dotenv.env['ANDROID_MAPS_KEY'] ?? _apiKey;
    
    final response = await _dio.get(
      'https://maps.googleapis.com/maps/api/geocode/json',
      queryParameters: {
        'latlng': '$lat,$lng',
        'key': apiKey,
        'result_type': 'locality|neighborhood|sublocality|administrative_area_level_1',
      },
      options: Options(
        headers: {
          'X-Android-Package': 'com.jh311.haul_alerts',
          'X-Android-Cert': '86A5EF10AE192D3097FBFD6478648A862CC9E909',
        },
      ),
    );

    if (response.data['status'] == 'OK' && (response.data['results'] as List).isNotEmpty) {
      final results = response.data['results'] as List;
      String cityName = '';
      
      // LOGIC: Scan all results to find an actual city/town/postal area
      for (var res in results) {
        final components = res['address_components'] as List;
        for (var component in components) {
          final List cTypes = component['types'];
          
          // BROADENED: Include cities, towns, and postal municipalities
          if (cTypes.contains('locality') || 
              cTypes.contains('sublocality_level_1') || 
              cTypes.contains('administrative_area_level_3') ||
              cTypes.contains('postal_town')) {
            cityName = component['long_name'];
            break; 
          }
        }
        
        if (cityName.isNotEmpty) break;
      }
      
      // FALLBACK: If still nothing, try to find the street address or a specific point of interest
      if (cityName.isEmpty) {
        for (var res in results) {
          final types = res['types'] as List;
          if (!types.contains('administrative_area_level_1') && !types.contains('country')) {
             cityName = res['address_components'][0]['long_name'];
             break;
          }
        }
      }
      
      debugPrint('DEBUG: Geocoded $lat,$lng to $cityName');
      return cityName.isNotEmpty ? {'name': cityName} : null;
    } else {
      debugPrint('DEBUG: Geocode status: ${response.data['status']}');
    }
    return null;
  }

  List<LatLng> _decodePolyline(String encoded) {
    final List<List<num>> coords = decodePolyline(encoded);
    return coords.map((c) => LatLng(c[0].toDouble(), c[1].toDouble())).toList();
  }

  List<Map<String, dynamic>> _samplePointsAlongPolyline(List<LatLng> points, double intervalMeters) {
    final List<Map<String, dynamic>> sampled = [];
    double accumulatedDistance = 0.0;
    double nextTargetDistance = intervalMeters;

    sampled.add({
      'lat': points.first.latitude,
      'lng': points.first.longitude,
      'distance_from_start': 0.0,
    });

    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      final dist = _haversineDistance(p1, p2);

      while (accumulatedDistance + dist >= nextTargetDistance) {
        final ratio = (nextTargetDistance - accumulatedDistance) / dist;
        final lat = p1.latitude + (p2.latitude - p1.latitude) * ratio;
        final lng = p1.longitude + (p2.longitude - p1.longitude) * ratio;
        
        sampled.add({
          'lat': lat,
          'lng': lng,
          'distance_from_start': nextTargetDistance,
        });
        
        nextTargetDistance += intervalMeters;
      }
      accumulatedDistance += dist;
    }

    return sampled;
  }

  double _haversineDistance(LatLng p1, LatLng p2) {
    const r = 6371000;
    final dLat = _degToRad(p2.latitude - p1.latitude);
    final dLng = _degToRad(p2.longitude - p1.longitude);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(p1.latitude)) * cos(_degToRad(p2.latitude)) * sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  double _degToRad(double deg) => deg * (pi / 180);
}
