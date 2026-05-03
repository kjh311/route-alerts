import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/route_model.dart';

abstract class RouteState {}

class RouteInitial extends RouteState {}

class RouteLoading extends RouteState {}

class RouteSuccess extends RouteState {}

class RouteFailure extends RouteState {
  final String error;
  RouteFailure(this.error);
}

class RouteCubit extends Cubit<RouteState> {
  final SupabaseClient _supabase = Supabase.instance.client;

  RouteCubit() : super(RouteInitial());

  Future<void> saveRoute(RouteModel route) async {
    emit(RouteLoading());
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        emit(RouteFailure('User not authenticated. Please log in.'));
        return;
      }

      // Ensure the model has the correct user_id from the session
      final routeWithUser = RouteModel(
        userId: userId,
        originName: route.originName,
        destinationName: route.destinationName,
        departureTime: route.departureTime,
        alertLeadMinutes: route.alertLeadMinutes,
        waypoints: route.waypoints,
        routePolyline: route.routePolyline,
      );

      await _supabase.from('routes').insert(routeWithUser.toMap());

      emit(RouteSuccess());
    } catch (e) {
      emit(RouteFailure(e.toString()));
    }
  }
}
