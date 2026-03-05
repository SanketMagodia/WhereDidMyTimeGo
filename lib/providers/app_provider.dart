import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task_model.dart';
import '../models/log_entry_model.dart';
import '../models/todo_model.dart';
import '../services/notification_service.dart';
import '../services/widget_sync_service.dart';
import 'package:file_picker/file_picker.dart';

class AppProvider extends ChangeNotifier with WidgetsBindingObserver {
  List<TaskModel> _tasks = [];
  List<LogEntry> _logs = [];
  List<TodoModel> _todos = [];

  bool _isAwake = true;
  int _logIntervalMinutes = 60;
  bool _isPromptOwed = false;
  ThemeMode _themeMode = ThemeMode.dark;

  // Tracks whether the last notification was answered (for auto-continue)
  DateTime? _notificationShownAt;

  Timer? _timer;

  List<TaskModel> get tasks => _tasks;
  List<LogEntry> get logs => _logs;
  List<TodoModel> get todos => _todos;
  bool get isAwake => _isAwake;
  int get logIntervalMinutes => _logIntervalMinutes;
  bool get isPromptOwed => _isPromptOwed;
  ThemeMode get themeMode => _themeMode;

  AppProvider() {
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPendingNotifications();
    }
  }

  Future<void> _init() async {
    await _loadSettings();
    await _loadPromptState();
    await _loadData();
    await _checkPendingNotifications();
    _startTimer();
  }

  Future<void> _savePromptState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isPromptOwed', _isPromptOwed);
    if (_notificationShownAt != null) {
      await prefs.setInt(
        'notifShownAt',
        _notificationShownAt!.millisecondsSinceEpoch,
      );
    } else {
      await prefs.remove('notifShownAt');
    }
  }

  Future<void> _loadPromptState() async {
    final prefs = await SharedPreferences.getInstance();
    _isPromptOwed = prefs.getBool('isPromptOwed') ?? false;
    final ms = prefs.getInt('notifShownAt');
    if (ms != null)
      _notificationShownAt = DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> _checkPendingNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final text = prefs.getString('pending_log_reply');
    final timeMs = prefs.getInt('pending_log_time');

    if (text != null && text.isNotEmpty && timeMs != null) {
      final dt = DateTime.fromMillisecondsSinceEpoch(timeMs);
      await addLog(LogEntry(id: timeMs.toString(), timestamp: dt, text: text));
      await prefs.remove('pending_log_reply');
      await prefs.remove('pending_log_time');
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _isAwake = prefs.getBool('isAwake') ?? true;
    _logIntervalMinutes = prefs.getInt('logIntervalMinutes') ?? 60;
    final tm = prefs.getInt('themeMode') ?? 0;
    _themeMode = ThemeMode.values[tm.clamp(0, 2)];
    notifyListeners();
  }

  Future<void> saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isAwake', _isAwake);
    await prefs.setInt('logIntervalMinutes', _logIntervalMinutes);
    await prefs.setInt('themeMode', _themeMode.index);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    await saveSettings();
  }

  Future<File> _getDataFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/timelog_data.json');
  }

  Future<void> _loadData() async {
    try {
      final file = await _getDataFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final data = json.decode(content);

        if (data['tasks'] != null) {
          _tasks = (data['tasks'] as List)
              .map((e) => TaskModel.fromJson(e))
              .toList();
        }
        if (data['logs'] != null) {
          _logs = (data['logs'] as List)
              .map((e) => LogEntry.fromJson(e))
              .toList();
        }
        if (data['todos'] != null) {
          _todos = (data['todos'] as List)
              .map((e) => TodoModel.fromJson(e))
              .toList();
          _todos.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
        }

        // Sort
        _tasks.sort((a, b) => a.startTime.compareTo(b.startTime));
        _logs.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        notifyListeners();

        // Update widgets purely on startup so they fill in right away
        WidgetSyncService.updateWidgets(_tasks, _todos);
      }
    } catch (e) {
      debugPrint("Error loading data: $e");
    }
  }

  Future<void> _saveData() async {
    try {
      final file = await _getDataFile();
      final data = {
        'tasks': _tasks.map((e) => e.toJson()).toList(),
        'logs': _logs.map((e) => e.toJson()).toList(),
        'todos': _todos.map((e) => e.toJson()).toList(),
      };
      await file.writeAsString(json.encode(data));

      // Update Android Home Widgets
      WidgetSyncService.updateWidgets(_tasks, _todos);
    } catch (e) {
      debugPrint("Error saving data: $e");
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (!_isAwake || _isPromptOwed) return;

      final now = DateTime.now();
      final minuteOfDay = now.hour * 60 + now.minute;

      if (minuteOfDay % _logIntervalMinutes != 0) return;

      // Don't double-fire if already logged this exact minute
      if (_logs.isNotEmpty) {
        final last = _logs.last.timestamp;
        final lastMinute = last.hour * 60 + last.minute;
        final sameDay =
            last.year == now.year &&
            last.month == now.month &&
            last.day == now.day;
        if (sameDay && lastMinute == minuteOfDay) return;
      }

      // Auto-continue: if last notification was shown but never answered
      if (_notificationShownAt != null) {
        String prevText = 'Continued previous task';
        for (var i = _logs.length - 1; i >= 0; i--) {
          if (!_logs[i].isSleep) {
            prevText = _logs[i].text.split(' • ').last;
            if (prevText.startsWith('Continued: ')) {
              prevText = prevText.substring(11).trim();
            }
            break;
          }
        }

        _insertLog(
          LogEntry(
            id: _notificationShownAt!.millisecondsSinceEpoch.toString(),
            timestamp: _notificationShownAt!,
            text: 'Continued: $prevText',
          ),
        );
        _saveData();
        _notificationShownAt = null;
      }

      _isPromptOwed = true;
      _notificationShownAt = now;
      _savePromptState();

      // Find ongoing task
      String? currentTaskTitle;
      try {
        final ongoing = _tasks.firstWhere(
          (t) => t.startTime.isBefore(now) && t.endTime.isAfter(now),
        );
        currentTaskTitle = ongoing.title;
      } catch (_) {}

      NotificationService.instance.showLogPrompt(
        _logIntervalMinutes,
        slotStart: now.subtract(Duration(minutes: _logIntervalMinutes)),
        slotEnd: now,
        currentTaskTitle: currentTaskTitle,
      );
      notifyListeners();
    });
  }

  void clearPrompt() {
    _isPromptOwed = false;
    _notificationShownAt = null;
    _savePromptState();
    notifyListeners();
  }

  void _insertLog(LogEntry entry) {
    if (entry.isSleep) {
      _logs.add(entry);
    } else {
      final t = entry.timestamp;
      final bucketTime = t.subtract(const Duration(seconds: 1));
      final bucketStart = DateTime(
        t.year,
        t.month,
        t.day,
        bucketTime.hour,
        0,
        0,
      );

      final existingIdx = _logs.indexWhere(
        (l) => l.timestamp == bucketStart && !l.isSleep,
      );

      if (existingIdx != -1) {
        final existing = _logs[existingIdx];

        var newText = entry.text;
        if (newText.startsWith('Continued: '))
          newText = newText.substring(11).trim();

        var oldText = existing.text;
        if (oldText.startsWith('Continued: '))
          oldText = oldText.substring(11).trim();

        final parts = oldText.split(' • ').map((e) => e.trim()).toList();
        if (parts.isEmpty || parts.last != newText) {
          _logs[existingIdx] = LogEntry(
            id: existing.id,
            timestamp: bucketStart, // aligned to start of hour
            text: '${existing.text} • $newText',
            isSleep: false,
          );
        }
      } else {
        _logs.add(
          LogEntry(
            id: entry.id,
            timestamp: bucketStart, // aligned to start of hour
            text: entry.text,
            isSleep: false,
          ),
        );
      }
    }
    _logs.sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  Future<void> addLog(LogEntry entry) async {
    LogEntry finalEntry = entry;
    // If answering a prompt, force the log into the exact slot that was prompted
    if (_isPromptOwed && _notificationShownAt != null && !entry.isSleep) {
      finalEntry = LogEntry(
        id: entry.id,
        timestamp: _notificationShownAt!,
        text: entry.text,
        isSleep: entry.isSleep,
      );
    }

    _insertLog(finalEntry);
    _isPromptOwed = false;
    _notificationShownAt = null; // answered — no auto-continue
    _savePromptState();
    await NotificationService.instance.cancelLogNotification();
    notifyListeners();
    await _saveData();
  }

  /// Updates the text of an existing log entry (used by the edit dialog).
  Future<void> updateLog(LogEntry updated) async {
    final idx = _logs.indexWhere((l) => l.id == updated.id);
    if (idx != -1) {
      _logs[idx] = updated;
      notifyListeners();
      await _saveData();
    }
  }

  /// Called when user replies to the notification from the notification shade.
  Future<void> handleNotificationReply(String text, DateTime at) async {
    await addLog(
      LogEntry(
        id: at.millisecondsSinceEpoch.toString(),
        timestamp: at,
        text: text,
      ),
    );
  }

  Future<void> toggleAwakeStatus(bool awake) async {
    _isAwake = awake;
    notifyListeners();
    await saveSettings();
    if (awake) {
      _startTimer();
    } else {
      // Create a sleep log entry
      addLog(
        LogEntry(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          timestamp: DateTime.now(),
          text: "Sleeping...",
          isSleep: true,
        ),
      );
    }
  }

  Future<void> setLogInterval(int minutes) async {
    _logIntervalMinutes = minutes;
    notifyListeners();
    await saveSettings();
  }

  Future<void> addTask(TaskModel task) async {
    _tasks.add(task);
    _tasks.sort((a, b) => a.startTime.compareTo(b.startTime));
    notifyListeners();
    await _saveData();
  }

  Future<void> removeTask(String id) async {
    _tasks.removeWhere((t) => t.id == id);
    notifyListeners();
    await _saveData();
  }

  Future<void> updateTask(TaskModel updatedTask) async {
    final index = _tasks.indexWhere((t) => t.id == updatedTask.id);
    if (index != -1) {
      _tasks[index] = updatedTask;
      _tasks.sort((a, b) => a.startTime.compareTo(b.startTime));
      notifyListeners();
      await _saveData();
    }
  }

  Future<void> shiftTasksForDay(DateTime date, Duration shiftDuration) async {
    bool changed = false;
    for (int i = 0; i < _tasks.length; i++) {
      final task = _tasks[i];
      if (task.startTime.year == date.year &&
          task.startTime.month == date.month &&
          task.startTime.day == date.day) {
        _tasks[i] = TaskModel(
          id: task.id,
          title: task.title,
          startTime: task.startTime.add(shiftDuration),
          endTime: task.endTime.add(shiftDuration),
        );
        changed = true;
      }
    }

    if (changed) {
      _tasks.sort((a, b) => a.startTime.compareTo(b.startTime));
      notifyListeners();
      await _saveData();
    }
  }

  // ─── Todos ──────────────────────────────────────────────────────────────────
  Future<void> addTodo(String text, int colorIndex) async {
    final newId = DateTime.now().millisecondsSinceEpoch.toString();
    final newOrder = _todos.isEmpty ? 0 : _todos.last.orderIndex + 1;
    _todos.add(
      TodoModel(
        id: newId,
        text: text,
        colorIndex: colorIndex,
        orderIndex: newOrder,
      ),
    );
    notifyListeners();
    await _saveData();
  }

  Future<void> updateTodoColor(String id, int colorIndex) async {
    final idx = _todos.indexWhere((t) => t.id == id);
    if (idx != -1) {
      _todos[idx] = _todos[idx].copyWith(colorIndex: colorIndex);
      notifyListeners();
      await _saveData();
    }
  }

  Future<void> updateTodoText(String id, String text) async {
    final idx = _todos.indexWhere((t) => t.id == id);
    if (idx != -1) {
      _todos[idx] = _todos[idx].copyWith(text: text);
      notifyListeners();
      await _saveData();
    }
  }

  Future<void> toggleTodo(String id) async {
    final idx = _todos.indexWhere((t) => t.id == id);
    if (idx != -1) {
      _todos[idx] = _todos[idx].copyWith(isDone: !_todos[idx].isDone);
      notifyListeners();
      await _saveData();
    }
  }

  Future<void> reorderTodos(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final item = _todos.removeAt(oldIndex);
    _todos.insert(newIndex, item);
    // Reassign orderIndex mathematically
    for (int i = 0; i < _todos.length; i++) {
      _todos[i] = _todos[i].copyWith(orderIndex: i);
    }
    notifyListeners();
    await _saveData();
  }

  Future<void> removeTodo(String id) async {
    _todos.removeWhere((t) => t.id == id);
    notifyListeners();
    await _saveData();
  }

  // ─── Export & Import ────────────────────────────────────────────────────────
  Future<void> exportData() async {
    try {
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Please select an output file:',
        fileName: 'timelog_export.json',
      );

      if (outputFile != null) {
        final data = {
          'tasks': _tasks.map((e) => e.toJson()).toList(),
          'logs': _logs.map((e) => e.toJson()).toList(),
        };
        await File(outputFile).writeAsString(json.encode(data));
      }
    } catch (e) {
      debugPrint("Export error: $e");
    }
  }

  Future<void> importData() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final content = await file.readAsString();
        final data = json.decode(content);

        bool changed = false;

        if (data['tasks'] != null) {
          final importedTasks = (data['tasks'] as List).map(
            (e) => TaskModel.fromJson(e),
          );
          for (var t in importedTasks) {
            if (!_tasks.any((existing) => existing.id == t.id)) {
              _tasks.add(t);
              changed = true;
            }
          }
        }

        if (data['logs'] != null) {
          final importedLogs = (data['logs'] as List).map(
            (e) => LogEntry.fromJson(e),
          );
          for (var l in importedLogs) {
            if (!_logs.any((existing) => existing.id == l.id)) {
              _logs.add(l);
              changed = true;
            }
          }
        }

        if (changed) {
          _tasks.sort((a, b) => a.startTime.compareTo(b.startTime));
          _logs.sort((a, b) => a.timestamp.compareTo(b.timestamp));
          notifyListeners();
          await _saveData();
        }
      }
    } catch (e) {
      debugPrint("Import error: $e");
    }
  }
}
