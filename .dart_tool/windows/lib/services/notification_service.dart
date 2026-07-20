// import 'dart:convert';

// import 'package:flutter/material.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:timezone/data/latest.dart' as tzData;
// import 'package:timezone/timezone.dart' as tz;

// import 'api_service.dart';

// class NotificationService {
//   static final NotificationService _instance =
//       NotificationService._internal();

//   factory NotificationService() => _instance;

//   NotificationService._internal();

//   final FlutterLocalNotificationsPlugin _plugin =
//       FlutterLocalNotificationsPlugin();

//   GlobalKey<NavigatorState>? _navigatorKey;

//   Future<void> init(GlobalKey<NavigatorState> navigatorKey) async {
//     _navigatorKey = navigatorKey;

//     tzData.initializeTimeZones();
//     tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));

//     const androidSettings =
//         AndroidInitializationSettings('@mipmap/ic_launcher');

//     const iosSettings = DarwinInitializationSettings(
//       requestAlertPermission: true,
//       requestBadgePermission: true,
//       requestSoundPermission: true,
//     );

//     const settings = InitializationSettings(
//       android: androidSettings,
//       iOS: iosSettings,
//     );

//     await _plugin.initialize(
//       settings,
//       onDidReceiveNotificationResponse: _handleNotificationTap,
//     );

//     final androidImpl =
//         _plugin.resolvePlatformSpecificImplementation<
//             AndroidFlutterLocalNotificationsPlugin>();

//     await androidImpl?.requestNotificationsPermission();
//     await androidImpl?.requestExactAlarmsPermission();
//   }

//   void _handleNotificationTap(NotificationResponse details) {
//     final context = _navigatorKey?.currentContext;
//     if (context == null) return;

//     String title = "Reminder";
//     String body = "You have a reminder!";
//     String? customerId;

//     if (details.payload != null && details.payload!.isNotEmpty) {
//       try {
//         final data = jsonDecode(details.payload!);

//         title = data["title"] ?? title;
//         body = data["body"] ?? body;
//         customerId = data["customerId"];
//       } catch (_) {
//         body = details.payload!;
//       }
//     }

//     if (customerId != null) {
//       ApiService()
//           .markReminderCompleted(customerId)
//           .catchError((_) {});
//     }

//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (_) => AlertDialog(
//         title: Text(title),
//         content: Text(body),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text("OK"),
//           )
//         ],
//       ),
//     );
//   }

//   int _idFromCustomer(String customerId) =>
//       customerId.hashCode & 0x7fffffff;

//   Future<void> scheduleReminder({
//     required String customerId,
//     required String customerName,
//     required DateTime reminderDate,
//     required String message,
//   }) async {
//     final id = _idFromCustomer(customerId);

//     final scheduledDate = tz.TZDateTime.from(
//       reminderDate,
//       tz.local,
//     );

//     final now = tz.TZDateTime.now(tz.local);

//     final finalDate = scheduledDate.isBefore(now)
//         ? now.add(const Duration(seconds: 5))
//         : scheduledDate;

//     final payload = jsonEncode({
//       "title": customerName,
//       "body": message,
//       "customerId": customerId,
//     });

//     const androidDetails = AndroidNotificationDetails(
//       "customer_reminders",
//       "Customer Reminders",
//       channelDescription: "Customer Reminder Notifications",
//       importance: Importance.max,
//       priority: Priority.high,
//       playSound: true,
//       enableVibration: true,
//     );

//     const iosDetails = DarwinNotificationDetails(
//       presentAlert: true,
//       presentBadge: true,
//       presentSound: true,
//     );

//     const notificationDetails = NotificationDetails(
//       android: androidDetails,
//       iOS: iosDetails,
//     );

//     await _plugin.zonedSchedule(
//       id,
//       customerName,
//       message,
//       finalDate,
//       notificationDetails,
//       androidScheduleMode:
//           AndroidScheduleMode.exactAllowWhileIdle,
//       uiLocalNotificationDateInterpretation:
//           UILocalNotificationDateInterpretation.absoluteTime,
//       payload: payload,
//     );
//   }

//   Future<void> cancelReminder(String customerId) async {
//     await _plugin.cancel(_idFromCustomer(customerId));
//   }

//   Future<void> cancelAllReminders() async {
//     await _plugin.cancelAll();
//   }

//   Future<bool> hasExactAlarmPermission() async {
//     return true;
//   }

//   Future<void> resyncPendingReminders(
//       List<dynamic> customers) async {
//     for (final customer in customers) {
//       try {
//         final reminder = customer["reminder"];

//         if (reminder == null) continue;

//         final status =
//             reminder["status"]?.toString().toLowerCase() ?? "";

//         if (status != "pending") continue;

//         final dateString = reminder["date"];

//         if (dateString == null) continue;

//         final reminderDate = DateTime.parse(dateString);

//         await scheduleReminder(
//           customerId: customer["_id"].toString(),
//           customerName: customer["name"] ?? "Customer",
//           reminderDate: reminderDate,
//           message:
//               reminder["note"] ?? "Customer follow-up reminder",
//         );
//       } catch (_) {
//         // Skip invalid reminder
//       }
//     }
//   }
// }


import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzData;
import 'package:timezone/timezone.dart' as tz;

import 'api_service.dart';

class NotificationService {
  static final NotificationService _instance =
      NotificationService._internal();

  factory NotificationService() => _instance;

  NotificationService._internal();

  static const _notifiedKeysPrefsKey = 'notified_reminder_keys';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  GlobalKey<NavigatorState>? _navigatorKey;

  // Reminders we've already fired an immediate notification for, so a
  // resync (e.g. on every app launch) doesn't re-notify the same overdue
  // reminder over and over.
  final Set<String> _notifiedKeys = {};
  bool _keysLoaded = false;

  Future<void> init(GlobalKey<NavigatorState> navigatorKey) async {
    _navigatorKey = navigatorKey;

    tzData.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _handleNotificationTap,
    );

    if (Platform.isAndroid) {
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      await androidImpl?.requestNotificationsPermission();
      await androidImpl?.requestExactAlarmsPermission();
    }

    await _loadNotifiedKeys();
  }

  Future<void> _loadNotifiedKeys() async {
    if (_keysLoaded) return;
    final prefs = await SharedPreferences.getInstance();
    _notifiedKeys
      ..clear()
      ..addAll(prefs.getStringList(_notifiedKeysPrefsKey) ?? []);
    _keysLoaded = true;
  }

  Future<void> _saveNotifiedKeys() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_notifiedKeysPrefsKey, _notifiedKeys.toList());
  }

  void _handleNotificationTap(NotificationResponse details) {
    final context = _navigatorKey?.currentContext;
    if (context == null) return;

    String title = "Reminder";
    String body = "You have a reminder!";
    String? customerId;

    if (details.payload != null && details.payload!.isNotEmpty) {
      try {
        final data = jsonDecode(details.payload!);

        title = data["title"] ?? title;
        body = data["body"] ?? body;
        customerId = data["customerId"];
      } catch (_) {
        body = details.payload!;
      }
    }

    // 🔥 FIX: viewing/tapping a notification no longer silently marks the
    // reminder complete. Completion is now an explicit user choice.
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Dismiss"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              if (customerId != null) {
                try {
                  await ApiService().markReminderCompleted(customerId);
                } catch (_) {
                  // Dialog is already closed; a failed completion call here
                  // shouldn't surface as a crash from the notification tap.
                }
              }
            },
            child: const Text(
              "Mark as Complete",
              style: TextStyle(color: Colors.green),
            ),
          ),
        ],
      ),
    );
  }

  // 🔥 FIX: the ID now depends on customerId + the reminder's own
  // date/time, not just customerId. Before, every reminder belonging to
  // the same customer shared one ID, so scheduling a second reminder
  // silently overwrote the first, and cancelling one wiped out whichever
  // reminder happened to be scheduled under that shared ID.
  int _idFor(String customerId, DateTime reminderDate) =>
      _keyFor(customerId, reminderDate).hashCode & 0x7fffffff;

  String _keyFor(String customerId, DateTime reminderDate) =>
      '$customerId|${reminderDate.toIso8601String()}';

  Future<void> scheduleReminder({
    required String customerId,
    required String customerName,
    required DateTime reminderDate,
    required String message,
  }) async {
    await _loadNotifiedKeys();

    final key = _keyFor(customerId, reminderDate);
    final id = _idFor(customerId, reminderDate);

    final scheduledDate = tz.TZDateTime.from(
      reminderDate,
      tz.local,
    );

    final now = tz.TZDateTime.now(tz.local);
    final isOverdue = scheduledDate.isBefore(now);

    // 🔥 FIX: don't re-fire a notification we've already shown for this
    // exact reminder. Previously, resyncPendingReminders() re-scheduled
    // every pending reminder on every call (e.g. every app launch), so an
    // overdue reminder would notify again and again instead of once.
    if (isOverdue && _notifiedKeys.contains(key)) {
      return;
    }

    final finalDate =
        isOverdue ? now.add(const Duration(seconds: 5)) : scheduledDate;

    final payload = jsonEncode({
      "title": customerName,
      "body": message,
      "customerId": customerId,
    });

    const androidDetails = AndroidNotificationDetails(
      "customer_reminders",
      "Customer Reminders",
      channelDescription: "Customer Reminder Notifications",
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.zonedSchedule(
      id,
      customerName,
      message,
      finalDate,
      notificationDetails,
      androidScheduleMode:
          AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );

    if (isOverdue) {
      _notifiedKeys.add(key);
      await _saveNotifiedKeys();
    }
  }

  // 🔥 BREAKING CHANGE: now requires the reminder's date, since a single ID
  // per customer no longer makes sense when a customer can have several
  // reminders. Update call sites to pass the specific reminder being
  // cancelled, e.g. NotificationService().cancelReminder(customerId, reminderDate).
  Future<void> cancelReminder(String customerId, DateTime reminderDate) async {
    final key = _keyFor(customerId, reminderDate);
    await _plugin.cancel(_idFor(customerId, reminderDate));
    _notifiedKeys.remove(key);
    await _saveNotifiedKeys();
  }

  Future<void> cancelAllReminders() async {
    await _plugin.cancelAll();
    _notifiedKeys.clear();
    await _saveNotifiedKeys();
  }

  // 🔥 FIX: this was hardcoded to `true` and never actually checked
  // anything. Now queries the platform for real.
  Future<bool> hasExactAlarmPermission() async {
    if (!Platform.isAndroid) return true;
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await androidImpl?.canScheduleExactNotifications() ?? false;
  }

  // 🔥 FIX: a customer's `reminder` field can be a single Map OR a List of
  // reminders. The original code only ever read it as a single Map, so any
  // additional reminders in a list were silently ignored.
  List<Map<String, dynamic>> _remindersOf(dynamic reminderField) {
    if (reminderField is List) {
      return reminderField.cast<Map<String, dynamic>>();
    } else if (reminderField is Map) {
      return [reminderField.cast<String, dynamic>()];
    }
    return [];
  }

  Future<void> resyncPendingReminders(List<dynamic> customers) async {
    await _loadNotifiedKeys();

    for (final customer in customers) {
      try {
        final customerId = customer["_id"]?.toString();
        if (customerId == null) continue;

        final reminders = _remindersOf(customer["reminder"]);

        for (final reminder in reminders) {
          final status =
              reminder["status"]?.toString().toLowerCase() ?? "";

          if (status != "pending") continue;

          final dateString = reminder["date"];
          if (dateString == null) continue;

          final reminderDate = DateTime.parse(dateString.toString());

          await scheduleReminder(
            customerId: customerId,
            customerName: customer["name"] ?? "Customer",
            reminderDate: reminderDate,
            message:
                reminder["note"] ?? "Customer follow-up reminder",
          );
        }
      } catch (_) {
        // Skip invalid customer/reminder entry
      }
    }
  }
}