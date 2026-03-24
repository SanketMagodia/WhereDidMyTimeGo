import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:timezone/timezone.dart' as tz;

/// Singleton wrapper around flutter_local_notifications.
/// Supports inline reply actions so users can log directly from the
/// notification shade — just like a chat app.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const int _baseNotifId = 1000;
  static const String _replyActionId = 'log_reply';
  static const String _channelId = 'wdmtg_log_v2'; // Bumped to apply new sound
  static const String _channelName = 'WDMTG Time Log';
  static const String _channelDesc =
      'Periodic reminders to log what you have been doing.';

  Future<void> init({
    void Function(NotificationResponse)? onResponse,
    void Function(NotificationResponse)? onBackgroundResponse,
  }) async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/launcher_icon',
    );
    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: onResponse,
      onDidReceiveBackgroundNotificationResponse: onBackgroundResponse,
    );

    // Request runtime permission (Android 13+)
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      await android.requestNotificationsPermission();
      // Ensure exact alarms are permitted (Android 12+)
      await android.requestExactAlarmsPermission();
    }
  }

  /// Cancels all existing notifications and pre-schedules exactly for the next 24 hours.
  /// This ensures absolute reliability even if the OS aggressively suspends the Dart app.
  Future<void> scheduleUpcomingPrompts({
    required int intervalMinutes,
    required bool isAwake,
    required String? Function(DateTime time) getTaskTitleAt,
  }) async {
    // 1. Cancel previous pending prompts unconditionally
    await _plugin.cancelAll();

    // 2. Do nothing if sleeping
    if (!isAwake) return;

    final now = DateTime.now();

    // 3. Find the exact next interval boundary
    final int minOffset = intervalMinutes - (now.minute % intervalMinutes);
    DateTime slotStart = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
    ).add(Duration(minutes: minOffset));

    // If it's less than 10 seconds away somehow (edge case execution overlap), bump a slot
    if (slotStart.difference(now).inSeconds < 10) {
      slotStart = slotStart.add(Duration(minutes: intervalMinutes));
    }

    // 4. Pre-schedule a full 24 hours of intervals
    final int slotsToSchedule = (24 * 60) ~/ intervalMinutes;

    for (int i = 0; i < slotsToSchedule; i++) {
      final currentStart = slotStart.add(
        Duration(minutes: i * intervalMinutes),
      );
      final currentEnd = currentStart.add(Duration(minutes: intervalMinutes));

      final taskTitle = getTaskTitleAt(currentStart);

      String p(int v) => v.toString().padLeft(2, '0');
      final rangeLabel =
          '${p(currentStart.hour)}:${p(currentStart.minute)} – ${p(currentEnd.hour)}:${p(currentEnd.minute)}';

      final body = taskTitle != null
          ? '$rangeLabel ● Ongoing: $taskTitle'
          : '$rangeLabel ● What are you doing?';

      final androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.high,
        priority: Priority.high,
        enableVibration: true,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound('clock'),
        ongoing: false,
        autoCancel: true,
        actions: [
          AndroidNotificationAction(
            _replyActionId,
            'Log $rangeLabel',
            showsUserInterface: true,
            allowGeneratedReplies: true,
            inputs: [
              AndroidNotificationActionInput(
                label: 'What are you doing $rangeLabel?',
              ),
            ],
          ),
        ],
      );

      final details = NotificationDetails(android: androidDetails);

      try {
        await _plugin.zonedSchedule(
          id: _baseNotifId + i,
          title: 'WDMTG — Time Log',
          body: body,
          scheduledDate: tz.TZDateTime.from(currentStart, tz.local),
          notificationDetails: details,
          payload: currentStart.millisecondsSinceEpoch.toString(),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
      } catch (e) {
        debugPrint('NotificationService.schedule error: $e');
        break; // If scheduling fails (likely limit reached or permission issue), stop the loop.
      }
    }
  }

  /// Cancels everything (including currently visible notification and ALL scheduled).
  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }

  /// Cancels ONLY the currently visible notifications, leaving scheduled ones intact.
  Future<void> clearActiveNotifications() async {
    try {
      final active = await _plugin.getActiveNotifications();
      for (final n in active) {
        if (n.id != null) {
          await _plugin.cancel(id: n.id!);
        }
      }
    } catch (_) {}
  }

  /// Extract reply text from a [NotificationResponse] action.
  static String? extractReply(NotificationResponse response) {
    if (response.actionId == _replyActionId) {
      final text = response.input?.trim();
      return (text != null && text.isNotEmpty) ? text : 'No details provided';
    }
    final text = response.input?.trim();
    return (text != null && text.isNotEmpty) ? text : null;
  }
}
