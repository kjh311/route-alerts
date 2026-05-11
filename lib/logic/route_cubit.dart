import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/route_model.dart';
import '../services/notification_service.dart';

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

      final map = route.toMap();
      map['user_id'] = userId;
      
      final response = await _supabase.from('routes').upsert(map).select().single();
      
      // Update local model with ID if it was a new insert
      final savedRoute = RouteModel.fromJson(response);

      // Refresh all notifications to stay in sync with latest changes
      await NotificationService().refreshScheduledNotifications();

      emit(RouteSuccess());
    } catch (e) {
      emit(RouteFailure(e.toString()));
    }
  }
}
