class RouteModel {
  final String? id;
  final String userId;
  final String startLocation;
  final String endLocation;
  final List<Map<String, dynamic>> checkPoints;
  final String shiftStartTime;
  final int shiftDuration;
  final double? estimatedDistance;
  final int? estimatedDurationMinutes;
  final int alertLeadTimeMinutes;
  final List<int> activeDays;
  final int windThreshold;

  RouteModel({
    this.id,
    required this.userId,
    required this.startLocation,
    required this.endLocation,
    required this.checkPoints,
    required this.shiftStartTime,
    required this.shiftDuration,
    this.estimatedDistance,
    this.estimatedDurationMinutes,
    this.alertLeadTimeMinutes = 30,
    this.activeDays = const [1, 2, 3, 4, 5],
    this.windThreshold = 45,
  });

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'start_location': startLocation,
      'end_location': endLocation,
      'check_points': checkPoints,
      'shift_start_time': shiftStartTime,
      'shift_duration': shiftDuration,
      'estimated_distance_mi': estimatedDistance,
      'estimated_duration_minutes': estimatedDurationMinutes,
      'alert_lead_time_minutes': alertLeadTimeMinutes,
      'active_days': activeDays,
      'wind_threshold': windThreshold,
    };
  }
}
