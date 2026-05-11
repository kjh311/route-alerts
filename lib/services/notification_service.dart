import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:flutter/foundation.dart';
import '../models/route_model.dart';
import 'route_service.dart';
import 'dart:io';
import 'dart:convert';
import '../main.dart';
import '../theme/design_system.dart';
import 'package:flutter/material.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();
    try {
      final dynamic rawRes = await FlutterTimezone.getLocalTimezone();
      final String rawTz = rawRes.toString();
      
      // Clean up "TimezoneInfo(name: America/Denver, ...)" string
      String cleanTz = rawTz.contains('(') ? rawTz.split('(')[1].split(',')[0] : rawTz;
      // Strip potential "name: " label if present
      cleanTz = cleanTz.replaceFirst('name:', '').trim();
      
      try {
        tz.setLocalLocation(tz.getLocation(cleanTz));
        debugPrint('DEBUG: Local Timezone successfully set to: ${tz.local.name}');
      } catch (e) {
        debugPrint('WARNING: Could not find location for "$cleanTz". Falling back to America/Denver.');
        tz.setLocalLocation(tz.getLocation('America/Denver'));
        debugPrint('DEBUG: Local Timezone successfully set to: ${tz.local.name}');
      }
    } catch (e) {
      debugPrint('ERROR: Failed to set local timezone: $e');
      // If native fails, try to at least get a common US timezone or stay UTC but log it clearly
      debugPrint('CRITICAL: App is defaulting to UTC. Notification times may be incorrect.');
    }
    
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
        if (response.actionId == 'dismiss_summary' || response.actionId == 'dismiss_action') {
          _notificationsPlugin.cancel(id: response.id ?? 0);
          debugPrint('DEBUG: Notification ${response.id} dismissed via action.');
        } else if (response.payload != null) {
          _showBriefingDialog(response.payload!);
          debugPrint('DEBUG: Notification body tapped. Showing full briefing.');
        }
      },
    );

    // Create high-priority channel for Android
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      
      // Delete old channels to force sound update
      await androidImplementation?.deleteNotificationChannel(channelId: 'route_alerts_channel');
      
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'shift_alerts_v1', // New ID to force sound update
        'Shift Alerts',
        description: 'High-priority shift reminders with custom sound',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        sound: RawResourceAndroidNotificationSound('horn'),
      );

      await androidImplementation?.createNotificationChannel(channel);
    }

    // 2. Start-up Logs (Timezone & Pending)
    debugPrint('DEBUG: Timezone: ${tz.local.name}');
    debugPrint('DEBUG: Current TZ Time: ${tz.TZDateTime.now(tz.local)}');
    await checkPendingAlerts();
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
    tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime departureDateTime = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    tz.TZDateTime alertDateTime = departureDateTime.subtract(Duration(minutes: route.alertLeadMinutes));

    debugPrint('DEBUG: Wall Clock Time: ${now.toString()}');
    debugPrint('DEBUG: Alert Base Time: ${alertDateTime.toString()}');
    debugPrint('DEBUG: Starting schedule loop for route: ${route.originName}');
    
    // 2. Schedule for each driving day
    for (int i = 1; i <= 7; i++) {
      final isInDrivingDays = route.drivingDays.contains(i);
      debugPrint('DEBUG: Checking Day $i: is it in driving_days? $isInDrivingDays');
      
      if (!isInDrivingDays) continue;

      final int day = i;
      final int notificationId = (route.id.hashCode + day).abs();
      final int dartDay = day; // Use day directly (Expected 1-7)
      final scheduledDate = _nextInstanceOfDayAndTime(dartDay, alertDateTime.hour, alertDateTime.minute);
      
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
            'shift_alerts_v1',
            'Shift Alerts',
            channelDescription: 'High-priority shift reminders with custom sound',
            importance: Importance.max,
            priority: Priority.high,
            ongoing: true,
            autoCancel: false,
            playSound: true,
            sound: RawResourceAndroidNotificationSound('horn'),
            timeoutAfter: null,
            styleInformation: const BigTextStyleInformation(''),
            actions: [
              AndroidNotificationAction('dismiss_action', 'Dismiss'),
            ],
          ),
          iOS: DarwinNotificationDetails(
            sound: 'horn.mp3',
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: jsonEncode({
          'type': 'scheduled',
          'title': 'Shift Start Alert: ${route.originName}',
          'body': 'Your shift to ${route.destinationName} starts soon. Check weather hazards!',
          'routeId': route.id,
        }),
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
    // 1. Ensure Exact Alarm permission is granted for Android 14+
    final permissionGranted = await requestExactAlarmsPermission();
    if (!permissionGranted) {
      debugPrint('WARNING: Exact Alarm permission NOT granted. Alerts may be delayed.');
    }

    // 2. Clear all existing alerts to avoid overlap
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
    
    // 4. Final Audit
    await checkPendingAlerts();
  }

  Future<void> checkPendingAlerts() async {
    final List<PendingNotificationRequest> pending = 
        await _notificationsPlugin.pendingNotificationRequests();
    
    debugPrint('--- PENDING NOTIFICATIONS AUDIT (Count: ${pending.length}) ---');
    for (var p in pending) {
      debugPrint('ID: ${p.id} | Title: ${p.title} | Payload: ${p.payload}');
    }
    debugPrint('--- END AUDIT ---');
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
      'shift_alerts_v1',
      'Shift Alerts',
      channelDescription: 'High-priority shift reminders with custom sound',
      importance: Importance.max,
      priority: Priority.high,
      autoCancel: false,
      ongoing: true, // Prevents dismissal by tap or "Clear All"
      timeoutAfter: null,
      playSound: true,
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
      payload: jsonEncode({
        'type': 'briefing',
        'title': title,
        'body': body,
      }),
    );
  }

  void _showBriefingDialog(String payload) {
    try {
      final data = jsonDecode(payload);
      final context = navigatorKey.currentContext;
      if (context == null) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppDesignSystem.surfaceContainerHigh,
          title: Text(data['title']?.toString().toUpperCase() ?? 'HAUL BRIEFING', 
              style: AppDesignSystem.headlineMedium.copyWith(color: AppDesignSystem.primary)),
          content: SingleChildScrollView(
            child: Text(data['body']?.toString() ?? '', style: AppDesignSystem.bodyMedium),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(backgroundColor: AppDesignSystem.primary),
              child: Text('DISMISS', style: TextStyle(color: AppDesignSystem.onPrimary)),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('ERROR showing briefing dialog: $e');
    }
  }
}
