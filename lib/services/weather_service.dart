import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/constants.dart';

class WeatherService {
  final Dio _dio = Dio();
  final String _apiKey = AppConstants.openWeatherApiKey;

  /// Audits a route for hazards at specific ETAs for each waypoint
  Future<Map<String, dynamic>> auditRouteWeather({
    required DateTime departureTime,
    required List<Map<String, dynamic>> waypoints,
    required int totalDurationMinutes,
    required int totalDistanceMiles,
  }) async {
    final List<Map<String, dynamic>> waypointAlerts = [];
    String overallStatus = 'Clear';

    // Log the audit start
    debugPrint('DEBUG: Starting Weather Audit for ${waypoints.length} waypoints');
    debugPrint('DEBUG: Departure Time: $departureTime');

    for (var wp in waypoints) {
      final double lat = wp['lat'];
      final double lng = wp['lng'];
      final int dist = wp['distance_from_origin_miles'];
      
      // 1. Calculate ETA for this waypoint
      // Progress = dist / totalDistance
      final double progress = totalDistanceMiles > 0 ? dist / totalDistanceMiles : 0.0;
      final int offsetMinutes = (progress * totalDurationMinutes).round();
      final DateTime eta = departureTime.add(Duration(minutes: offsetMinutes));
      
      wp['eta'] = eta; // Attach to waypoint for logging/UI
      debugPrint('DEBUG: Waypoint ${wp['name']} | Dist: $dist mi | ETA: $eta');

      // 2. Fetch Forecast
      final forecast = await _fetchOneCallForecast(lat, lng);
      if (forecast == null) continue;

      // 3. Audit for hazards at ETA
      final audit = _auditWaypoint(wp['name'], forecast, eta);
      
      if (audit['severity'] != 'Clear') {
        waypointAlerts.add({
          'city': wp['name'],
          'hazard': audit['hazard'],
          'severity': audit['severity'],
          'lat': lat,
          'lng': lng,
        });

        // Update overall status (Red takes priority over Yellow)
        if (audit['severity'] == 'Red') {
          overallStatus = 'Critical';
        } else if (audit['severity'] == 'Yellow' && overallStatus != 'Critical') {
          overallStatus = 'Caution';
        }
      }
    }

    return {
      'status': overallStatus,
      'last_checked': DateTime.now().toIso8601String(),
      'alerts': waypointAlerts,
    };
  }

  Future<Map<String, dynamic>?> _fetchOneCallForecast(double lat, double lng) async {
    try {
      final response = await _dio.get(
        'https://api.openweathermap.org/data/3.0/onecall',
        queryParameters: {
          'lat': lat,
          'lon': lng,
          'appid': _apiKey,
          'exclude': 'minutely,daily',
          'units': 'imperial',
        },
      );

      if (response.statusCode == 200) {
        return response.data;
      }
    } catch (e) {
      debugPrint('DEBUG: OpenWeather OneCall Error: $e');
    }
    return null;
  }

  Map<String, dynamic> _auditWaypoint(String cityName, Map<String, dynamic> data, DateTime eta) {
    final hourly = data['hourly'] as List<dynamic>;
    final alerts = data['alerts'] as List<dynamic>?;
    
    // Find closest hourly forecast
    final etaSeconds = eta.millisecondsSinceEpoch ~/ 1000;
    final forecast = hourly.firstWhere(
      (h) => (h['dt'] as int) >= etaSeconds,
      orElse: () => hourly.last,
    );

    String severity = 'Clear';
    String hazard = '';

    // 1. Government Alerts (Tornado, Hurricane, Severe Thunderstorm)
    if (alerts != null) {
      for (var alert in alerts) {
        final event = (alert['event'] as String).toLowerCase();
        if (event.contains('tornado') || event.contains('hurricane') || event.contains('severe thunderstorm')) {
          return {'severity': 'Red', 'hazard': 'OFFICIAL WARNING: ${alert['event']}'};
        }
      }
    }

    // 2. Wind Gusts
    final windGust = (forecast['wind_gust'] ?? forecast['wind_speed'] ?? 0).toDouble();
    if (windGust > 35) {
      severity = 'Red';
      hazard = 'Critical Wind Gusts ($windGust mph)';
    } else if (windGust > 20) {
      severity = 'Yellow';
      hazard = 'High Wind Caution ($windGust mph)';
    }

    // 3. Frozen Precipitation (Ice, Sleet, Freezing Rain)
    final weatherDesc = (forecast['weather'][0]['description'] as String).toLowerCase();
    if (weatherDesc.contains('ice') || weatherDesc.contains('sleet') || weatherDesc.contains('freezing')) {
      return {'severity': 'Red', 'hazard': 'Icy Conditions Detected ($weatherDesc)'};
    }

    // 4. Visibility (< 1 mile)
    final visibilityMeters = (forecast['visibility'] ?? 10000).toDouble();
    final visibilityMiles = visibilityMeters / 1609.34;
    if (visibilityMiles < 1.0) {
      if (severity != 'Red') {
        severity = 'Yellow';
        hazard = 'Low Visibility (${visibilityMiles.toStringAsFixed(1)} mi)';
      }
    }

    return {'severity': severity, 'hazard': hazard};
  }
}
