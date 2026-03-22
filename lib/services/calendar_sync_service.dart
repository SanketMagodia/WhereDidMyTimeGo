/// Stub — device_calendar (v3.9.0) is incompatible with modern Android
/// Gradle Plugin. Calendar sync is not active; the interface is kept so
/// the rest of the codebase compiles without changes.
library calendar_sync_service;

import '../models/task_model.dart';

class Calendar {
  final String? id;
  final String? name;
  final int? color;
  final bool? isReadOnly;
  const Calendar({this.id, this.name, this.color, this.isReadOnly});
}

class CalendarSyncService {
  CalendarSyncService._();
  static final CalendarSyncService instance = CalendarSyncService._();

  String? _calendarId;
  String? get calendarId => _calendarId;
  void setCalendarId(String id) => _calendarId = id;

  Future<bool> hasPermission() async => false;
  Future<bool> requestPermission() async => false;
  Future<List<Calendar>> getWritableCalendars() async => [];

  Future<String?> syncTask(TaskModel task) async => null;
  Future<void> deleteEvent(String calendarEventId) async {}
  Future<Map<String, String>> fullSync(List<TaskModel> tasks) async => {};
}
