import 'dart:convert';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import '../models/task_model.dart';
import '../models/todo_folder_model.dart';

class WidgetSyncService {
  static const String androidAppWidgetGroup = 'group.wdmtg.widget';

  static Future<void> updateWidgets(
    List<TaskModel> tasks,
    List<TodoFolderModel> todos,
  ) async {
    // 2. Prepare Schedule Data (Next 4 days: 0, 1, 2, 3)
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    Map<String, List<Map<String, String>>> tasksByDay = {};
    List<Map<String, dynamic>> dayTiles = [];

    for (int i = 0; i < 4; i++) {
      final targetDate = today.add(Duration(days: i));
      final nextDate = targetDate.add(const Duration(days: 1));

      final dayTasks = tasks
          .where(
            (t) =>
                t.startTime.isBefore(nextDate) && t.endTime.isAfter(targetDate),
          )
          .toList();

      dayTasks.sort((a, b) => a.startTime.compareTo(b.startTime));

      tasksByDay[i.toString()] = dayTasks.map((t) {
        return {
          'title': t.title,
          'time':
              '${DateFormat.Hm().format(t.startTime)} - ${DateFormat.Hm().format(t.endTime)}',
        };
      }).toList();

      dayTiles.add({
        'offset': i,
        'label': i == 0 ? 'Today' : DateFormat('EEE d').format(targetDate),
        'count': dayTasks.length,
      });
    }

    await HomeWidget.saveWidgetData<String>(
      'schedule_tasks_json',
      jsonEncode(tasksByDay),
    );
    await HomeWidget.saveWidgetData<String>(
      'schedule_tiles_json',
      jsonEncode(dayTiles),
    );

    // Force Android widgets to update
    await HomeWidget.updateWidget(
      name: 'ScheduleWidgetProvider',
      androidName: 'ScheduleWidgetProvider',
    );
  }
}
