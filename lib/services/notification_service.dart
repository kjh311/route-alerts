import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart';
import '../models/route_model.dart';
import 'route_service.dart';
import 'dart:io';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();
    
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _notificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.actionId == 'dismiss_summary') {
          _notificationsPlugin.cancel(id: response.id ?? 0);
          debugPrint('DEBUG: Summary notification dismissed via action.');
        }
      },
    );

    // Create high-priority channel for Android
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'route_alerts_channel',
        'Route Alerts',
        description: 'Notifications for scheduled haul routes and weather summaries',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        sound: RawResourceAndroidNotificationSound('horn'),
      );

      await androidImplementation?.createNotificationChannel(channel);
    }
  }

  Future<bool> requestNotificationPermission() async {
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      return await androidImplementation?.requestNotificationsPermission() ?? false;
    } else if (Platform.isIOS) {
      return await _notificationsPlugin
              .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin>()
              ?.requestPermissions(
                alert: true,
                badge: true,
                sound: true,
              ) ??
          false;
    }
    return true;
  }

  Future<bool> requestExactAlarmsPermission() async {
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      return await androidImplementation?.requestExactAlarmsPermission() ?? false;
    }
    return true;
  }

  Future<void> scheduleRouteAlert(RouteModel route) async {
    // 1. Calculate Alert Time
    // departureTime is 'HH:mm:ss'
    final timeParts = route.departureTime.split(':');
    final int hour = int.parse(timeParts[0]);
    final int minute = int.parse(timeParts[1]);

    // Subtract lead minutes
    DateTime now = DateTime.now();
    DateTime departureDateTime = DateTime(now.year, now.month, now.day, hour, minute);
    DateTime alertDateTime = departureDateTime.subtract(Duration(minutes: route.alertLeadMinutes));

    // 2. Schedule for each driving day
    for (int day in route.drivingDays) {
      final int notificationId = (route.id.hashCode + day).abs();
      final int dartDay = day; // Use day directly (Expected 1-7)
      final scheduledDate = _nextInstanceOfDayAndTime(dartDay, alertDateTime.hour, alertDateTime.minute);
      
      debugPrint('DEBUG: Checking if today (${DateTime.now().weekday}) is in drivingDays: ${route.drivingDays}');
      debugPrint('DEBUG: Target TZDateTime for Day $day: $scheduledDate');

      // IMMEDIATE TEST RULE: If scheduled within 10 mins from now, fire immediately
      bool fireNow = false;
      final nowTZ = tz.TZDateTime.now(tz.local);
      final diff = scheduledDate.difference(nowTZ).inMinutes;
      if (diff >= 0 && diff <= 10) {
        fireNow = true;
        debugPrint('DEBUG: [IMMEDIATE TEST] Alert is within 10 mins ($diff mins). Triggering NOW.');
      }

      await _notificationsPlugin.zonedSchedule(
        id: notificationId,
        title: 'Route Start Alert: ${route.originName}',
        body: 'Your shift to ${route.destinationName} starts soon. Check weather hazards!',
        scheduledDate: fireNow ? nowTZ.add(const Duration(seconds: 2)) : scheduledDate,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'route_alerts_channel',
            'Route Alerts',
            channelDescription: 'Notifications for scheduled haul routes',
            importance: Importance.max,
            priority: Priority.high,
            sound: RawResourceAndroidNotificationSound('horn'),
          ),
          iOS: DarwinNotificationDetails(
            sound: 'horn.mp3',
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: route.id,
      );
      
      debugPrint('DEBUG: Scheduled notification $notificationId for day $day at ${alertDateTime.hour}:${alertDateTime.minute}');
    }
  }

  Future<void> cancelRouteAlert(String routeId) async {
    // Cancel all IDs that could have been generated for this route
    for (int day = 0; day <= 6; day++) {
      await _notificationsPlugin.cancel(id: (routeId.hashCode + day).abs());
    }
  }

  Future<void> refreshScheduledNotifications() async {
    // 1. Clear all existing alerts to avoid overlap
    await _notificationsPlugin.cancelAll();
    
    // 2. Fetch latest active routes
    try {
      final routes = await RouteService().fetchRoutes();
      
      // 3. Re-schedule for each ACTIVE route
      for (var route in routes) {
        if (route.isActive) {
          await scheduleRouteAlert(route);
        }
      }
      debugPrint('DEBUG: Refresh complete for ${routes.length} routes.');
    } catch (e) {
      debugPrint('DEBUG: Failed to refresh notifications: $e');
    }
  }

  tz.TZDateTime _nextInstanceOfDayAndTime(int day, int hour, int minute) {
    tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    
    // Adjust to correct day of week
    while (scheduledDate.weekday != day) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 7));
    }
    return scheduledDate;
  }
  Future<void> sendImmediateSummaryNotification({
    required String title,
    required String body,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'route_alerts_channel',
      'Route Alerts',
      channelDescription: 'Notifications for scheduled haul routes',
      importance: Importance.max,
      priority: Priority.high,
      autoCancel: false,
      ongoing: true, // Prevents dismissal by tap or "Clear All"
      timeoutAfter: null,
      sound: const RawResourceAndroidNotificationSound('horn'),
      actions: [
        const AndroidNotificationAction(
          'dismiss_summary',
          'Dismiss',
          showsUserInterface: false,
          cancelNotification: true,
        ),
      ],
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        summaryText: 'Haul Weather Briefing',
      ),
    );

    await _notificationsPlugin.show(
      id: DateTime.now().millisecond,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: androidDetails,
        iOS: const DarwinNotificationDetails(
          sound: 'horn.mp3',
        ),
      ),
    );
  }
}
