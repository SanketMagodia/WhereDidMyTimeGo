import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
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
import '../models/journal_entry_model.dart';
import '../models/sip_model.dart';
import '../models/stock_model.dart';
import '../models/daily_checklist_item_model.dart';
import '../services/notification_service.dart';
import '../services/widget_sync_service.dart';
import '../services/calendar_sync_service.dart';

class AppProvider extends ChangeNotifier with WidgetsBindingObserver {
  static const bool _notificationServiceTestMode = false;

  List<TaskModel> _tasks = [];
  List<LogEntry> _logs = [];
  List<TodoFolderModel> _todoFolders = [];
  List<ExpenseModel> _expenses = [];
  List<JournalEntryModel> _journalEntries = [];
  List<FixedExpenseTemplate> _fixedTemplates = [];
  List<SipModel> _sips = [];
  List<StockModel> _stocks = [];
  // "YYYY-MM" of the last month fixed expenses were applied
  String _lastFixedAppliedMonth = '';

  List<DailyChecklistItemModel> _dailyChecklistItems = [];

  /// yyyy-MM-dd -> item ids checked that calendar day
  final Map<String, List<String>> _dailyChecklistChecksByDate = {};

  String _userName = '';

  bool _isAwake = true;
  // When the user toggled to sleep — used to backfill all missed slots on wake.
  DateTime? _sleepStartTime;
  int _logIntervalMinutes = 60;
  bool _isPromptOwed = false;
  ThemeMode _themeMode = ThemeMode.dark;

  bool _isAiReady = false;
  String? _aiModelPath;

  bool _calendarSyncEnabled = false;
  bool get calendarSyncEnabled => _calendarSyncEnabled;

  /// Selected calendar is read-only (import only; cannot write app tasks back).
  bool _calendarReadOnly = false;
  bool get calendarReadOnly => _calendarReadOnly;

  /// Writable calendar: both import and push (app tasks → device calendar).
  bool get mirrorsTasksToCalendar => _calendarSyncEnabled && !_calendarReadOnly;

  // Tracks whether the last notification was answered (for auto-continue)
  DateTime? _notificationShownAt;

  Timer? _timer;

  List<TaskModel> get tasks => _tasks;
  List<LogEntry> get logs => _logs;
  List<TodoFolderModel> get todoFolders => _todoFolders;
  List<ExpenseModel> get expenses => _expenses;
  List<JournalEntryModel> get journalEntries => _journalEntries;
  List<FixedExpenseTemplate> get fixedTemplates => _fixedTemplates;
  List<SipModel> get sips => _sips;
  List<StockModel> get stocks => _stocks;

  List<DailyChecklistItemModel> get dailyChecklistItems {
    final copy = List<DailyChecklistItemModel>.from(_dailyChecklistItems);
    copy.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    return copy;
  }

  String get userName => _userName;
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
      // If the user was sleeping while the app was backgrounded,
      // backfill any interval slots the timer missed.
      if (!_isAwake && _sleepStartTime != null) {
        _backfillSleepLogs(DateTime.now());
      }
      _syncLogsWithClock(DateTime.now());
      _schedulePrompts(); // Ensure alarms are refreshed
    }
  }

  Future<void> _init() async {
    await _loadSettings();
    await _loadPromptState();
    await _loadData();
    await checkPendingNotifications();
    _startClockSync();
    _schedulePrompts();
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
    _calendarSyncEnabled = prefs.getBool('calendarSyncEnabled') ?? false;
    _calendarReadOnly = prefs.getBool('calendarReadOnly') ?? false;
    final calId = prefs.getString('calendarId');
    if (calId != null) CalendarSyncService.instance.setCalendarId(calId);

    _isAwake = prefs.getBool('isAwake') ?? true;
    final sleepStartStr = prefs.getString('sleepStartTime');
    _sleepStartTime = sleepStartStr != null
        ? DateTime.tryParse(sleepStartStr)
        : null;
    // If app relaunched while still sleeping, backfill any missed slots immediately
    if (!_isAwake && _sleepStartTime != null) {
      _backfillSleepLogs(DateTime.now());
    }
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
    await prefs.setBool('calendarSyncEnabled', _calendarSyncEnabled);
    await prefs.setBool('calendarReadOnly', _calendarReadOnly);
    final calId = CalendarSyncService.instance.calendarId;
    if (calId != null) {
      await prefs.setString('calendarId', calId);
    } else {
      await prefs.remove('calendarId');
    }
    if (_sleepStartTime != null) {
      await prefs.setString(
        'sleepStartTime',
        _sleepStartTime!.toIso8601String(),
      );
    } else {
      await prefs.remove('sleepStartTime');
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    await saveSettings();
  }

  Future<void> setUserName(String name) async {
    _userName = name.trim();
    notifyListeners();
    await _saveData();
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

        _userName = data['userName'] as String? ?? '';

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
        if (data['journals'] != null) {
          _journalEntries = (data['journals'] as List)
              .map((e) => JournalEntryModel.fromJson(e))
              .toList();
          _journalEntries.sort((a, b) => b.date.compareTo(a.date));
        }

        if (data['fixed_templates'] != null) {
          _fixedTemplates = (data['fixed_templates'] as List)
              .map((e) => FixedExpenseTemplate.fromJson(e))
              .toList();
        }

        if (data['sips'] != null) {
          _sips = (data['sips'] as List)
              .map((e) => SipModel.fromJson(e))
              .toList();
        }

        if (data['stocks'] != null) {
          _stocks = (data['stocks'] as List)
              .map((e) => StockModel.fromJson(e))
              .toList();
        }

        _lastFixedAppliedMonth =
            data['last_fixed_applied_month'] as String? ?? '';
        _applyFixedExpensesIfNeeded();

        // Data Migration logic
        if (data['daily_checklist_items'] != null) {
          _dailyChecklistItems = (data['daily_checklist_items'] as List)
              .map(
                (e) => DailyChecklistItemModel.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
        if (data['daily_checklist_checks'] != null) {
          _dailyChecklistChecksByDate.clear();
          final raw = data['daily_checklist_checks'] as Map<String, dynamic>;
          for (final e in raw.entries) {
            final ids = (e.value as List)
                .map((x) => x.toString())
                .toList(growable: false);
            if (ids.isNotEmpty) {
              _dailyChecklistChecksByDate[e.key] = ids;
            }
          }
        }

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
        await FlutterGemma.installModel(
          modelType: ModelType.gemmaIt,
        ).fromFile(targetPath).install();

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
        'userName': _userName,
        'tasks': _tasks.map((e) => e.toJson()).toList(),
        'logs': _logs.map((e) => e.toJson()).toList(),
        'todo_folders': _todoFolders.map((e) => e.toJson()).toList(),
        'expenses': _expenses.map((e) => e.toJson()).toList(),
        'journals': _journalEntries.map((e) => e.toJson()).toList(),
        'fixed_templates': _fixedTemplates.map((e) => e.toJson()).toList(),
        'sips': _sips.map((e) => e.toJson()).toList(),
        'stocks': _stocks.map((e) => e.toJson()).toList(),
        'last_fixed_applied_month': _lastFixedAppliedMonth,
        'daily_checklist_items': _dailyChecklistItems
            .map((e) => e.toJson())
            .toList(),
        'daily_checklist_checks': _dailyChecklistChecksByDate.map(
          (k, v) => MapEntry(k, v),
        ),
      };
      await file.writeAsString(json.encode(data));

      // Update Android Home Widgets
      _saveDataAndUpdateWidgets();
    } catch (e) {
      debugPrint("Error saving data: $e");
    }
  }

  void _saveDataAndUpdateWidgets() {
    // _saveData() is already called by the caller of this method.
    // This method is intended to handle post-save actions.
    WidgetSyncService.updateWidgets(_tasks, _todoFolders);
    _schedulePrompts(); // Ensure notifications update if task schedule changes
  }

  void _startClockSync() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 45), (timer) {
      _syncLogsWithClock(DateTime.now());
    });
    _syncLogsWithClock(DateTime.now()); // First sync immediately
  }

  void _schedulePrompts() {
    final effectiveIntervalMinutes = _notificationServiceTestMode
        ? 1
        : _logIntervalMinutes;
    NotificationService.instance.scheduleUpcomingPrompts(
      intervalMinutes: effectiveIntervalMinutes,
      isAwake: _isAwake,
      getTaskTitleAt: (time) {
        try {
          final ongoing = _tasks.firstWhere(
            (t) => t.startTime.isBefore(time) && t.endTime.isAfter(time),
          );
          return ongoing.title;
        } catch (_) {
          return null;
        }
      },
    );
  }

  void _syncLogsWithClock(DateTime now) {
    final effectiveIntervalMinutes = _notificationServiceTestMode
        ? 1
        : _logIntervalMinutes;

    if (!_isAwake) {
      _addSleepLogIfNeeded(now, effectiveIntervalMinutes);
      return;
    }

    final currentBoundaryMin =
        (now.minute ~/ effectiveIntervalMinutes) * effectiveIntervalMinutes;
    final currentBoundary = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      currentBoundaryMin,
    );

    // 1. Check for completely missed intervals and backfill 'Continued previous task'
    if (_logs.isNotEmpty) {
      DateTime? lastTime;
      String lastText = 'Continued previous task';
      for (var i = _logs.length - 1; i >= 0; i--) {
        if (!_logs[i].isSleep) {
          lastTime = _logs[i].timestamp;
          lastText = _logs[i].text.split(' • ').last;
          if (lastText.startsWith('Continued: ')) {
            lastText = lastText.substring(11).trim();
          }
          break;
        }
      }

      if (lastTime != null) {
        final int nextBucket =
            ((lastTime.minute ~/ effectiveIntervalMinutes) + 1) *
            effectiveIntervalMinutes;
        var nextSlot = DateTime(
          lastTime.year,
          lastTime.month,
          lastTime.day,
          lastTime.hour,
          0,
        ).add(Duration(minutes: nextBucket));

        bool changed = false;
        while (nextSlot.isBefore(currentBoundary)) {
          _insertLog(
            LogEntry(
              id: nextSlot.millisecondsSinceEpoch.toString(),
              timestamp: nextSlot,
              text: 'Continued: $lastText',
            ),
          );
          changed = true;
          nextSlot = nextSlot.add(Duration(minutes: effectiveIntervalMinutes));
        }
        if (changed) {
          _saveData();
        }
      }
    }

    // 2. Determine if a prompt is owed for the CURRENT interval boundary
    bool owesPrompt = true;
    final hourStart = DateTime(
      currentBoundary.year,
      currentBoundary.month,
      currentBoundary.day,
      currentBoundary.hour,
      0,
    );
    for (var i = _logs.length - 1; i >= 0; i--) {
      if (!_logs[i].isSleep && _logs[i].timestamp.isAtSameMomentAs(hourStart)) {
        final int currentSlotIndex =
            (currentBoundary.minute ~/ effectiveIntervalMinutes).clamp(
              0,
              (60 ~/ effectiveIntervalMinutes) - 1,
            );
        final parts = _logs[i].text.split(' • ');
        // Safely check if the corresponding string part is not actually 'Continued previous task' which we might have injected.
        // However, if it's not empty, it counts as logged.
        if (parts.length > currentSlotIndex &&
            parts[currentSlotIndex].trim().isNotEmpty) {
          owesPrompt = false;
        }
        break;
      }
    }

    if (_isPromptOwed != owesPrompt ||
        _notificationShownAt != (owesPrompt ? currentBoundary : null)) {
      _isPromptOwed = owesPrompt;
      _notificationShownAt = owesPrompt ? currentBoundary : null;
      _savePromptState();
      notifyListeners();
    }
  }

  DateTime _slotStart(DateTime now, int intervalMinutes) {
    final bucketMinute = (now.minute ~/ intervalMinutes) * intervalMinutes;
    return DateTime(now.year, now.month, now.day, now.hour, bucketMinute);
  }

  void _addSleepLogIfNeeded(DateTime now, int intervalMinutes) {
    final slot = _slotStart(now, intervalMinutes);
    final alreadyLogged = _logs.any((l) => l.isSleep && l.timestamp == slot);
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

  /// Fills every interval slot from [_sleepStartTime] to [until] with a sleep log.
  /// Called when waking up or on app resume while sleeping.
  void _backfillSleepLogs(DateTime until) {
    if (_sleepStartTime == null) return;
    final intervalMinutes = _notificationServiceTestMode
        ? 1
        : _logIntervalMinutes;

    // Start from the first interval boundary at or after sleep start
    final start = _sleepStartTime!;
    // Round start UP to the next slot boundary
    final startMin = start.hour * 60 + start.minute;
    final firstBucket = ((startMin ~/ intervalMinutes) + 1) * intervalMinutes;
    final firstSlot = DateTime(
      start.year,
      start.month,
      start.day,
    ).add(Duration(minutes: firstBucket));

    bool added = false;
    var slot = firstSlot;
    while (!slot.isAfter(until)) {
      final alreadyLogged = _logs.any((l) => l.isSleep && l.timestamp == slot);
      if (!alreadyLogged) {
        _insertLog(
          LogEntry(
            id: slot.millisecondsSinceEpoch.toString(),
            timestamp: slot,
            text: 'Sleeping...',
            isSleep: true,
          ),
        );
        added = true;
      }
      slot = slot.add(Duration(minutes: intervalMinutes));
    }

    if (added) {
      notifyListeners();
      _saveData();
    }
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
    await NotificationService.instance.clearActiveNotifications();
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
    final now = DateTime.now();
    _isAwake = awake;

    if (awake) {
      // Backfill every sleep slot from when they fell asleep until now
      _backfillSleepLogs(now);
      _sleepStartTime = null;
      notifyListeners();
      await saveSettings();
      _syncLogsWithClock(now);
      _schedulePrompts();
    } else {
      clearPrompt();
      await NotificationService.instance.cancelAll();
      // Record exactly when they went to sleep
      _sleepStartTime = now;
      notifyListeners();
      await saveSettings();
      // Immediately log the current slot as sleeping
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
    _schedulePrompts();
    _syncLogsWithClock(DateTime.now());
  }

  // ── Calendar sync public API ────────────────────────────────────────────────

  /// Links a device calendar: imports its events into Schedule; if the calendar
  /// is writable, app tasks are also written back (same as legacy “sync”).
  ///
  /// Returns imported event count on success, `-1` if permission denied when
  /// enabling, or `0` when disabling.
  Future<int> setCalendarSync(
    bool enabled, {
    String? calendarId,
    bool calendarReadOnly = false,
  }) async {
    if (!enabled) {
      _calendarSyncEnabled = false;
      _calendarReadOnly = false;
      CalendarSyncService.instance.setCalendarId(null);
      notifyListeners();
      await saveSettings();
      return 0;
    }
    final granted = await CalendarSyncService.instance.requestPermission();
    if (!granted) return -1;
    if (calendarId != null) {
      CalendarSyncService.instance.setCalendarId(calendarId);
    }
    _calendarReadOnly = calendarReadOnly;
    _calendarSyncEnabled = true;
    notifyListeners();
    await saveSettings();
    final imported = await importTasksFromPhoneCalendar();
    if (mirrorsTasksToCalendar) {
      await _pushAllTasksToCalendar();
    }
    return imported;
  }

  Future<void> _pushAllTasksToCalendar() async {
    final idMap = await CalendarSyncService.instance.fullSync(_tasks);
    for (final entry in idMap.entries) {
      final idx = _tasks.indexWhere((t) => t.id == entry.key);
      if (idx != -1) {
        _tasks[idx] = _tasks[idx].copyWith(calendarEventId: entry.value);
      }
    }
    await _saveData();
    notifyListeners();
  }

  /// Imports events from selected phone calendar into app schedule.
  /// Returns number of newly imported tasks.
  Future<int> importTasksFromPhoneCalendar({
    DateTime? from,
    DateTime? to,
  }) async {
    final imported = await CalendarSyncService.instance.importEventsAsTasks(
      from: from,
      to: to,
    );
    if (imported.isEmpty) return 0;

    int added = 0;
    for (final t in imported) {
      final exists = _tasks.any((existing) {
        if (t.calendarEventId != null &&
            existing.calendarEventId != null &&
            existing.calendarEventId == t.calendarEventId) {
          return true;
        }
        return existing.startTime == t.startTime &&
            existing.endTime == t.endTime &&
            existing.title == t.title;
      });
      if (!exists) {
        _tasks.add(t);
        added++;
      }
    }

    if (added > 0) {
      _tasks.sort((a, b) => a.startTime.compareTo(b.startTime));
      notifyListeners();
      await _saveData();
    }
    return added;
  }

  // ── Task mutations (with calendar sync) ─────────────────────────────────────

  Future<void> addTask(TaskModel task) async {
    var taskToAdd = task;
    if (mirrorsTasksToCalendar) {
      final eventId = await CalendarSyncService.instance.syncTask(task);
      if (eventId != null) taskToAdd = task.copyWith(calendarEventId: eventId);
    }
    _tasks.add(taskToAdd);
    _tasks.sort((a, b) => a.startTime.compareTo(b.startTime));
    notifyListeners();
    await _saveData();
  }

  Future<void> removeTask(String id) async {
    if (mirrorsTasksToCalendar) {
      final task = _tasks.firstWhere(
        (t) => t.id == id,
        orElse: () => _tasks.first,
      );
      if (task.calendarEventId != null) {
        await CalendarSyncService.instance.deleteEvent(task.calendarEventId!);
      }
    }
    _tasks.removeWhere((t) => t.id == id);
    notifyListeners();
    await _saveData();
  }

  Future<void> updateTask(TaskModel updatedTask) async {
    final index = _tasks.indexWhere((t) => t.id == updatedTask.id);
    if (index != -1) {
      var taskToUpdate = updatedTask;
      if (mirrorsTasksToCalendar) {
        final eventId = await CalendarSyncService.instance.syncTask(
          updatedTask,
        );
        if (eventId != null) {
          taskToUpdate = updatedTask.copyWith(calendarEventId: eventId);
        }
      }
      _tasks[index] = taskToUpdate;
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
        var shifted = task.copyWith(
          startTime: task.startTime.add(shiftDuration),
          endTime: task.endTime.add(shiftDuration),
        );
        if (mirrorsTasksToCalendar) {
          final eventId = await CalendarSyncService.instance.syncTask(shifted);
          if (eventId != null) {
            shifted = shifted.copyWith(calendarEventId: eventId);
          }
        }
        _tasks[i] = shifted;
        changed = true;
      }
    }

    if (changed) {
      _tasks.sort((a, b) => a.startTime.compareTo(b.startTime));
      notifyListeners();
      await _saveData();
    }
  }

  // ─── Daily checklist (resets completion per calendar day) ───────────────────

  static String _dailyChecklistDateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  bool isDailyChecklistItemChecked(String itemId, DateTime date) {
    final key = _dailyChecklistDateKey(date);
    return _dailyChecklistChecksByDate[key]?.contains(itemId) ?? false;
  }

  Future<void> toggleDailyChecklistItem(String itemId, DateTime date) async {
    final key = _dailyChecklistDateKey(date);
    final list = List<String>.from(_dailyChecklistChecksByDate[key] ?? []);
    if (list.contains(itemId)) {
      list.remove(itemId);
    } else {
      list.add(itemId);
    }
    if (list.isEmpty) {
      _dailyChecklistChecksByDate.remove(key);
    } else {
      _dailyChecklistChecksByDate[key] = list;
    }
    notifyListeners();
    await _saveData();
  }

  ({int checked, int total}) dailyChecklistProgress(DateTime date) {
    final total = _dailyChecklistItems.length;
    if (total == 0) return (checked: 0, total: 0);
    final key = _dailyChecklistDateKey(date);
    final done = _dailyChecklistChecksByDate[key]?.toSet() ?? {};
    var n = 0;
    for (final i in _dailyChecklistItems) {
      if (done.contains(i.id)) n++;
    }
    return (checked: n, total: total);
  }

  Future<void> addDailyChecklistItem(String title) async {
    final t = title.trim();
    if (t.isEmpty) return;
    final maxOrder = _dailyChecklistItems.isEmpty
        ? -1
        : _dailyChecklistItems.map((e) => e.orderIndex).reduce(math.max);
    _dailyChecklistItems.add(
      DailyChecklistItemModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: t,
        orderIndex: maxOrder + 1,
      ),
    );
    notifyListeners();
    await _saveData();
  }

  Future<void> updateDailyChecklistItemTitle(String id, String title) async {
    final t = title.trim();
    if (t.isEmpty) return;
    final idx = _dailyChecklistItems.indexWhere((e) => e.id == id);
    if (idx == -1) return;
    _dailyChecklistItems[idx] = _dailyChecklistItems[idx].copyWith(title: t);
    notifyListeners();
    await _saveData();
  }

  Future<void> removeDailyChecklistItem(String id) async {
    _dailyChecklistItems.removeWhere((e) => e.id == id);
    for (final k in _dailyChecklistChecksByDate.keys.toList()) {
      final list = List<String>.from(_dailyChecklistChecksByDate[k] ?? []);
      list.remove(id);
      if (list.isEmpty) {
        _dailyChecklistChecksByDate.remove(k);
      } else {
        _dailyChecklistChecksByDate[k] = list;
      }
    }
    notifyListeners();
    await _saveData();
  }

  Future<void> reorderDailyChecklistItems(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) newIndex -= 1;
    final sorted = List<DailyChecklistItemModel>.from(_dailyChecklistItems)
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    if (oldIndex < 0 ||
        oldIndex >= sorted.length ||
        newIndex < 0 ||
        newIndex >= sorted.length) {
      return;
    }
    final item = sorted.removeAt(oldIndex);
    sorted.insert(newIndex, item);
    for (var i = 0; i < sorted.length; i++) {
      sorted[i] = sorted[i].copyWith(orderIndex: i);
    }
    _dailyChecklistItems
      ..clear()
      ..addAll(sorted);
    notifyListeners();
    await _saveData();
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

  // ─── Fixed Expense Templates ─────────────────────────────────────────────────

  /// Auto-generates expense entries from fixed templates on the 1st of each month.
  void _applyFixedExpensesIfNeeded() {
    if (_fixedTemplates.isEmpty) return;
    final now = DateTime.now();
    final currentMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    if (_lastFixedAppliedMonth == currentMonth) return;

    final firstOfMonth = DateTime(now.year, now.month, 1, 0, 1);
    for (final t in _fixedTemplates) {
      // Avoid adding duplicates if somehow called twice in the same month
      final alreadyExists = _expenses.any(
        (e) =>
            e.isFixed &&
            e.title == t.title &&
            e.timestamp.year == now.year &&
            e.timestamp.month == now.month,
      );
      if (!alreadyExists) {
        _expenses.insert(
          0,
          ExpenseModel(
            title: t.title,
            amount: t.amount,
            timestamp: firstOfMonth,
            category: t.category,
            note: t.note,
            isFixed: true,
          ),
        );
      }
    }

    // Also auto-add active SIPs as fixed expenses
    for (final sip in _sips) {
      if (sip.status != SipStatus.active) continue;
      final sipTitle = 'SIP: ${sip.schemeName}';
      final alreadyExists = _expenses.any(
        (e) =>
            e.isFixed &&
            e.title == sipTitle &&
            e.timestamp.year == now.year &&
            e.timestamp.month == now.month,
      );
      if (!alreadyExists) {
        _expenses.insert(
          0,
          ExpenseModel(
            title: sipTitle,
            amount: sip.monthlyAmount,
            timestamp: firstOfMonth,
            category: 'Other',
            note: 'Auto-added from SIP investment',
            isFixed: true,
          ),
        );
      }
    }

    _lastFixedAppliedMonth = currentMonth;
    // Save asynchronously — fire-and-forget
    _saveData();
    notifyListeners();
  }

  Future<void> addFixedTemplate(FixedExpenseTemplate template) async {
    _fixedTemplates.add(template);
    notifyListeners();
    await _saveData();
    // Immediately apply for the current month if not yet applied
    _applyFixedExpensesIfNeeded();
  }

  Future<void> updateFixedTemplate(FixedExpenseTemplate updated) async {
    final idx = _fixedTemplates.indexWhere((t) => t.id == updated.id);
    if (idx != -1) _fixedTemplates[idx] = updated;
    notifyListeners();
    await _saveData();
  }

  Future<void> removeFixedTemplate(String id) async {
    _fixedTemplates.removeWhere((t) => t.id == id);
    notifyListeners();
    await _saveData();
  }

  // ─── SIP Investments ────────────────────────────────────────────────────────

  Future<void> addSip(SipModel sip) async {
    _sips.add(sip);
    notifyListeners();
    await _saveData();
  }

  Future<void> updateSip(SipModel updated) async {
    final idx = _sips.indexWhere((s) => s.id == updated.id);
    if (idx != -1) {
      _sips[idx] = updated;
    } else {
      _sips.add(updated);
    }
    notifyListeners();
    await _saveData();
  }

  Future<void> removeSip(String id) async {
    _sips.removeWhere((s) => s.id == id);
    notifyListeners();
    await _saveData();
  }

  // ─── Stocks ────────────────────────────────────────────────────────────────

  Future<void> addStock(StockModel stock) async {
    _stocks.add(stock);
    notifyListeners();
    await _saveData();
  }

  Future<void> updateStock(StockModel stock) async {
    final idx = _stocks.indexWhere((s) => s.id == stock.id);
    if (idx != -1) {
      _stocks[idx] = stock;
    } else {
      _stocks.add(stock);
    }
    notifyListeners();
    await _saveData();
  }

  Future<void> removeStock(String id) async {
    _stocks.removeWhere((s) => s.id == id);
    notifyListeners();
    await _saveData();
  }

  // ─── Journals ────────────────────────────────────────────────────────────────

  JournalEntryModel? getJournalForDate(DateTime date) {
    for (final entry in _journalEntries) {
      if (entry.date.year == date.year &&
          entry.date.month == date.month &&
          entry.date.day == date.day) {
        return entry;
      }
    }
    return null;
  }

  Future<void> upsertJournal({
    required DateTime date,
    required String content,
  }) async {
    final normalized = DateTime(date.year, date.month, date.day);
    final idx = _journalEntries.indexWhere(
      (j) =>
          j.date.year == normalized.year &&
          j.date.month == normalized.month &&
          j.date.day == normalized.day,
    );
    final now = DateTime.now();
    if (idx == -1) {
      _journalEntries.add(
        JournalEntryModel(
          id: '${normalized.millisecondsSinceEpoch}_jrnl',
          date: normalized,
          content: content,
          updatedAt: now,
        ),
      );
    } else {
      _journalEntries[idx] = _journalEntries[idx].copyWith(
        content: content,
        updatedAt: now,
      );
    }
    _journalEntries.sort((a, b) => b.date.compareTo(a.date));
    notifyListeners();
    await _saveData();
  }

  Future<void> deleteJournalById(String id) async {
    _journalEntries.removeWhere((j) => j.id == id);
    notifyListeners();
    await _saveData();
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
      final raw = (response is TextResponse ? response.token : '')
          .trim()
          .replaceAll('.', '');
      const allowed = ['Food', 'Travelling', 'Clothes', 'Gadgets', 'Medical'];
      final matched = allowed.firstWhere(
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
        'userName': _userName,
        'tasks': _tasks.map((e) => e.toJson()).toList(),
        'logs': _logs.map((e) => e.toJson()).toList(),
        'todo_folders': _todoFolders.map((e) => e.toJson()).toList(),
        'expenses': _expenses.map((e) => e.toJson()).toList(),
        'journals': _journalEntries.map((e) => e.toJson()).toList(),
        'fixed_templates': _fixedTemplates.map((e) => e.toJson()).toList(),
        'sips': _sips.map((e) => e.toJson()).toList(),
        'stocks': _stocks.map((e) => e.toJson()).toList(),
        'last_fixed_applied_month': _lastFixedAppliedMonth,
        'daily_checklist_items': _dailyChecklistItems
            .map((e) => e.toJson())
            .toList(),
        'daily_checklist_checks': _dailyChecklistChecksByDate.map(
          (k, v) => MapEntry(k, v),
        ),
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

        if (data['userName'] != null &&
            (data['userName'] as String).trim().isNotEmpty) {
          final importedName = (data['userName'] as String).trim();
          if (_userName.isEmpty || _userName != importedName) {
            _userName = importedName;
            changed = true;
          }
        }

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
        if (data['journals'] != null) {
          final importedJournals = (data['journals'] as List).map(
            (e) => JournalEntryModel.fromJson(e),
          );
          for (final j in importedJournals) {
            final byId = _journalEntries.indexWhere(
              (existing) => existing.id == j.id,
            );
            if (byId != -1) {
              // Keep the newer edit if same entry id exists.
              if (j.updatedAt.isAfter(_journalEntries[byId].updatedAt)) {
                _journalEntries[byId] = j;
                changed = true;
              }
              continue;
            }

            final byDate = _journalEntries.indexWhere(
              (existing) =>
                  existing.date.year == j.date.year &&
                  existing.date.month == j.date.month &&
                  existing.date.day == j.date.day,
            );
            if (byDate != -1) {
              // Date-wise journals should be unique per day.
              // If importing the same day from another device, keep latest.
              if (j.updatedAt.isAfter(_journalEntries[byDate].updatedAt)) {
                _journalEntries[byDate] = j;
                changed = true;
              }
            } else {
              _journalEntries.add(j);
              changed = true;
            }
          }
        }

        if (data['fixed_templates'] != null) {
          final importedTemplates = (data['fixed_templates'] as List).map(
            (e) => FixedExpenseTemplate.fromJson(e),
          );
          for (final t in importedTemplates) {
            if (!_fixedTemplates.any((existing) => existing.id == t.id)) {
              _fixedTemplates.add(t);
              changed = true;
            }
          }
        }

        if (data['sips'] != null) {
          final importedSips = (data['sips'] as List).map(
            (e) => SipModel.fromJson(e),
          );
          for (final s in importedSips) {
            if (!_sips.any((existing) => existing.id == s.id)) {
              _sips.add(s);
              changed = true;
            }
          }
        }

        if (data['stocks'] != null) {
          final importedStocks = (data['stocks'] as List).map(
            (e) => StockModel.fromJson(e),
          );
          for (final stk in importedStocks) {
            if (!_stocks.any((existing) => existing.id == stk.id)) {
              _stocks.add(stk);
              changed = true;
            }
          }
        }

        if (data['daily_checklist_items'] != null) {
          final importedDaily = (data['daily_checklist_items'] as List)
              .map(
                (e) => DailyChecklistItemModel.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
          for (final item in importedDaily) {
            if (!_dailyChecklistItems.any((x) => x.id == item.id)) {
              _dailyChecklistItems.add(item);
              changed = true;
            }
          }
          _dailyChecklistItems.sort(
            (a, b) => a.orderIndex.compareTo(b.orderIndex),
          );
        }
        if (data['daily_checklist_checks'] != null) {
          final raw = data['daily_checklist_checks'] as Map<String, dynamic>;
          for (final e in raw.entries) {
            final ids = (e.value as List).map((x) => x.toString()).toList();
            final merged = <String>{
              ...?_dailyChecklistChecksByDate[e.key],
              ...ids,
            };
            if (merged.isNotEmpty) {
              _dailyChecklistChecksByDate[e.key] = merged.toList();
              changed = true;
            }
          }
        }

        if (data['last_fixed_applied_month'] != null) {
          final importedMonth = data['last_fixed_applied_month'] as String;
          // Only update if the imported month is "newer" or equal to ours
          // to prevent re-triggering fixed templates right after an import.
          if (importedMonth.compareTo(_lastFixedAppliedMonth) > 0) {
            _lastFixedAppliedMonth = importedMonth;
            changed = true;
          }
        }

        if (changed) {
          _tasks.sort((a, b) => a.startTime.compareTo(b.startTime));
          _logs.sort((a, b) => a.timestamp.compareTo(b.timestamp));
          _expenses.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          _journalEntries.sort((a, b) => b.date.compareTo(a.date));
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
