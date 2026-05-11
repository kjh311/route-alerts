import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart';
import '../models/route_model.dart';
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
      // map 0-6 (Mon-Sun) to 1-7 (Mon-Sun)
      final int dartDay = day + 1;
      
      await _notificationsPlugin.zonedSchedule(
        id: notificationId,
        title: 'Route Start Alert: ${route.originName}',
        body: 'Your shift to ${route.destinationName} starts soon. Check weather hazards!',
        scheduledDate: _nextInstanceOfDayAndTime(dartDay, alertDateTime.hour, alertDateTime.minute),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'route_alerts_channel',
            'Route Alerts',
            channelDescription: 'Notifications for scheduled haul routes',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: route.id,
      );
      
      debugPrint('DEBUG: Scheduled notification $notificationId for day $day at ${alertDateTime.hour}:${alertDateTime.minute}');
    }
  }

  Future<void> cancelRouteAlert(String routeId) async {
    // We would need to know which IDs were used. 
    // Usually we use routeId.hashCode + day. 
    // To be safe, we can use a range or store them.
    // For now, let's just cancel all for simplicity if IDs are not known, 
    // or use a consistent hashing.
    for (int day = 1; day <= 7; day++) {
      await _notificationsPlugin.cancel(id: (routeId.hashCode + day).abs());
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
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }
}
