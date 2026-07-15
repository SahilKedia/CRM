import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzData;
import 'package:flutter/material.dart';
import 'api_service.dart'; // 👈 import your API service

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  GlobalKey<NavigatorState>? _navigatorKey;

  Future<void> init(GlobalKey<NavigatorState> navigatorKey) async {
    _navigatorKey = navigatorKey;

    tzData.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const iOSSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iOSSettings,
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (details) {
        _handleNotificationTap(details);
      },
    );

    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await androidImpl?.requestNotificationsPermission();
    await androidImpl?.requestExactAlarmsPermission();
  }

  void _handleNotificationTap(NotificationResponse details) {
    final context = _navigatorKey?.currentContext;
    if (context == null) return;

    String? title = 'Reminder';
    String? body = 'You have a reminder!';
    String? customerId;

    // Parse payload as JSON
    if (details.payload != null && details.payload!.isNotEmpty) {
      try {
        final data = jsonDecode(details.payload!) as Map<String, dynamic>;
        title = data['title'] as String? ?? title;
        body = data['body'] as String? ?? body;
        customerId = data['customerId'] as String?; // extract customer ID
      } catch (e) {
        body = details.payload;
      }
    }

    // ---- Update backend status if we have a customerId ----
    if (customerId != null) {
      ApiService().markReminderCompleted(customerId).then((_) {
        print('✅ Reminder for customer $customerId marked as completed.');
      }).catchError((error) {
        print('❌ Failed to update reminder status: $error');
      });
    }

    // Show the dialog (regardless of API success/failure)
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(title!),
        content: Text(body!),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  int _idFromCustomer(String customerId) => customerId.hashCode & 0x7fffffff;

  /// Schedules a reminder notification.
  /// Stores the customerId so we can update the backend when tapped.
  Future<void> scheduleReminder({
    required String customerId,
    required String customerName,
    required DateTime reminderDate,
    required String message,
  }) async {
    final id = _idFromCustomer(customerId);

    final scheduledDate = tz.TZDateTime(
      tz.local,
      reminderDate.year,
      reminderDate.month,
      reminderDate.day,
      reminderDate.hour,
      reminderDate.minute,
    );

    final now = tz.TZDateTime.now(tz.local);
    final finalDate = scheduledDate.isBefore(now)
        ? now.add(const Duration(seconds: 5))
        : scheduledDate;

    // Include customerId in the payload
    final payload = jsonEncode({
      'title': customerName,
      'body': message,
      'customerId': customerId, // 👈 stored for later retrieval
    });

    const androidDetails = AndroidNotificationDetails(
      'customer_reminders',
      'Customer Reminders',
      channelDescription: 'Reminders for customer follow-ups',
      importance: Importance.max,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
    );

    const iOSDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iOSDetails,
    );

    await _plugin.zonedSchedule(
      id,
      customerName,
      message,
      finalDate,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  Future<void> cancelReminder(String customerId) async {
    await _plugin.cancel(_idFromCustomer(customerId));
  }

  Future<void> cancelAllReminders() async {
    await _plugin.cancelAll();
  }
}