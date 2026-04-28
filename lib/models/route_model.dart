import 'package:supabase_flutter/supabase_flutter.dart';

class RouteModel {
  final String id;
  final String userId;
  final String originName;
  final String destinationName;
  final DateTime departureTime;
  final int alertLeadMinutes;
  final List<dynamic> waypoints;
  final String routePolyline;
  final int delayMinutes;
  final String weatherCondition;
  final DateTime updatedAt;

  RouteModel({
    required this.id,
    required this.userId,
    required this.originName,
    required this.destinationName,
    required this.departureTime,
    required this.alertLeadMinutes,
    required this.waypoints,
    required this.routePolyline,
    required this.delayMinutes,
    required this.weatherCondition,
    required this.updatedAt,
  });

  factory RouteModel.fromJson(Map<String, dynamic> json) {
    return RouteModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      originName: json['origin_name'] as String,
      destinationName: json['destination_name'] as String,
      departureTime: DateTime.parse(json['departure_time'] as String),
      alertLeadMinutes: json['alert_lead_minutes'] as int,
      waypoints: json['waypoints'] as List<dynamic>,
      routePolyline: json['route_polyline'] as String,
      delayMinutes: json['delay_minutes'] as int,
      weatherCondition: json['weather_condition'] as String,
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'origin_name': originName,
      'destination_name': destinationName,
      'departure_time': departureTime.toIso8601String(),
      'alert_lead_minutes': alertLeadMinutes,
      'waypoints': waypoints,
      'route_polyline': routePolyline,
      'delay_minutes': delayMinutes,
      'weather_condition': weatherCondition,
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}