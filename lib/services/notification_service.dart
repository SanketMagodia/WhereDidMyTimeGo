import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';

/// Singleton wrapper around flutter_local_notifications.
/// Supports inline reply actions so users can log directly from the
/// notification shade — just like a chat app.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const int _logNotifId = 1;
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
      '@mipmap/ic_launcher',
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
    }
  }

  /// Shows a notification with an **inline text reply action**.
  /// The user can type directly in the notification shade and hit send.
  Future<void> showLogPrompt(
    int intervalMinutes, {
    required DateTime slotStart,
    required DateTime slotEnd,
    String? currentTaskTitle,
  }) async {
    String _p(int v) => v.toString().padLeft(2, '0');
    final rangeLabel =
        '${_p(slotStart.hour)}:${_p(slotStart.minute)} – ${_p(slotEnd.hour)}:${_p(slotEnd.minute)}';

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
          showsUserInterface: false,
          allowGeneratedReplies: true,
          inputs: [
            AndroidNotificationActionInput(
              label: 'What were you doing $rangeLabel?',
            ),
          ],
        ),
      ],
    );

    final details = NotificationDetails(android: androidDetails);

    try {
      final body = currentTaskTitle != null
          ? '$rangeLabel ● Ongoing: $currentTaskTitle'
          : '$rangeLabel ● What were you doing?';

      await _plugin.show(
        id: _logNotifId,
        title: 'WDMTG — Time Log',
        body: body,
        notificationDetails: details,
      );
    } catch (e) {
      debugPrint('NotificationService.showLogPrompt error: $e');
    }
  }

  /// Dismiss the log notification (e.g. after user replied via the app).
  Future<void> cancelLogNotification() async {
    try {
      await _plugin.cancel(id: _logNotifId);
    } catch (_) {}
  }

  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }

  /// Extract reply text from a [NotificationResponse] action.
  static String? extractReply(NotificationResponse response) {
    if (response.actionId != _replyActionId) return null;
    final text = response.input?.trim();
    return (text != null && text.isNotEmpty) ? text : null;
  }
}
