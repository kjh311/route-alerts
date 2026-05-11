import 'package:google_maps_flutter/google_maps_flutter.dart';

class RouteModel {
  final String? id;
  final String userId;
  final String originName;
  final String destinationName;
  final String departureTime; // Format: 'HH:mm:ss'
  final int alertLeadMinutes;
  final List<dynamic> waypoints;
  final String routePolyline;
  final List<int> drivingDays; // 0 (Mon) - 6 (Sun)
  final int delayMinutes;
  final Map<String, dynamic>? weatherCondition;
  final double shiftDuration;
  final bool isActive;
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
    this.isActive = true,
    this.updatedAt,
    this.createdAt,
  });

  factory RouteModel.fromJson(Map<String, dynamic> json) {
    return RouteModel(
      id: json['id'] as String?,
      userId: json['user_id'] as String,
      originName: json['origin_name'] as String,
      destinationName: json['destination_name'] as String,
      departureTime: json['departure_time'] as String,
      alertLeadMinutes: (json['alert_lead_minutes'] as num?)?.toInt() ?? 30,
      waypoints: json['waypoints'] as List<dynamic>,
      routePolyline: json['route_polyline'] as String,
      drivingDays: (json['driving_days'] as List<dynamic>? ?? [])
          .map((e) => int.tryParse(e.toString()) ?? 0)
          .map((d) => d == 0 ? 1 : d) // Legacy Mon (0) -> ISO Mon (1)
          .where((d) => d >= 1 && d <= 7) // Keep only valid ISO days
          .toSet() // Remove duplicates
          .toList(),
      delayMinutes: (json['delay_minutes'] as num?)?.toInt() ?? 0,
      weatherCondition: json['weather_condition'] is Map 
          ? json['weather_condition'] as Map<String, dynamic>
          : { 'status': json['weather_condition']?.toString() ?? 'Clear', 'alerts': [] },
      shiftDuration: ((json['shift_duration'] ?? 690) as num).toInt() / 60.0,
      isActive: json['is_active'] as bool? ?? true,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
    );
  }

  Map<String, dynamic> toMap() {
    final map = {
      'user_id': userId,
      'origin_name': originName,
      'destination_name': destinationName,
      'departure_time': departureTime,
      'alert_lead_minutes': alertLeadMinutes,
      'waypoints': waypoints,
      'route_polyline': routePolyline,
      'driving_days': drivingDays,
      'delay_minutes': delayMinutes,
      'shift_duration': (shiftDuration * 60).round(),
      'weather_condition': weatherCondition,
      'is_active': isActive,
    };
    
    if (id != null && id!.isNotEmpty) {
      map['id'] = id!;
    }
    
    return map;
  }
}