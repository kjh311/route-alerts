import 'dart:async';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_polyline_algorithm/google_polyline_algorithm.dart';
import 'dart:js' as js;
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
  }) async {
    // 1. Get Directions
    final directions = await _getDirections(startLat, startLng, endLat, endLng);
    if (directions == null) return {'waypoints': [], 'polyline': ''};

    final String encodedPolyline = directions['polyline'];
    final double totalDistanceMeters = directions['distance_meters'].toDouble();
    final double totalDistanceMiles = totalDistanceMeters / 1609.34;

    // 2. Decode Polyline
    final List<LatLng> points = _decodePolyline(encodedPolyline);

    // 3. Determine Sampling Interval (40 miles for < 200mi, 75 miles otherwise)
    final double intervalMiles = totalDistanceMiles < 200 ? 40.0 : 75.0;
    final double intervalMeters = intervalMiles * 1609.34;

    // 4. Sample Points along Polyline
    final sampledPoints = _samplePointsAlongPolyline(points, intervalMeters);

    // 5. Reverse Geocode & Deduplicate
    final List<Map<String, dynamic>> waypoints = [];
    final Set<String> seenCities = {};

    for (var i = 0; i < sampledPoints.length; i++) {
      final point = sampledPoints[i];
      final cityData = await _getCityFromCoords(point['lat'], point['lng']);
      
      if (cityData != null) {
        final cityName = cityData['name'];
        if (!seenCities.contains(cityName)) {
          waypoints.add({
            'name': cityName,
            'lat': point['lat'],
            'lng': point['lng'],
            'distance_from_origin_miles': (point['distance_from_start'] / 1609.34).round(),
          });
          seenCities.add(cityName);
        }
      }
    }

    return {
      'waypoints': waypoints,
      'polyline': encodedPolyline,
      'total_distance_miles': totalDistanceMiles.round(),
      'total_duration_minutes': (directions['duration_seconds'] / 60).round(),
    };
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

    js.context['onGoogleDirectionsSuccess'] = (String polyline, int distance, int duration) {
      completer.complete({
        'polyline': polyline,
        'distance_meters': distance,
        'duration_seconds': duration,
      });
    };

    js.context['onGoogleDirectionsFailure'] = (String status) {
      debugPrint('DEBUG: Directions API Failed: $status');
      completer.complete(null);
    };

    return completer.future;
  }

  Future<Map<String, dynamic>?> _getDirectionsMobile(double startLat, double startLng, double endLat, double endLng) async {
    final response = await _dio.get(
      'https://maps.googleapis.com/maps/api/directions/json',
      queryParameters: {
        'origin': '$startLat,$startLng',
        'destination': '$endLat,$endLng',
        'key': _apiKey,
        'mode': 'driving',
      },
    );

    if (response.data['status'] == 'OK') {
      final route = response.data['routes'][0];
      final leg = route['legs'][0];
      return {
        'polyline': route['overview_polyline']['points'],
        'distance_meters': leg['distance']['value'],
        'duration_seconds': leg['duration']['value'],
      };
    }
    return null;
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
            var components = results[0].address_components;
            for (var i = 0; i < components.length; i++) {
              var types = components[i].types;
              if (types.indexOf('locality') !== -1) {
                cityName = components[i].long_name;
                break;
              } else if (types.indexOf('administrative_area_level_2') !== -1) {
                cityName = components[i].long_name;
              }
            }
            window.onGoogleGeocodeSuccess(cityName);
          } else {
            window.onGoogleGeocodeFailure(status);
          }
        });
      })($lat, $lng)
    """]);

    js.context['onGoogleGeocodeSuccess'] = (String cityName) {
      completer.complete(cityName.isNotEmpty ? {'name': cityName} : null);
    };

    js.context['onGoogleGeocodeFailure'] = (String status) {
      completer.complete(null);
    };

    return completer.future;
  }

  Future<Map<String, dynamic>?> _getCityFromCoordsMobile(double lat, double lng) async {
    final response = await _dio.get(
      'https://maps.googleapis.com/maps/api/geocode/json',
      queryParameters: {
        'latlng': '$lat,$lng',
        'key': _apiKey,
        'result_type': 'locality|sublocality|administrative_area_level_2',
      },
    );

    if (response.data['status'] == 'OK' && (response.data['results'] as List).isNotEmpty) {
      final result = response.data['results'][0];
      String cityName = '';
      
      for (var component in result['address_components']) {
        final List types = component['types'];
        if (types.contains('locality')) {
          cityName = component['long_name'];
          break;
        } else if (types.contains('administrative_area_level_2')) {
          cityName = component['long_name'];
        }
      }
      
      return cityName.isNotEmpty ? {'name': cityName} : null;
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
