import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

import '../models/task_model.dart';
import '../models/log_entry_model.dart';
import '../models/todo_folder_model.dart';
import '../models/todo_model.dart';
import '../models/expense_model.dart';
import '../services/notification_service.dart';
import '../services/widget_sync_service.dart';

class AppProvider extends ChangeNotifier with WidgetsBindingObserver {
  static const bool _notificationServiceTestMode = false;

  List<TaskModel> _tasks = [];
  List<LogEntry> _logs = [];
  List<TodoFolderModel> _todoFolders = [];
  List<ExpenseModel> _expenses = [];

  bool _isAwake = true;
  int _logIntervalMinutes = 60;
  bool _isPromptOwed = false;
  ThemeMode _themeMode = ThemeMode.dark;

  bool _isAiReady = false;
  String? _aiModelPath;

  // Tracks whether the last notification was answered (for auto-continue)
  DateTime? _notificationShownAt;

  Timer? _timer;

  List<TaskModel> get tasks => _tasks;
  List<LogEntry> get logs => _logs;
  List<TodoFolderModel> get todoFolders => _todoFolders;
  List<ExpenseModel> get expenses => _expenses;
  bool get isAwake => _isAwake;
  int get logIntervalMinutes => _logIntervalMinutes;
  bool get isPromptOwed => _isPromptOwed;
  ThemeMode get themeMode => _themeMode;
  bool get isAiReady => _isAiReady;
  String? get aiModelPath => _aiModelPath;

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
      checkPendingNotifications();
    }
  }

  Future<void> _init() async {
    await _loadSettings();
    await _loadPromptState();
    await _loadData();
    await checkPendingNotifications();
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

  Future<void> checkPendingNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    // Must reload to get latest disk values, as background isolate writes to the same file
    await prefs.reload();

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

    _aiModelPath = prefs.getString('ai_model_path');
    if (_aiModelPath != null) {
      final modelFile = File(_aiModelPath!);
      if (modelFile.existsSync()) {
        try {
          await FlutterGemma.installModel(
            modelType: ModelType.gemmaIt,
          ).fromFile(_aiModelPath!).install();

          // Warm up the model
          await FlutterGemma.getActiveModel(maxTokens: 512);

          _isAiReady = true;
        } catch (e) {
          debugPrint("Failed to init Gemma: $e");
          _isAiReady = false;
        }
      } else {
        // Path no longer valid (file deleted or temp path expired)
        _aiModelPath = null;
        await prefs.remove('ai_model_path');
      }
    }

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

        if (data['expenses'] != null) {
          _expenses = (data['expenses'] as List)
              .map((e) => ExpenseModel.fromJson(e))
              .toList();
          _expenses.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        }

        // Data Migration logic
        if (data['todo_folders'] != null) {
          _todoFolders = (data['todo_folders'] as List)
              .map((e) => TodoFolderModel.fromJson(e))
              .toList();
        } else if (data['todos'] != null) {
          // Legacy flat data
          final flatTodos = (data['todos'] as List)
              .map((e) => TodoModel.fromJson(e))
              .toList();
          if (flatTodos.isNotEmpty) {
            flatTodos.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
            _todoFolders = [
              TodoFolderModel(title: "Uncategorized", todos: flatTodos),
            ];
          }
        }

        // Sort
        _tasks.sort((a, b) => a.startTime.compareTo(b.startTime));
        _logs.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        notifyListeners();

        // Update widgets purely on startup so they fill in right away
        WidgetSyncService.updateWidgets(_tasks, []);
      }
    } catch (e) {
      debugPrint("Error loading data: $e");
    }
  }

  Future<void> importAiModel() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        String pickedPath = result.files.single.path!;
        String fileName = result.files.single.name;

        final directory = await getApplicationDocumentsDirectory();
        final targetPath = '${directory.path}/$fileName';

        // 1. Clean up the PREVIOUS model if it exists and is different, to save GBs of space
        final prefs = await SharedPreferences.getInstance();
        final oldPath = prefs.getString('ai_model_path');
        if (oldPath != null && oldPath != targetPath) {
          try {
            final oldFile = File(oldPath);
            if (oldFile.existsSync()) {
              await oldFile.delete();
              debugPrint("Deleted previous model file to save space.");
            }
          } catch (e) {
            debugPrint("Failed to delete old model: $e");
          }
        }

        // 2. Copy the new model to the application's internal documents folder
        // This is CRITICAL because file_picker paths are often temporary and expire.
        if (pickedPath != targetPath) {
          debugPrint("Copying model to persistent storage: $targetPath");
          await File(pickedPath).copy(targetPath);
        }

        // 3. Initialize Gemma with the persistent path
        await FlutterGemma.installModel(modelType: ModelType.gemmaIt)
            .fromFile(targetPath)
            .install();

        // 4. Warm up
        await FlutterGemma.getActiveModel(maxTokens: 512);

        _aiModelPath = targetPath;
        _isAiReady = true;

        await prefs.setString('ai_model_path', targetPath);
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error importing AI model: $e");
      _isAiReady = false;
      notifyListeners();
    }
  }

  Future<void> _saveData() async {
    try {
      final file = await _getDataFile();
      final data = {
        'tasks': _tasks.map((e) => e.toJson()).toList(),
        'logs': _logs.map((e) => e.toJson()).toList(),
        'todo_folders': _todoFolders.map((e) => e.toJson()).toList(),
        'expenses': _expenses.map((e) => e.toJson()).toList(),
      };
      await file.writeAsString(json.encode(data));

      // Update Android Home Widgets
      WidgetSyncService.updateWidgets(_tasks, []);
    } catch (e) {
      debugPrint("Error saving data: $e");
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      final now = DateTime.now();
      final minuteOfDay = now.hour * 60 + now.minute;
      final effectiveIntervalMinutes = _notificationServiceTestMode
          ? 1
          : _logIntervalMinutes;

      if (minuteOfDay % effectiveIntervalMinutes != 0) return;

      if (!_isAwake) {
        _addSleepLogIfNeeded(now, effectiveIntervalMinutes);
        return;
      }

      // Don't double-fire if already logged this exact minute
      if (_logs.isNotEmpty) {
        final last = _logs.last.timestamp;
        final lastMinute = last.hour * 60 + last.minute;
        final sameDay =
            last.year == now.year &&
            last.month == now.month &&
            last.day == now.day;
        if (sameDay && lastMinute == minuteOfDay && !_isPromptOwed) return;
      }

      // If we already prompted within the last interval length, don't double fire
      // If a full interval elapsed, they entirely missed it, so we auto-continue!
      if (_isPromptOwed && _notificationShownAt != null) {
        final diff = now.difference(_notificationShownAt!).inMinutes;
        if (diff < effectiveIntervalMinutes - 1) {
          return;
        } else {
          // A full interval passed, user ignored the prompt entirely!
          // Auto-continue the PREVIOUS ignored prompt
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
          _isPromptOwed = false;
        }
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
        effectiveIntervalMinutes,
        slotStart: now,
        slotEnd: now.add(Duration(minutes: effectiveIntervalMinutes)),
        currentTaskTitle: currentTaskTitle,
      );
      notifyListeners();
    });
  }

  DateTime _slotStart(DateTime now, int intervalMinutes) {
    final bucketMinute = (now.minute ~/ intervalMinutes) * intervalMinutes;
    return DateTime(now.year, now.month, now.day, now.hour, bucketMinute);
  }

  void _addSleepLogIfNeeded(DateTime now, int intervalMinutes) {
    final slot = _slotStart(now, intervalMinutes);
    final alreadyLogged = _logs.any(
      (l) => l.isSleep && l.timestamp == slot,
    );
    if (alreadyLogged) return;

    _insertLog(
      LogEntry(
        id: slot.millisecondsSinceEpoch.toString(),
        timestamp: slot,
        text: 'Sleeping...',
        isSleep: true,
      ),
    );
    notifyListeners();
    _saveData();
  }

  void clearPrompt() {
    _isPromptOwed = false;
    _notificationShownAt = null;
    _savePromptState();
    notifyListeners();
  }

  DateTime? get notificationShownAt => _notificationShownAt;

  void _insertLog(LogEntry entry) {
    if (entry.isSleep) {
      _logs.add(entry);
    } else {
      final t = entry.timestamp;

      // Calculate the start of the exact time block (e.g., 14:15, 14:30)
      final hourStart = DateTime(t.year, t.month, t.day, t.hour, 0);

      // We maintain logs conceptually at the start of the hour in the list,
      // but conceptually we want to build a string grouped by interval slices.
      final existingIdx = _logs.indexWhere(
        (l) => l.timestamp == hourStart && !l.isSleep,
      );
      final int nSlots = 60 ~/ _logIntervalMinutes;
      final int currentSlotIndex = (t.minute ~/ _logIntervalMinutes).clamp(
        0,
        nSlots - 1,
      );

      List<String> textParts;
      if (existingIdx != -1) {
        textParts = _logs[existingIdx].text
            .split(' • ')
            .map((e) => e.trim())
            .toList();
      } else {
        textParts = List.generate(nSlots, (_) => '');
      }

      // Pad array if previous interval settings caused fewer than expected parts
      while (textParts.length < nSlots) {
        textParts.add('');
      }

      var newText = entry.text;
      if (newText.startsWith('Continued: ')) {
        newText = newText.substring(11).trim();
      }

      textParts[currentSlotIndex] = newText;

      // Ensure continuity: if previous slots in the same hour are empty, fill them with the last known log
      String lastKnown = '';
      if (currentSlotIndex > 0) {
        // Try to find the most recent non-empty string in previous slots of THIS hour
        for (int i = currentSlotIndex - 1; i >= 0; i--) {
          if (textParts[i].isNotEmpty) {
            lastKnown = textParts[i];
            break;
          }
        }
      }

      // If we didn't find anything in this hour, look at previous hours
      if (lastKnown.isEmpty) {
        for (var i = _logs.length - 1; i >= 0; i--) {
          if (!_logs[i].isSleep && _logs[i].timestamp.isBefore(hourStart)) {
            final parts = _logs[i].text.split(' • ');
            lastKnown = parts.lastWhere(
              (p) => p.trim().isNotEmpty,
              orElse: () => '',
            );
            if (lastKnown.isNotEmpty) break;
          }
        }
      }

      // If we STILL don't have anything, use a default fallback
      if (lastKnown.isEmpty) {
        lastKnown =
            'Continued previous task'; // Or just leave empty depending on preference, but we'll fulfill continuity.
      }

      // Now fill any empty gaps up to the current slot index
      for (int i = 0; i <= currentSlotIndex; i++) {
        if (textParts[i].isEmpty) {
          // If we are at slot 0, and we pulled from previous hour, we fill it.
          // If we are > 0, we pulled from earlier slot or previous hour, we fill it.
          textParts[i] = lastKnown;
        }
      }

      final combinedText = textParts.join(' • ');

      if (existingIdx != -1) {
        _logs[existingIdx] = LogEntry(
          id: _logs[existingIdx].id,
          timestamp: hourStart,
          text: combinedText,
          isSleep: false,
        );
      } else {
        _logs.add(
          LogEntry(
            id: entry
                .id, // Or use hourStart.millisecondsSinceEpoch if tracking by hour ID
            timestamp: hourStart,
            text: combinedText,
            isSleep: false,
            category: entry.category,
          ),
        );
      }
    }
    _logs.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Kick off async background classification if AI is ready and text exists
    if (_isAiReady &&
        !entry.isSleep &&
        entry.text.trim().isNotEmpty &&
        entry.category == null) {
      _classifyLog(entry.id, entry.text);
    }
  }

  Future<void> _classifyLog(String id, String text) async {
    try {
      final prompt =
          "Classify this short activity log '$text' strictly into one of the following four categories: 'Exercise', 'Study', 'Social', or 'Time Waste'. Return only the category name exactly as it appears in the list, no punctuation or extra words.";

      final activeModel = await FlutterGemma.getActiveModel(maxTokens: 512);
      final chat = await activeModel.createChat();
      await chat.addQuery(Message(text: prompt, isUser: true));

      final response = await chat.generateChatResponse();
      final responseText = response is TextResponse ? response.token : "";

      final clean = responseText.trim().replaceAll("'", "").replaceAll(".", "");

      String matchedCategory = "miscellaneous";
      if (clean.contains("Exercise") || clean.contains("exercise"))
        matchedCategory = "Exercise";
      else if (clean.contains("Study") || clean.contains("study"))
        matchedCategory = "Study";
      else if (clean.contains("Social") || clean.contains("social"))
        matchedCategory = "Social";
      else if (clean.contains("Time") ||
          clean.contains("time") ||
          clean.contains("Waste"))
        matchedCategory = "Time Waste";

      final idx = _logs.indexWhere((l) => l.id == id);
      if (idx != -1) {
        _logs[idx] = _logs[idx].copyWith(category: matchedCategory);
        notifyListeners();
        _saveData();
      }
    } catch (e) {
      debugPrint("Classification error: $e");
    }
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

  /// Manually log entry for the current active time block, replacing what's there
  Future<void> logNowForCurrentBlock(String text) async {
    final now = DateTime.now();
    await addLog(
      LogEntry(
        id: now.millisecondsSinceEpoch.toString(),
        timestamp: now,
        text: text,
        isSleep: false,
      ),
    );
  }

  /// Updates the text of an existing log entry (used by the edit dialog).
  Future<void> updateLog(LogEntry updated) async {
    final idx = _logs.indexWhere((l) => l.id == updated.id);
    if (idx != -1) {
      final old = _logs[idx];
      final textChanged = old.text != updated.text;

      _logs[idx] = updated;

      // If text changed, re-classify
      if (textChanged && _isAiReady && !updated.isSleep) {
        // Clear category first to show it's pending re-classification
        _logs[idx] = _logs[idx].copyWith(category: null);
        _classifyLog(updated.id, updated.text);
      }
    } else {
      _logs.add(updated);
      _logs.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      if (_isAiReady && !updated.isSleep && updated.category == null) {
        _classifyLog(updated.id, updated.text);
      }
    }
    notifyListeners();
    await _saveData();
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
      clearPrompt();
      await NotificationService.instance.cancelLogNotification();
      final now = DateTime.now();
      final effectiveIntervalMinutes = _notificationServiceTestMode
          ? 1
          : _logIntervalMinutes;
      _addSleepLogIfNeeded(now, effectiveIntervalMinutes);
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

  // ─── AI Todo Folders ────────────────────────────────────────────────────────

  Future<void> generateAiTodoFolder(String prompt) async {
    if (!_isAiReady) return;

    try {
      final fullPrompt =
          "Based on the goal '$prompt', create a short task list.\n"
          "Reply EXACTLY with this structure, starting immediately with TITLE:\n"
          "TITLE: [Generate a 2-3 word folder name]\n"
          "- [Task 1]\n"
          "- [Task 2]\n"
          "- [Task 3]";

      final activeModel = await FlutterGemma.getActiveModel(maxTokens: 512);
      final chat = await activeModel.createChat();
      await chat.addQuery(Message(text: fullPrompt, isUser: true));

      final response = await chat.generateChatResponse();
      final content = response is TextResponse ? response.token.trim() : "";

      String folderTitle = "AI Generated Plan";
      List<TodoModel> newTodos = [];

      final lines = content.split('\n');
      for (final line in lines) {
        final cleanLine = line.trim();
        if (cleanLine.startsWith('TITLE:')) {
          folderTitle = cleanLine.substring(6).trim();
          folderTitle = folderTitle
              .replaceAll('[', '')
              .replaceAll(']', '')
              .trim();
        } else if (cleanLine.startsWith('-')) {
          String taskText = cleanLine.substring(1).trim();
          taskText = taskText.replaceAll('[', '').replaceAll(']', '').trim();
          if (taskText.isNotEmpty) {
            newTodos.add(
              TodoModel(
                id:
                    DateTime.now().millisecondsSinceEpoch.toString() +
                    newTodos.length.toString(),
                text: taskText,
                orderIndex: newTodos.length,
              ),
            );
          }
        }
      }

      if (newTodos.isNotEmpty) {
        _todoFolders.insert(
          0,
          TodoFolderModel(title: folderTitle, todos: newTodos),
        );
        notifyListeners();
        await _saveData();
      }
    } catch (e) {
      debugPrint("AI Plan error: $e");
    }
  }

  // ─── Todo Folders ───────────────────────────────────────────────────────────

  Future<void> addTodoFolder(String title) async {
    _todoFolders.insert(0, TodoFolderModel(title: title));
    notifyListeners();
    await _saveData();
  }

  Future<void> removeTodoFolder(String folderId) async {
    _todoFolders.removeWhere((f) => f.id == folderId);
    notifyListeners();
    await _saveData();
  }

  Future<void> addTodoToFolder(
    String folderId,
    String text,
    int colorIndex,
  ) async {
    final folderIdx = _todoFolders.indexWhere((f) => f.id == folderId);
    if (folderIdx != -1) {
      final folder = _todoFolders[folderIdx];
      final newId = DateTime.now().millisecondsSinceEpoch.toString();
      final newOrder = folder.todos.isEmpty
          ? 0
          : folder.todos.last.orderIndex + 1;

      final updatedTodos = List<TodoModel>.from(folder.todos);
      updatedTodos.add(
        TodoModel(
          id: newId,
          text: text,
          colorIndex: colorIndex,
          orderIndex: newOrder,
        ),
      );

      _todoFolders[folderIdx] = folder.copyWith(todos: updatedTodos);
      notifyListeners();
      await _saveData();
    }
  }

  Future<void> updateTodoColor(
    String folderId,
    String todoId,
    int colorIndex,
  ) async {
    final folderIdx = _todoFolders.indexWhere((f) => f.id == folderId);
    if (folderIdx != -1) {
      final folder = _todoFolders[folderIdx];
      final tIdx = folder.todos.indexWhere((t) => t.id == todoId);
      if (tIdx != -1) {
        final updatedTodos = List<TodoModel>.from(folder.todos);
        updatedTodos[tIdx] = updatedTodos[tIdx].copyWith(
          colorIndex: colorIndex,
        );
        _todoFolders[folderIdx] = folder.copyWith(todos: updatedTodos);
        notifyListeners();
        await _saveData();
      }
    }
  }

  Future<void> updateTodoText(
    String folderId,
    String todoId,
    String text,
  ) async {
    final folderIdx = _todoFolders.indexWhere((f) => f.id == folderId);
    if (folderIdx != -1) {
      final folder = _todoFolders[folderIdx];
      final tIdx = folder.todos.indexWhere((t) => t.id == todoId);
      if (tIdx != -1) {
        final updatedTodos = List<TodoModel>.from(folder.todos);
        updatedTodos[tIdx] = updatedTodos[tIdx].copyWith(text: text);
        _todoFolders[folderIdx] = folder.copyWith(todos: updatedTodos);
        notifyListeners();
        await _saveData();
      }
    }
  }

  Future<void> toggleTodo(String folderId, String todoId) async {
    final folderIdx = _todoFolders.indexWhere((f) => f.id == folderId);
    if (folderIdx != -1) {
      final folder = _todoFolders[folderIdx];
      final tIdx = folder.todos.indexWhere((t) => t.id == todoId);
      if (tIdx != -1) {
        final updatedTodos = List<TodoModel>.from(folder.todos);
        updatedTodos[tIdx] = updatedTodos[tIdx].copyWith(
          isDone: !updatedTodos[tIdx].isDone,
        );
        _todoFolders[folderIdx] = folder.copyWith(todos: updatedTodos);
        notifyListeners();
        await _saveData();
      }
    }
  }

  Future<void> reorderTodos(String folderId, int oldIndex, int newIndex) async {
    final folderIdx = _todoFolders.indexWhere((f) => f.id == folderId);
    if (folderIdx != -1) {
      final folder = _todoFolders[folderIdx];
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final updatedTodos = List<TodoModel>.from(folder.todos);
      final item = updatedTodos.removeAt(oldIndex);
      updatedTodos.insert(newIndex, item);

      for (int i = 0; i < updatedTodos.length; i++) {
        updatedTodos[i] = updatedTodos[i].copyWith(orderIndex: i);
      }
      _todoFolders[folderIdx] = folder.copyWith(todos: updatedTodos);
      notifyListeners();
      await _saveData();
    }
  }

  Future<void> removeTodo(String folderId, String todoId) async {
    final folderIdx = _todoFolders.indexWhere((f) => f.id == folderId);
    if (folderIdx != -1) {
      final folder = _todoFolders[folderIdx];
      final updatedTodos = List<TodoModel>.from(folder.todos)
        ..removeWhere((t) => t.id == todoId);
      _todoFolders[folderIdx] = folder.copyWith(todos: updatedTodos);
      notifyListeners();
      await _saveData();
    }
  }

  // ─── Expenses ────────────────────────────────────────────────────────────────

  Future<void> addExpense(ExpenseModel expense) async {
    _expenses.insert(0, expense);
    notifyListeners();
    await _saveData();
    if (_isAiReady) _classifyExpense(expense.id, expense.title);
  }

  Future<void> updateExpense(ExpenseModel updated) async {
    final idx = _expenses.indexWhere((e) => e.id == updated.id);
    if (idx != -1) {
      _expenses[idx] = updated;
    } else {
      _expenses.insert(0, updated);
    }
    _expenses.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    notifyListeners();
    await _saveData();
  }

  Future<void> removeExpense(String id) async {
    _expenses.removeWhere((e) => e.id == id);
    notifyListeners();
    await _saveData();
  }

  Future<void> _classifyExpense(String id, String title) async {
    try {
      const cats = 'Food, Travelling, Clothes, Gadgets, Medical, Other';
      final prompt =
          "Classify this expense description strictly into one of these categories: $cats. "
          "Return ONLY the category name, nothing else. "
          "Description: $title";
      final activeModel = await FlutterGemma.getActiveModel(maxTokens: 64);
      final chat = await activeModel.createChat();
      await chat.addQuery(Message(text: prompt, isUser: true));
      final response = await chat.generateChatResponse();
      final raw =
          (response is TextResponse ? response.token : '').trim().replaceAll('.', '');
      const allowed = ['Food', 'Travelling', 'Clothes', 'Gadgets', 'Medical'];
      final matched =
          allowed.firstWhere(
            (c) => raw.toLowerCase().contains(c.toLowerCase()),
            orElse: () => 'Other',
          );
      final idx = _expenses.indexWhere((e) => e.id == id);
      if (idx != -1) {
        _expenses[idx] = _expenses[idx].copyWith(category: matched);
        notifyListeners();
        await _saveData();
      }
    } catch (e) {
      debugPrint('Expense classify error: $e');
    }
  }

  // ─── Export & Import ────────────────────────────────────────────────────────
  Future<String?> exportData() async {
    try {
      String? outputFile;
      try {
        outputFile = await FilePicker.platform.saveFile(
          dialogTitle: 'Please select an output file:',
          fileName: 'timelog_export.json',
        );
      } catch (e) {
        debugPrint("Export save picker unavailable: $e");
        outputFile = null;
      }
      final data = {
        'tasks': _tasks.map((e) => e.toJson()).toList(),
        'logs': _logs.map((e) => e.toJson()).toList(),
        'todo_folders': _todoFolders.map((e) => e.toJson()).toList(),
        'expenses': _expenses.map((e) => e.toJson()).toList(),
      };

      // Some platforms may return null immediately if save-file picker is unsupported.
      // Fallback to app documents so export still succeeds.
      if (outputFile == null || outputFile.trim().isEmpty) {
        if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
          outputFile = '${Directory.current.path}/timelog_export.json';
        } else if (Platform.isAndroid) {
          outputFile = '/storage/emulated/0/Download/timelog_export.json';
        } else {
          final dir = await getApplicationDocumentsDirectory();
          outputFile = '${dir.path}/timelog_export.json';
        }
      }

      try {
        await File(outputFile).writeAsString(json.encode(data));
        return outputFile;
      } catch (_) {
        final dir = await getApplicationDocumentsDirectory();
        final fallbackPath = '${dir.path}/timelog_export.json';
        await File(fallbackPath).writeAsString(json.encode(data));
        return fallbackPath;
      }
    } catch (e) {
      debugPrint("Export error: $e");
    }
    return null;
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

        if (data['todo_folders'] != null) {
          final importedFolders = (data['todo_folders'] as List).map(
            (e) => TodoFolderModel.fromJson(e),
          );
          for (final importedFolder in importedFolders) {
            final existingFolderIdx = _todoFolders.indexWhere(
              (f) => f.id == importedFolder.id,
            );

            if (existingFolderIdx == -1) {
              final sortedTodos = List<TodoModel>.from(importedFolder.todos)
                ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
              _todoFolders.add(importedFolder.copyWith(todos: sortedTodos));
              changed = true;
              continue;
            }

            final existingFolder = _todoFolders[existingFolderIdx];
            final mergedTodos = List<TodoModel>.from(existingFolder.todos);
            var folderChanged = false;

            for (final importedTodo in importedFolder.todos) {
              if (!mergedTodos.any((t) => t.id == importedTodo.id)) {
                mergedTodos.add(importedTodo);
                folderChanged = true;
              }
            }

            if (folderChanged ||
                existingFolder.title.trim() != importedFolder.title.trim()) {
              mergedTodos.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
              _todoFolders[existingFolderIdx] = existingFolder.copyWith(
                title: importedFolder.title,
                todos: mergedTodos,
              );
              changed = true;
            }
          }
        } else if (data['todos'] != null) {
          // Backward compatibility with older exports that stored flat todos.
          final importedTodos = (data['todos'] as List).map(
            (e) => TodoModel.fromJson(e),
          );
          if (importedTodos.isNotEmpty) {
            var uncategorizedIdx = _todoFolders.indexWhere(
              (f) => f.title.trim().toLowerCase() == 'uncategorized',
            );
            if (uncategorizedIdx == -1) {
              _todoFolders.add(TodoFolderModel(title: 'Uncategorized'));
              uncategorizedIdx = _todoFolders.length - 1;
              changed = true;
            }

            final target = _todoFolders[uncategorizedIdx];
            final merged = List<TodoModel>.from(target.todos);
            var folderChanged = false;
            for (final todo in importedTodos) {
              if (!merged.any((t) => t.id == todo.id)) {
                merged.add(todo);
                folderChanged = true;
              }
            }
            if (folderChanged) {
              merged.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
              _todoFolders[uncategorizedIdx] = target.copyWith(todos: merged);
              changed = true;
            }
          }
        }

        if (data['expenses'] != null) {
          final importedExpenses = (data['expenses'] as List).map(
            (e) => ExpenseModel.fromJson(e),
          );
          for (final exp in importedExpenses) {
            if (!_expenses.any((existing) => existing.id == exp.id)) {
              _expenses.add(exp);
              changed = true;
            }
          }
        }

        if (changed) {
          _tasks.sort((a, b) => a.startTime.compareTo(b.startTime));
          _logs.sort((a, b) => a.timestamp.compareTo(b.timestamp));
          _expenses.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          for (int i = 0; i < _todoFolders.length; i++) {
            final sortedTodos = List<TodoModel>.from(_todoFolders[i].todos)
              ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
            _todoFolders[i] = _todoFolders[i].copyWith(todos: sortedTodos);
          }
          notifyListeners();
          await _saveData();
        }
      }
    } catch (e) {
      debugPrint("Import error: $e");
    }
  }
}
