import 'package:device_calendar/device_calendar.dart' as dc;
import 'package:timezone/timezone.dart' as tz;
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

  final dc.DeviceCalendarPlugin _plugin = dc.DeviceCalendarPlugin();

  String? _calendarId;
  String? get calendarId => _calendarId;
  void setCalendarId(String id) => _calendarId = id;

  Future<bool> hasPermission() async {
    final permissionsGranted = await _plugin.hasPermissions();
    return permissionsGranted.isSuccess && permissionsGranted.data == true;
  }

  Future<bool> requestPermission() async {
    final permissionsGranted = await _plugin.requestPermissions();
    return permissionsGranted.isSuccess && permissionsGranted.data == true;
  }

  Future<List<Calendar>> getWritableCalendars() async {
    if (!(await hasPermission())) return [];

    final res = await _plugin.retrieveCalendars();
    if (!res.isSuccess || res.data == null) return [];

    return res.data!
        .where((c) => c.isReadOnly == false)
        .map(
          (c) => Calendar(
            id: c.id,
            name: c.name,
            color: c.color,
            isReadOnly: c.isReadOnly,
          ),
        )
        .toList();
  }

  Future<String?> syncTask(TaskModel task) async {
    if (_calendarId == null || !(await hasPermission())) return null;

    final event = dc.Event(_calendarId);
    event.title = task.title;
    if (task.description != null && task.description!.isNotEmpty) {
      event.description = task.description;
    }

    final start = task.startTime;
    final end = task.endTime;

    event.start = tz.TZDateTime.from(start, tz.local);
    event.end = tz.TZDateTime.from(end, tz.local);
    if (task.calendarEventId != null) {
      event.eventId = task.calendarEventId;
    }

    final res = await _plugin.createOrUpdateEvent(event);
    if (res?.isSuccess == true) {
      return res!.data;
    }
    return null;
  }

  Future<void> deleteEvent(String calendarEventId) async {
    if (_calendarId == null || !(await hasPermission())) return;
    await _plugin.deleteEvent(_calendarId, calendarEventId);
  }

  Future<Map<String, String>> fullSync(List<TaskModel> tasks) async {
    final Map<String, String> newIds = {};
    for (final t in tasks) {
      if (t.calendarEventId != null ||
          t.startTime.isAfter(
            DateTime.now().subtract(const Duration(days: 1)),
          )) {
        final nid = await syncTask(t);
        if (nid != null && nid != t.calendarEventId) {
          newIds[t.id] = nid;
        }
      }
    }
    return newIds;
  }
}
