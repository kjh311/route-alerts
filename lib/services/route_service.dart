import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/route_model.dart';

class RouteService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Fetch all routes for the current user
  Future<List<RouteModel>> fetchRoutes() async {
    final userId = _supabase.auth.currentUser!.id;
    final response = await _supabase
        .from('routes')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return (response as List<dynamic>)
        .map((json) => RouteModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Save a new route with user inputs and Google Directions API results
  Future<void> saveRoute({
    required String originName,
    required String destinationName,
    required DateTime departureTime,
    required List<dynamic> waypoints,
    required String routePolyline,
    int alertLeadMinutes = 30,
  }) async {
    final userId = _supabase.auth.currentUser!.id;
    final routeData = {
      'user_id': userId,
      'origin_name': originName,
      'destination_name': destinationName,
      'departure_time': departureTime.toIso8601String(),
      'alert_lead_minutes': alertLeadMinutes,
      'waypoints': waypoints,
      'route_polyline': routePolyline,
      'delay_minutes': 0,
      'weather_condition': 'Clear',
    };

    await _supabase.from('routes').insert(routeData);
  }

  /// Update delay and weather condition for a specific route
  Future<void> updateRouteDelay({
    required String routeId,
    required int delayMinutes,
    required String weatherCondition,
  }) async {
    await _supabase.from('routes').update({
      'delay_minutes': delayMinutes,
      'weather_condition': weatherCondition,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', routeId);
  }
}