import 'package:supabase_flutter/supabase_flutter.dart';

class RouteModel {
  final String? id;
  final String userId;
  final String originName;
  final String destinationName;
  final DateTime departureTime;
  final int alertLeadMinutes;
  final List<dynamic> waypoints;
  final String routePolyline;
  final List<String> drivingDays;
  final int delayMinutes;
  final Map<String, dynamic>? weatherCondition;
  final double shiftDuration;
  final DateTime? updatedAt;
  final DateTime? createdAt;

  RouteModel({
    this.id,
    required this.userId,
    required this.originName,
    required this.destinationName,
    required this.departureTime,
    required this.alertLeadMinutes,
    required this.waypoints,
    required this.routePolyline,
    this.drivingDays = const [],
    this.delayMinutes = 0,
    this.shiftDuration = 11.5,
    this.weatherCondition,
    this.updatedAt,
    this.createdAt,
  });

  factory RouteModel.fromJson(Map<String, dynamic> json) {
    return RouteModel(
      id: json['id'] as String?,
      userId: json['user_id'] as String,
      originName: json['origin_name'] as String,
      destinationName: json['destination_name'] as String,
      departureTime: DateTime.parse(json['departure_time'] as String),
      alertLeadMinutes: json['alert_lead_minutes'] as int,
      waypoints: json['waypoints'] as List<dynamic>,
      routePolyline: json['route_polyline'] as String,
      drivingDays: List<String>.from(json['driving_days'] ?? []),
      delayMinutes: json['delay_minutes'] as int,
      weatherCondition: json['weather_condition'] is Map 
          ? json['weather_condition'] as Map<String, dynamic>
          : { 'status': json['weather_condition']?.toString() ?? 'Clear', 'alerts': [] },
      // DB stores minutes as int, Model uses hours as double
      shiftDuration: ((json['shift_duration'] ?? 690) as int) / 60.0,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
    );
  }

  /// Use this for Database Inserts/Updates
  Map<String, dynamic> toMap() {
    final map = {
      'user_id': userId,
      'origin_name': originName,
      'destination_name': destinationName,
      'departure_time': departureTime.toIso8601String(),
      'alert_lead_minutes': alertLeadMinutes,
      'waypoints': waypoints,
      'route_polyline': routePolyline,
      'driving_days': drivingDays,
      'delay_minutes': delayMinutes,
      'shift_duration': (shiftDuration * 60).round(), // Store as minutes
      'weather_condition': weatherCondition,
    };
    
    // Include ID only if it exists (for updates)
    if (id != null && id!.isNotEmpty) {
      map['id'] = id!;
    }
    
    return map;
  }
}