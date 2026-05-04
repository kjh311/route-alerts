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
    required double shiftDurationHours,
    required int totalDistanceMiles,
  }) async {
    final List<Map<String, dynamic>> waypointAlerts = [];
    String overallStatus = 'Clear';
    String worstHazard = '';

    // Log the audit start
    debugPrint('DEBUG: Starting Window Weather Audit for ${waypoints.length} waypoints');
    debugPrint('DEBUG: Shift Duration: $shiftDurationHours hours');

    for (var wp in waypoints) {
      final double lat = wp['lat'];
      final double lng = wp['lng'];
      
      // 1. Fetch Forecast
      final forecast = await _fetchOneCallForecast(lat, lng);
      if (forecast == null) continue;

      // 2. Audit for hazards across the entire shift window for this location
      final audit = _auditWaypointWindow(wp['name'], forecast, departureTime, shiftDurationHours);
      
      debugPrint('DEBUG: Waypoint ${wp['name']} | Peak Wind: ${audit['peak_wind']} mph at ${audit['peak_time']} | Weather: ${audit['desc']}');

      // Always add the forecast data for the UI
      waypointAlerts.add({
        'city': wp['name'],
        'hazard': audit['hazard'],
        'severity': audit['severity'],
        'icon': audit['icon'],
        'temp': audit['temp'],
        'desc': audit['desc'],
        'peak_wind': audit['peak_wind'],
        'peak_time': audit['peak_time']?.toIso8601String(),
        'lat': lat,
        'lng': lng,
      });

      // Update overall status (Red takes priority over Yellow)
      if (audit['severity'] == 'Red') {
        overallStatus = 'Critical';
        worstHazard = audit['hazard'];
      } else if (audit['severity'] == 'Yellow' && overallStatus != 'Critical') {
        overallStatus = 'Caution';
        if (worstHazard.isEmpty) worstHazard = audit['hazard'];
      }
    }

    return {
      'status': overallStatus,
      'worst_hazard': worstHazard,
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


  Map<String, dynamic> _auditWaypointWindow(String cityName, Map<String, dynamic> data, DateTime startTime, double shiftDurationHours) {
    final hourly = data['hourly'] as List<dynamic>;
    final alerts = data['alerts'] as List<dynamic>?;
    
    final int startSeconds = startTime.millisecondsSinceEpoch ~/ 1000;
    final int endSeconds = startTime.add(Duration(minutes: (shiftDurationHours * 60).round())).millisecondsSinceEpoch ~/ 1000;
    
    // Filter hourly forecasts within the shift window
    final shiftForecasts = hourly.where((h) {
      final dt = h['dt'] as int;
      return dt >= startSeconds && dt <= endSeconds;
    }).toList();
    
    if (shiftForecasts.isEmpty) return _auditWaypointLegacy(cityName, data, startTime);

    String severity = 'Clear';
    String hazard = '';
    double maxWind = 0;
    DateTime? peakWindTime;
    
    // Initial peak values from start of window
    String peakIcon = shiftForecasts.first['weather'][0]['icon'];
    double peakTemp = (shiftForecasts.first['temp'] as num).toDouble();
    String peakDesc = shiftForecasts.first['weather'][0]['description'];

    // 1. Scan for Severe Alerts (Critical Priority)
    if (alerts != null) {
      for (var alert in alerts) {
        final event = (alert['event'] as String).toLowerCase();
        if (event.contains('tornado') || event.contains('hurricane') || event.contains('severe thunderstorm')) {
          severity = 'Red';
          hazard = 'OFFICIAL WARNING: ${alert['event']}';
        }
      }
    }

    // 2. Scan each hour for peak wind and dangerous precipitation
    for (var f in shiftForecasts) {
      final fWind = (f['wind_gust'] ?? f['wind_speed'] ?? 0).toDouble();
      if (fWind > maxWind) {
        maxWind = fWind;
        peakWindTime = DateTime.fromMillisecondsSinceEpoch((f['dt'] as int) * 1000);
        peakIcon = f['weather'][0]['icon'];
        peakTemp = (f['temp'] as num).toDouble();
        peakDesc = f['weather'][0]['description'];
      }
      
      final fDesc = (f['weather'][0]['description'] as String).toLowerCase();
      if (fDesc.contains('ice') || fDesc.contains('sleet') || fDesc.contains('freezing')) {
        severity = 'Red';
        if (!hazard.contains('OFFICIAL')) {
          hazard = 'Icy Conditions Detected';
        }
      }
    }

    // 3. Final Wind Threshold Check
    if (severity != 'Red') {
      if (maxWind > 35) {
        severity = 'Red';
        hazard = 'Critical Wind: ${maxWind.round()}mph';
      } else if (maxWind > 20) {
        severity = 'Yellow';
        hazard = 'Peak Gusts: ${maxWind.round()}mph';
      }
    }

    return {
      'severity': severity, 
      'hazard': hazard,
      'icon': peakIcon,
      'temp': peakTemp,
      'desc': peakDesc,
      'peak_wind': maxWind,
      'peak_time': peakWindTime,
    };
  }

  /// Legacy fallback for out-of-range forecasts
  Map<String, dynamic> _auditWaypointLegacy(String cityName, Map<String, dynamic> data, DateTime time) {
    final current = data['current'];
    return {
      'severity': 'Clear',
      'hazard': '',
      'icon': current['weather'][0]['icon'],
      'temp': (current['temp'] as num).toDouble(),
      'desc': current['weather'][0]['description'],
      'peak_wind': (current['wind_gust'] ?? current['wind_speed'] ?? 0).toDouble(),
      'peak_time': time,
    };
  }
}
