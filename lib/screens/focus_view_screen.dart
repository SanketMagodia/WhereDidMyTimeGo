import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/task_model.dart';
import '../models/log_entry_model.dart';
import '../models/expense_model.dart';
import '../theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

// ───────────────────────────────────────────────────────────────────────────
// The app has TWO distinct data sources:
//
//  1. TASKS   – what the user PRE-SCHEDULED (startTime / endTime blocks).
//               Shown on the Tasks tab as calendar blocks.
//
//  2. TIME LOGS – what the user ACTUALLY DID, captured every 15/20/30 min
//               via the notification prompt. Each entry has a timestamp + text.
//
// The Home page surfaces both clearly: planned vs actual.
// ───────────────────────────────────────────────────────────────────────────

class FocusViewScreen extends StatelessWidget {
  const FocusViewScreen({super.key});

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static _Metrics _compute(
    List<TaskModel> tasks,
    List<LogEntry> logs,
    DateTime now,
  ) {
    final today = DateTime(now.year, now.month, now.day);
    final todayTasks = tasks.where((t) => _sameDay(t.startTime, today)).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    final todayLogs =
        logs.where((l) => _sameDay(l.timestamp, today) && !l.isSleep).toList()
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Current / past / next task
    TaskModel? prev, current, next;
    for (final t in todayTasks) {
      if (t.endTime.isBefore(now)) {
        prev = t;
      } else if (!t.startTime.isAfter(now)) {
        current = t;
      } else {
        next ??= t;
      }
    }

    final lastLog = todayLogs.isNotEmpty ? todayLogs.last : null;
    final dayStart = DateTime(now.year, now.month, now.day, 6);
    final dayEnd = DateTime(now.year, now.month, now.day + 1);
    final elapsedMin = now.isBefore(dayStart)
        ? 0
        : now.isAfter(dayEnd)
        ? dayEnd.difference(dayStart).inMinutes
        : now.difference(dayStart).inMinutes;

    final trackedMin = todayTasks.fold<int>(
      0,
      (s, t) => s + t.endTime.difference(t.startTime).inMinutes,
    );
    final plannedElapsedMin = todayTasks.fold<int>(0, (sum, t) {
      final start = t.startTime.isAfter(dayStart) ? t.startTime : dayStart;
      final end = t.endTime.isBefore(now) ? t.endTime : now;
      if (!end.isAfter(start)) return sum;
      return sum + end.difference(start).inMinutes;
    });

    final inferredIntervalMinutes = _inferSlotIntervalMinutes(todayLogs);
    final slotTexts = <String>[];
    final loggedSlots = <DateTime>{};
    for (final l in todayLogs) {
      final parts = _splitLogParts(l.text, inferredIntervalMinutes);
      for (var i = 0; i < parts.length; i++) {
        final slotText = parts[i].trim();
        if (slotText.isEmpty) continue;
        final slotTime = l.timestamp.add(
          Duration(minutes: inferredIntervalMinutes * i),
        );
        if (slotTime.isBefore(dayStart) || slotTime.isAfter(now)) continue;
        loggedSlots.add(slotTime);
        slotTexts.add(slotText);
      }
    }
    final loggedMin = loggedSlots.length * inferredIntervalMinutes;
    final tasksDone = todayTasks.where((t) => t.endTime.isBefore(now)).length;

    // Top activity from logs
    final freq = <String, int>{};
    for (final txt in slotTexts) {
      freq[txt] = (freq[txt] ?? 0) + 1;
    }
    String? topActivity;
    if (freq.isNotEmpty) {
      topActivity = freq.entries
          .reduce((a, b) => a.value >= b.value ? a : b)
          .key;
    }

    // Category distribution
    final catCounts = <String, int>{};
    for (final l in todayLogs) {
      final c = l.category ?? 'miscellaneous';
      catCounts[c] = (catCounts[c] ?? 0) + 1;
    }

    return _Metrics(
      prev: prev,
      current: current,
      next: next,
      lastLog: lastLog,
      todayTasks: todayTasks,
      todayLogs: todayLogs,
      trackedMin: trackedMin,
      plannedElapsedMin: plannedElapsedMin,
      loggedMin: loggedMin,
      elapsedMin: elapsedMin,
      inferredIntervalMinutes: inferredIntervalMinutes,
      tasksTotal: todayTasks.length,
      tasksDone: tasksDone,
      topActivity: topActivity,
      categoryCounts: catCounts,
    );
  }

  static int _inferSlotIntervalMinutes(List<LogEntry> todayLogs) {
    var maxParts = 1;
    for (final l in todayLogs) {
      final parts = l.text.split('•');
      if (parts.length > maxParts) {
        maxParts = parts.length;
      }
    }
    final inferred = 60 ~/ maxParts;
    if (inferred <= 0) return 30;
    return inferred;
  }

  static List<String> _splitLogParts(String text, int intervalMinutes) {
    final rawParts = text.split('•').map((e) => e.trim()).toList();
    if (rawParts.length <= 1) return [text.trim()];
    final expected = (60 ~/ intervalMinutes).clamp(1, 12);
    if (rawParts.length < expected) {
      return [...rawParts, ...List.filled(expected - rawParts.length, '')];
    }
    return rawParts;
  }

  Future<void> _addTask(BuildContext context, DateTime now) async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final c = AppColors.of(context);
    final textController = TextEditingController();

    final input = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        title: Text(
          'AI quick schedule',
          style: TextStyle(color: c.text, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: textController,
          autofocus: true,
          style: TextStyle(color: c.text),
          decoration: InputDecoration(
            hintText: 'Jogging at 6:30am',
            hintStyle: TextStyle(color: c.muted),
            filled: true,
            fillColor: c.surfaceMid,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => Navigator.of(ctx).pop(textController.text.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: TextStyle(color: c.muted)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: c.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(textController.text.trim()),
            icon: const Icon(Icons.auto_awesome_rounded, size: 16),
            label: const Text('Schedule'),
          ),
        ],
      ),
    );

    if (input == null || input.isEmpty) return;

    if (!provider.isAiReady) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Import an AI model in Settings to use AI scheduling.'),
        ),
      );
      return;
    }

    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    _AiTaskDraft? parsed;
    try {
      parsed = await _parseTaskFromPrompt(input, now);
    } finally {
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    }

    if (parsed == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not understand that schedule. Try a clearer prompt.',
          ),
        ),
      );
      return;
    }

    final task = TaskModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: parsed.title,
      startTime: parsed.start,
      endTime: parsed.end,
    );
    await provider.addTask(task);

    if (!context.mounted) return;
    final fmt = DateFormat('EEE, d MMM • HH:mm');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Scheduled "${parsed.title}" for ${fmt.format(parsed.start)} (${parsed.durationMinutes} min).',
        ),
      ),
    );
  }

  Future<_AiTaskDraft?> _parseTaskFromPrompt(
    String userPrompt,
    DateTime now,
  ) async {
    final prompt =
        "Convert the user scheduling request into JSON.\n"
        "Current local datetime: ${now.toIso8601String()}.\n"
        "Focus primarily on explicit date/time keywords in the user's request.\n"
        "Do not infer a different day when no day keyword is mentioned.\n"
        "Rules:\n"
        "1) If duration is not specified, default to 30 minutes.\n"
        "2) Resolve relative dates like today/tomorrow using current local datetime.\n"
        "3) If user does NOT mention any day/date keyword, use today's date.\n"
        "3) Prefer 24-hour time. convert 12-hour time to 24-hour time.\n"
        "4) Keep title concise and human-friendly.\n"
        "Return ONLY minified JSON with exactly these keys:\n"
        "{\"title\":\"...\",\"date\":\"YYYY-MM-DD\",\"time\":\"HH:mm\",\"duration_minutes\":30}\n"
        "User request: $userPrompt";

    final activeModel = await FlutterGemma.getActiveModel(maxTokens: 512);
    final chat = await activeModel.createChat();
    await chat.addQuery(Message(text: prompt, isUser: true));
    final response = await chat.generateChatResponse();
    final responseText = response is TextResponse ? response.token.trim() : '';
    if (responseText.isEmpty) {
      return _fallbackParseTaskFromPrompt(userPrompt, now);
    }

    var jsonText = responseText
        .replaceAll('```json', '')
        .replaceAll('```', '')
        .trim();
    if (!jsonText.startsWith('{')) {
      final match = RegExp(r'\{[\s\S]*\}').firstMatch(jsonText);
      jsonText = match?.group(0)?.trim() ?? jsonText;
    }

    Map<String, dynamic> data;
    try {
      data = jsonDecode(jsonText) as Map<String, dynamic>;
    } catch (_) {
      return _fallbackParseTaskFromPrompt(userPrompt, now);
    }
    final titleRaw = (data['title'] ?? '').toString().trim();
    final dateRaw = (data['date'] ?? '').toString().trim();
    final timeRaw = (data['time'] ?? '').toString().trim();
    final durationRaw = data['duration_minutes'];
    if (titleRaw.isEmpty || dateRaw.isEmpty || timeRaw.isEmpty) {
      return _fallbackParseTaskFromPrompt(userPrompt, now);
    }

    final day = DateTime.tryParse(dateRaw);
    if (day == null) return _fallbackParseTaskFromPrompt(userPrompt, now);

    final timeMatch = RegExp(
      r'^(\d{1,2})(?::(\d{2}))?\s*(am|pm)?$',
      caseSensitive: false,
    ).firstMatch(timeRaw);
    if (timeMatch == null) return _fallbackParseTaskFromPrompt(userPrompt, now);

    var hour = int.tryParse(timeMatch.group(1) ?? '');
    final minute = int.tryParse(timeMatch.group(2) ?? '0');
    final ampm = (timeMatch.group(3) ?? '').toLowerCase();
    if (hour == null || minute == null || minute < 0 || minute > 59)
      return _fallbackParseTaskFromPrompt(userPrompt, now);

    if (ampm == 'pm' && hour < 12) hour += 12;
    if (ampm == 'am' && hour == 12) hour = 0;
    if (hour < 0 || hour > 23) return _fallbackParseTaskFromPrompt(userPrompt, now);

    final resolvedDay = _resolveRelativeDay(now, userPrompt, day);
    final resolvedTime = _resolveTimeFromPrompt(userPrompt, hour, minute);

    final duration = (durationRaw is num ? durationRaw.toInt() : 30).clamp(
      15,
      480,
    );
    final start = DateTime(
      resolvedDay.year,
      resolvedDay.month,
      resolvedDay.day,
      resolvedTime.$1,
      resolvedTime.$2,
    );
    final end = start.add(Duration(minutes: duration));

    return _AiTaskDraft(
      title: titleRaw,
      start: start,
      end: end,
      durationMinutes: duration,
    );
  }

  _AiTaskDraft _fallbackParseTaskFromPrompt(String userPrompt, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final day = _resolveRelativeDay(now, userPrompt, today);
    final defaultTime = _resolveTimeFromPrompt(userPrompt, now.hour, now.minute);
    final duration = _parseDurationFromPrompt(userPrompt);

    final start = DateTime(day.year, day.month, day.day, defaultTime.$1, defaultTime.$2);
    return _AiTaskDraft(
      title: _deriveTitleFromPrompt(userPrompt),
      start: start,
      end: start.add(Duration(minutes: duration)),
      durationMinutes: duration,
    );
  }

  DateTime _resolveRelativeDay(DateTime now, String prompt, DateTime modelDay) {
    final p = prompt.toLowerCase();
    final today = DateTime(now.year, now.month, now.day);
    if (p.contains('day after tomorrow')) {
      return today.add(const Duration(days: 2));
    }
    if (RegExp(r'\btomorrow\b').hasMatch(p)) {
      return today.add(const Duration(days: 1));
    }
    if (RegExp(r'\btoday\b').hasMatch(p)) return today;
    if (RegExp(r'\btonight\b').hasMatch(p)) return today;
    if (!_containsDayHint(p)) return today;
    return modelDay;
  }

  bool _containsDayHint(String promptLower) {
    if (RegExp(
      r'\b(today|tomorrow|tonight|day after tomorrow|next|monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b',
    ).hasMatch(promptLower)) {
      return true;
    }
    if (RegExp(
      r'\b(jan|january|feb|february|mar|march|apr|april|may|jun|june|jul|july|aug|august|sep|sept|september|oct|october|nov|november|dec|december)\b',
    ).hasMatch(promptLower)) {
      return true;
    }
    // Numeric dates like 12/05, 2026-03-10, 10-03-2026
    if (RegExp(r'\b\d{1,4}[/-]\d{1,2}([/-]\d{1,4})?\b').hasMatch(promptLower)) {
      return true;
    }
    return false;
  }

  (int, int) _resolveTimeFromPrompt(
    String prompt,
    int modelHour,
    int modelMinute,
  ) {
    final p = prompt.toLowerCase();
    final explicit = RegExp(
      r'\b(?:at\s*)?(\d{1,2})(?::(\d{2}))?\s*(am|pm)?\b',
      caseSensitive: false,
    ).firstMatch(p);
    if (explicit != null) {
      var h = int.tryParse(explicit.group(1) ?? '') ?? modelHour;
      var m = int.tryParse(explicit.group(2) ?? '0') ?? 0;
      final ampm = (explicit.group(3) ?? '').toLowerCase();

      if (ampm == 'pm' && h < 12) h += 12;
      if (ampm == 'am' && h == 12) h = 0;

      if (ampm.isEmpty) {
        if ((p.contains('morning') || p.contains('am')) && h == 12) h = 0;
        if (p.contains('afternoon') && h < 12) h += 12;
        if ((p.contains('evening') || p.contains('night')) && h < 12) h += 12;
      }

      if (h >= 0 && h <= 23 && m >= 0 && m <= 59) return (h, m);
    }

    if (p.contains('morning')) return (9, 0);
    if (p.contains('afternoon')) return (14, 0);
    if (p.contains('evening')) return (18, 0);
    if (p.contains('night') || p.contains('tonight')) return (21, 0);
    return (modelHour, modelMinute);
  }

  int _parseDurationFromPrompt(String prompt) {
    final p = prompt.toLowerCase();
    final m = RegExp(r'(\d{1,3})\s*(min|mins|minute|minutes|hr|hrs|hour|hours)\b')
        .firstMatch(p);
    if (m == null) return 30;
    final raw = int.tryParse(m.group(1) ?? '') ?? 30;
    final unit = m.group(2) ?? 'min';
    final minutes = unit.startsWith('h') ? raw * 60 : raw;
    return minutes.clamp(15, 480);
  }

  String _deriveTitleFromPrompt(String prompt) {
    final clean = prompt
        .replaceAll(RegExp(r'\b(today|tomorrow|tonight|morning|afternoon|evening|night)\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\bat\b\s*\d{1,2}(:\d{2})?\s*(am|pm)?\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\b\d{1,3}\s*(min|mins|minute|minutes|hr|hrs|hour|hours)\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (clean.isEmpty) return 'Planned task';
    return clean[0].toUpperCase() + clean.substring(1);
  }

  void _logNow(BuildContext context) {
    final textController = TextEditingController();
    final provider = Provider.of<AppProvider>(context, listen: false);
    final c = AppColors.of(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        title: Text(
          'Log current activity',
          style: TextStyle(color: c.text, fontSize: 16),
        ),
        content: TextField(
          controller: textController,
          autofocus: true,
          style: TextStyle(color: c.text),
          decoration: InputDecoration(
            hintText: 'What are you doing now?',
            hintStyle: TextStyle(color: c.muted),
            filled: true,
            fillColor: c.surfaceMid,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: TextStyle(color: c.muted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: c.gold,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final text = textController.text.trim();
              if (text.isNotEmpty) {
                provider.logNowForCurrentBlock(text);
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final now = DateTime.now();
    final m = _compute(provider.tasks, provider.logs, now);
    final expenses = provider.expenses;

    return Scaffold(
      floatingActionButton: _QuickActionsFab(
        onLogNow: () => _logNow(context),
        onSchedule: () => _addTask(context, now),
      ),
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _Header(provider: provider, now: now, m: m),
            ),
            SliverToBoxAdapter(
              child: _NowCard(metrics: m, now: now),
            ),
            SliverToBoxAdapter(child: _StatStrip(m: m)),
            SliverToBoxAdapter(
              child: _DonutCard(m: m, now: now),
            ),
            SliverToBoxAdapter(
              child: _ExpenseInsightCard(expenses: expenses, now: now),
            ),
            SliverToBoxAdapter(
              child: _AnimatedFeed(m: m, now: now),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: MediaQuery.of(context).padding.bottom + 24,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionsFab extends StatefulWidget {
  final VoidCallback onLogNow;
  final VoidCallback onSchedule;

  const _QuickActionsFab({required this.onLogNow, required this.onSchedule});

  @override
  State<_QuickActionsFab> createState() => _QuickActionsFabState();
}

class _QuickActionsFabState extends State<_QuickActionsFab> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final logColor = AppTheme.accentGold;
    final scheduleColor = AppTheme.accentPrimary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: ScaleTransition(scale: anim, child: child),
          ),
          child: !_open
              ? const SizedBox.shrink()
              : Column(
                  key: const ValueKey('fab_actions'),
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Transform.scale(
                      scale: 0.9,
                      child: FloatingActionButton.extended(
                        heroTag: 'log_now_fab',
                        onPressed: () {
                          setState(() => _open = false);
                          widget.onLogNow();
                        },
                        tooltip: 'Log now',
                        backgroundColor: logColor,
                        foregroundColor: Colors.white,
                        extendedPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                        ),
                        icon: const Icon(Icons.edit_note_rounded, size: 16),
                        label: const Text(
                          'Log Now',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Transform.scale(
                      scale: 0.9,
                      child: FloatingActionButton.extended(
                        heroTag: 'ai_schedule_fab',
                        onPressed: () {
                          setState(() => _open = false);
                          widget.onSchedule();
                        },
                        tooltip: 'AI schedule',
                        backgroundColor: scheduleColor,
                        foregroundColor: Colors.white,
                        extendedPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                        ),
                        icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                        label: const Text(
                          'Schedule',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
        ),
        FloatingActionButton(
          heroTag: 'quick_actions_main_fab',
          onPressed: () => setState(() => _open = !_open),
          tooltip: _open ? 'Close actions' : 'Quick actions',
          backgroundColor: colors.primary,
          foregroundColor: Colors.white,
          elevation: 5,
          highlightElevation: 8,
          child: Icon(_open ? Icons.close_rounded : Icons.add_rounded),
        ),
      ],
    );
  }
}

// ── Data ─────────────────────────────────────────────────────────────────────
class _Metrics {
  final TaskModel? prev, current, next;
  final LogEntry? lastLog;
  final List<TaskModel> todayTasks;
  final List<LogEntry> todayLogs;
  final int trackedMin, plannedElapsedMin, loggedMin, elapsedMin;
  final int inferredIntervalMinutes;
  final int tasksTotal, tasksDone;
  final String? topActivity;

  const _Metrics({
    this.prev,
    this.current,
    this.next,
    this.lastLog,
    required this.todayTasks,
    required this.todayLogs,
    required this.trackedMin,
    required this.plannedElapsedMin,
    required this.loggedMin,
    required this.elapsedMin,
    required this.inferredIntervalMinutes,
    required this.tasksTotal,
    required this.tasksDone,
    this.topActivity,
    required this.categoryCounts,
  });

  final Map<String, int> categoryCounts;

  double get dayFraction => (elapsedMin / (18 * 60)).clamp(0.0, 1.0);
  double get planCoverage =>
      elapsedMin == 0 ? 0 : (plannedElapsedMin / elapsedMin).clamp(0.0, 1.0);
  double get logCoverage =>
      elapsedMin == 0 ? 0 : (loggedMin / elapsedMin).clamp(0.0, 1.0);
  double get taskDoneRatio => tasksTotal == 0 ? 0 : tasksDone / tasksTotal;
}

class _AiTaskDraft {
  final String title;
  final DateTime start;
  final DateTime end;
  final int durationMinutes;

  const _AiTaskDraft({
    required this.title,
    required this.start,
    required this.end,
    required this.durationMinutes,
  });
}

// ── Header ────────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final AppProvider provider;
  final DateTime now;
  final _Metrics m;
  const _Header({required this.provider, required this.now, required this.m});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final greeting = now.hour < 12
        ? 'Good morning'
        : now.hour < 17
        ? 'Good afternoon'
        : 'Good evening';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: TextStyle(
                    color: c.muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'WDMTG',
                        style: TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.w900,
                          color: c.text,
                          letterSpacing: 1.2,
                        ),
                      ),
                      TextSpan(
                        text: '?',
                        style: TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.w900,
                          color: c.primary,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  DateFormat('EEE, d MMM').format(now),
                  style: TextStyle(color: c.muted, fontSize: 11),
                ),
                if (provider.isAiReady) ...[
                  const SizedBox(height: 6),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () => _showAiInsights(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: c.gold.withAlpha(22),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: c.gold.withAlpha(70)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.auto_awesome_rounded,
                              color: c.gold,
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "Today's Brief",
                              style: TextStyle(
                                color: c.gold,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Column(
            children: [
              Text(
                provider.isAwake ? '😌' : '😴',
                style: const TextStyle(fontSize: 22),
              ),
              Transform.scale(
                scale: 0.78,
                child: Switch(
                  value: provider.isAwake,
                  activeThumbColor: AppTheme.accentPrimary,
                  onChanged: provider.toggleAwakeStatus,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              Text(
                provider.isAwake ? 'Awake' : 'Asleep',
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 9),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAiInsights(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _AiInsightBottomSheet(provider: provider, m: m),
    );
  }
}

// ── Now card: what's happening right now ─────────────────────────────────────
class _NowCard extends StatelessWidget {
  final _Metrics metrics;
  final DateTime now;
  const _NowCard({required this.metrics, required this.now});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('HH:mm');
    final m = metrics;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('NOW'),
          const SizedBox(height: 6),
          // Scheduled task piece
          _NowBrick(
            accent: AppTheme.accentPrimary,
            topLabel: 'SCHEDULED TASK',
            mainText:
                m.current?.title ?? m.next?.title ?? 'Nothing in Schedule',
            subText: m.current != null
                ? 'Ongoing until ${fmt.format(m.current!.endTime)}'
                : m.next != null
                ? 'Starts at ${fmt.format(m.next!.startTime)}'
                : 'No upcoming tasks',
            isEmpty: m.current == null && m.next == null,
            icon: Icons.calendar_today_rounded,
            isActive: m.current != null,
          ),
          const SizedBox(height: 8),
          // Last time log
          _NowBrick(
            accent: AppTheme.accentGold,
            topLabel: 'LAST TIME LOG',
            mainText: m.lastLog != null
                ? (m.lastLog!.isSleep ? '😴 Sleeping' : m.lastLog!.text)
                : 'No logs yet today',
            subText: m.lastLog != null
                ? _agoText(now.difference(m.lastLog!.timestamp))
                : 'You\'ll be prompted soon',
            isEmpty: m.lastLog == null,
            icon: Icons.edit_note_rounded,
            isSolidStyle: true,
          ),
        ],
      ),
    );
  }

  String _agoText(Duration d) {
    if (d.inMinutes < 1) return 'Just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    return '${d.inHours}h ${d.inMinutes % 60}m ago';
  }
}

class _NowBrick extends StatelessWidget {
  final Color accent;
  final String topLabel, mainText, subText;
  final bool isEmpty;
  final bool isActive;
  final bool isSolidStyle;
  final IconData icon;

  const _NowBrick({
    required this.accent,
    required this.topLabel,
    required this.mainText,
    required this.subText,
    required this.isEmpty,
    required this.icon,
    this.isActive = false,
    this.isSolidStyle = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final bool isLight = Theme.of(context).brightness == Brightness.light;

    // Actives ALWAYS get accent. SolidStyle gets accent if not empty.
    final bool useAccent = isActive || (isSolidStyle && !isEmpty);

    final bgColor = useAccent ? accent : c.surface;
    final onBg = useAccent ? (isLight ? Colors.black87 : Colors.white) : c.text;
    final onBgMuted = useAccent
        ? (isLight ? Colors.black54 : Colors.white70)
        : c.muted;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: useAccent ? null : Border.all(color: c.sep),
        boxShadow: useAccent
            ? [
                BoxShadow(
                  color: accent.withAlpha(isActive ? 150 : 80),
                  blurRadius: isActive ? 16 : 10,
                  offset: Offset(0, isActive ? 6 : 4),
                ),
              ]
            : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isEmpty ? c.surfaceMid : Colors.white.withAlpha(50),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: isEmpty
                  ? accent
                  : (isLight ? Colors.black87 : Colors.white),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  topLabel,
                  style: TextStyle(
                    color: isEmpty
                        ? c.muted
                        : (isLight
                              ? Colors.black54
                              : Colors.white.withAlpha(200)),
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  mainText,
                  style: TextStyle(
                    color: onBg,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subText,
                  style: TextStyle(color: onBgMuted, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stat strip ────────────────────────────────────────────────────────────────
class _StatStrip extends StatelessWidget {
  final _Metrics m;
  const _StatStrip({required this.m});

  String _fmtMinutes(int totalMinutes) {
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: _Chip(
              icon: Icons.calendar_today_rounded,
              label: 'Planned',
              value: _fmtMinutes(m.trackedMin),
              sub: '${m.tasksTotal} task${m.tasksTotal == 1 ? "" : "s"}',
              color: AppTheme.accentPrimary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _Chip(
              icon: Icons.check_circle_outline_rounded,
              label: 'Completed',
              value: '${m.tasksDone}/${m.tasksTotal}',
              sub: m.tasksTotal == 0
                  ? '—'
                  : '${(m.taskDoneRatio * 100).round()}% done',
              color: AppTheme.accentGold,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _Chip(
              icon: Icons.insights_rounded,
              label: 'Captured',
              value: _fmtMinutes(m.loggedMin),
              sub: '${(m.logCoverage * 100).round()}% of elapsed',
              color: AppTheme.accentSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label, value, sub;
  final Color color;
  const _Chip({
    required this.icon,
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.sep),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: TextStyle(color: c.text, fontSize: 9.5),
            textAlign: TextAlign.center,
          ),
          Text(
            sub,
            style: TextStyle(color: c.muted, fontSize: 8.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Donut: Planned vs Actual ──────────────────────────────────────────────────
class _DonutCard extends StatelessWidget {
  final _Metrics m;
  final DateTime now;
  const _DonutCard({required this.m, required this.now});

  String _fmtMinutes(int totalMinutes) {
    final h = totalMinutes ~/ 60;
    final mm = totalMinutes % 60;
    if (h > 0) return '${h}h ${mm}m';
    return '${mm}m';
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final remMin = ((1 - m.dayFraction) * 18 * 60).round();
    final scheduledSoFar = m.plannedElapsedMin;
    final loggedSoFar = m.loggedMin;
    final gapMin = math.max(0, m.elapsedMin - loggedSoFar);
    final remainingPlannedMin = math.max(0, m.trackedMin - scheduledSoFar);
    final paceNeeded = remMin == 0
        ? 0.0
        : (remainingPlannedMin / remMin).clamp(0.0, 2.0);
    final alignmentScore = scheduledSoFar == 0
        ? (loggedSoFar > 0 ? 1.0 : 0.0)
        : (loggedSoFar / scheduledSoFar).clamp(0.0, 2.0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: c.sep),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 78,
              height: 78,
              child: CustomPaint(
                painter: _DonutPainter(
                  dayFraction: m.dayFraction,
                  planFraction: m.planCoverage * m.dayFraction,
                  trackColor: c.surfaceMid,
                  bgColor: c.sep,
                ),
                child: Center(
                  child: Text(
                    '${(m.dayFraction * 100).round()}%',
                    style: TextStyle(
                      color: c.text,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Day at a Glance',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _MiniBadge(
                        label: 'Logged',
                        value: '${(m.logCoverage * 100).round()}%',
                        color: AppTheme.accentGold,
                      ),
                      _MiniBadge(
                        label: 'Planned',
                        value: '${(m.planCoverage * 100).round()}%',
                        color: AppTheme.accentPrimary,
                      ),
                      _MiniBadge(
                        label: 'Gap',
                        value: _fmtMinutes(gapMin),
                        color: gapMin <= m.inferredIntervalMinutes
                            ? Colors.greenAccent
                            : Colors.orangeAccent,
                      ),
                      _MiniBadge(
                        label: 'Focus pace',
                        value: '${(paceNeeded * 100).round()}%',
                        color: paceNeeded <= 1
                            ? Colors.greenAccent
                            : Colors.orangeAccent,
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  _Legend(
                    color: AppTheme.accentPrimary,
                    label: 'Alignment',
                    value: '${(alignmentScore * 100).round()}% match',
                  ),
                  const SizedBox(height: 4),
                  _Legend(
                    color: AppTheme.separator,
                    label: 'Remaining',
                    value: '~${remMin ~/ 60}h ${remMin % 60}m left',
                  ),
                  if (m.topActivity != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.trending_up_rounded,
                          color: AppTheme.accentSecondary,
                          size: 13,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Logged most: ${m.topActivity}',
                            style: const TextStyle(
                              color: AppTheme.accentSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniBadge({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: c.surfaceMid.withAlpha(120),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.sep),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label ',
            style: TextStyle(
              color: c.muted,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label, value;
  const _Legend({
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: colors.muted, fontSize: 10)),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: colors.text,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ── AI Category Breakdown ───────────────────────────────────────────────────
class _CategoryTags extends StatelessWidget {
  final _Metrics m;
  const _CategoryTags({required this.m});

  @override
  Widget build(BuildContext context) {
    if (m.todayLogs.isEmpty) return const SizedBox.shrink();

    final c = AppColors.of(context);
    final total = m.todayLogs.length;

    final sortedCats = m.categoryCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 12, color: c.gold),
              const SizedBox(width: 4),
              Text(
                'ACTIVITY BREAKDOWN',
                style: TextStyle(
                  color: c.gold,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.8,
            ),
            itemCount: sortedCats.length,
            itemBuilder: (context, i) {
              final cat = sortedCats[i].key;
              final count = sortedCats[i].value;
              final pct = (count / total).clamp(0.0, 1.0);

              Color color = c.muted;
              IconData icon = Icons.label_rounded;

              switch (cat) {
                case 'Exercise':
                  color = Colors.greenAccent;
                  icon = Icons.fitness_center_rounded;
                  break;
                case 'Study':
                  color = Colors.cyanAccent;
                  icon = Icons.menu_book_rounded;
                  break;
                case 'Social':
                  color = Colors.orangeAccent;
                  icon = Icons.celebration_rounded;
                  break;
                case 'Time Waste':
                  color = Colors.redAccent;
                  icon = Icons.videogame_asset_rounded;
                  break;
              }

              return Container(
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: c.sep),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            value: pct,
                            strokeWidth: 3,
                            backgroundColor: color.withAlpha(40),
                            color: color,
                          ),
                        ),
                        Icon(icon, size: 14, color: color),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cat,
                            style: TextStyle(
                              color: c.text,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${(pct * 100).round()}% of focus',
                            style: TextStyle(color: c.muted, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── AI Summary Card ─────────────────────────────────────────────────────────

class _AiSummaryCard extends StatefulWidget {
  final AppProvider provider;
  final _Metrics m;
  const _AiSummaryCard({required this.provider, required this.m});

  @override
  State<_AiSummaryCard> createState() => _AiSummaryCardState();
}

class _AiSummaryCardState extends State<_AiSummaryCard> {
  String? _summary;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.provider.isAiReady && widget.m.todayLogs.isNotEmpty) {
        _generateSummary();
      }
    });
  }

  Future<void> _generateSummary() async {
    if (!widget.provider.isAiReady) return;
    if (widget.m.todayLogs.isEmpty) {
      setState(() {
        _summary = "Add a few logs today and I'll generate your brief.";
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _summary = null;
    });

    try {
      final timelineBuf = StringBuffer();
      final fmt = DateFormat('HH:mm');
      for (final l in widget.m.todayLogs) {
        if (!l.isSleep && l.text.trim().isNotEmpty) {
          timelineBuf.writeln("${fmt.format(l.timestamp)}: ${l.text}");
        }
      }

      final prompt =
          "Here is my timeline for today:\n${timelineBuf.toString()}\nAs a helpful AI assistant, give me a very short 1 sentence summary of how my day went, cheer me up if I did well, and give me a short tip for tomorrow.";

      final activeModel = await FlutterGemma.getActiveModel(maxTokens: 1024);
      final chat = await activeModel.createChat();
      await chat.addQuery(Message(text: prompt, isUser: true));

      final response = await chat.generateChatResponse();
      final responseText = response is TextResponse ? response.token : "";
      final cleaned = responseText.trim();

      if (mounted) {
        setState(() {
          _summary = cleaned.isNotEmpty
              ? cleaned
              : "Couldn't generate a brief this time. Try again.";
        });
      }
    } catch (e) {
      debugPrint("Summary error: $e");
      if (mounted) {
        setState(() {
          _summary = "Failed to generate summary. Please check your model.";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.provider.isAiReady) return const SizedBox.shrink();

    final c = AppColors.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.gold.withAlpha(50)),
          boxShadow: [
            BoxShadow(
              color: c.gold.withAlpha(10),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: c.gold.withAlpha(30),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: c.gold,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Daily Reflection',
                  style: TextStyle(
                    color: c.text,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                if (!_isLoading && _summary == null)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: c.gold,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 0,
                      ),
                      minimumSize: const Size(0, 28),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _generateSummary,
                    child: const Text(
                      'Generate',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),

            if (_isLoading) ...[
              const SizedBox(height: 16),
              Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: c.gold,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'AI is thinking offline...',
                  style: TextStyle(color: c.muted, fontSize: 11),
                ),
              ),
            ],

            if (_summary != null && !_isLoading) ...[
              const SizedBox(height: 16),
              Text(
                _summary!,
                style: TextStyle(
                  color: c.text.withAlpha(220),
                  fontSize: 13,
                  height: 1.5,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: c.muted,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: _generateSummary,
                  icon: const Icon(Icons.refresh_rounded, size: 14),
                  label: const Text(
                    'Regenerate',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final double dayFraction, planFraction;
  final Color trackColor, bgColor;
  const _DonutPainter({
    required this.dayFraction,
    required this.planFraction,
    required this.trackColor,
    required this.bgColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final r = math.min(cx, cy) - 7;
    const sw = 9.0;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);
    const start = -math.pi / 2;

    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..color = bgColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw,
    );

    if (dayFraction > 0) {
      canvas.drawArc(
        rect,
        start,
        math.pi * 2 * dayFraction,
        false,
        Paint()
          ..color = trackColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = sw
          ..strokeCap = StrokeCap.round,
      );
    }
    if (planFraction > 0) {
      canvas.drawArc(
        rect,
        start,
        math.pi * 2 * planFraction,
        false,
        Paint()
          ..color = AppTheme.accentPrimary
          ..style = PaintingStyle.stroke
          ..strokeWidth = sw
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter o) =>
      o.dayFraction != dayFraction ||
      o.planFraction != planFraction ||
      o.trackColor != trackColor ||
      o.bgColor != bgColor;
}

// ── Unified Animated Feed ───────────────────────────────────────────────────
class _AnimatedFeed extends StatelessWidget {
  final _Metrics m;
  final DateTime now;
  const _AnimatedFeed({required this.m, required this.now});

  @override
  Widget build(BuildContext context) {
    // final c = AppColors.of(context); // Removed as per instruction
    final fmt = DateFormat('HH:mm');

    final tasks = m.todayTasks.reversed.toList();
    final logs = m.todayLogs.reversed.toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        color: Colors.transparent, // User requested transparent container
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('📅 SCHEDULED TASKS'),
                  const SizedBox(height: 12),
                  if (tasks.isEmpty)
                    _emptyCard(context, 'No tasks today.\nTap + to plan.')
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      itemCount: tasks.length,
                      itemBuilder: (context, index) {
                        final t = tasks[index];
                        final isOngoing =
                            t.startTime.isBefore(now) && t.endTime.isAfter(now);
                        return TweenAnimationBuilder<double>(
                          key: ValueKey('task_${t.id}'),
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: Duration(
                            milliseconds: 300 + (index * 100).clamp(0, 500),
                          ),
                          curve: Curves.easeOutCubic,
                          builder: (context, val, child) {
                            return Transform.translate(
                              offset: Offset(0, 20 * (1 - val)),
                              child: Opacity(opacity: val, child: child),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _FeedCard(
                              title: t.title,
                              sub:
                                  '${fmt.format(t.startTime)} – ${fmt.format(t.endTime)}',
                              isDone: t.endTime.isBefore(now),
                              isOngoing: isOngoing,
                              isLog: false,
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('✏️ TIME LOGS'),
                  const SizedBox(height: 12),
                  if (logs.isEmpty)
                    _emptyCard(context, 'Check-in logs\nappear here.')
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      itemCount: logs.length,
                      itemBuilder: (context, index) {
                        final l = logs[index];
                        return TweenAnimationBuilder<double>(
                          key: ValueKey('log_${l.id}'),
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: Duration(
                            milliseconds: 300 + (index * 100).clamp(0, 500),
                          ),
                          curve: Curves.easeOutCubic,
                          builder: (context, val, child) {
                            return Transform.translate(
                              offset: Offset(0, 20 * (1 - val)),
                              child: Opacity(opacity: val, child: child),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _FeedCard(
                              title: l.text,
                              sub:
                                  '${fmt.format(l.timestamp)} – ${fmt.format(l.timestamp.add(const Duration(hours: 1)))}',
                              isDone: false,
                              isLog: true,
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedCard extends StatelessWidget {
  final String title, sub;
  final bool isDone;
  final bool isLog;
  final bool isOngoing;

  const _FeedCard({
    required this.title,
    required this.sub,
    required this.isDone,
    required this.isLog,
    this.isOngoing = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;

    final Color accent = isLog
        ? AppTheme.accentGold
        : (isDone ? c.muted : AppTheme.accentPrimary);

    final IconData icon = isLog
        ? Icons.edit_note_rounded
        : (isDone
              ? Icons.check_circle_rounded
              : Icons.radio_button_unchecked_rounded);

    // Sticky note styling
    final Color bgColor = isDone
        ? c.surface
        : (isLog
              ? const Color(0xFFF7C979).withAlpha(isLight ? 150 : 60)
              : const Color(
                  0xFF8BA694,
                ).withAlpha(isLight ? 150 : 60)); // Pastel tones

    final borderColor = isDone ? c.sep : Colors.transparent;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8), // More like a sharp sticky note
        border: Border.all(color: borderColor),
        boxShadow: isDone
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withAlpha(isLight ? 10 : 30),
                  blurRadius: 4,
                  offset: const Offset(1, 2),
                ),
              ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDone ? Colors.transparent : accent.withAlpha(40),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: accent, size: 14),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isDone ? c.muted : c.text,
                    fontSize: 12,
                    fontWeight: isOngoing ? FontWeight.bold : FontWeight.w600,
                    decoration: isDone && !isLog
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(sub, style: TextStyle(color: c.muted, fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Widget _emptyCard(BuildContext context, String text) {
  final c = AppColors.of(context);
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: c.surface,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: c.sep),
    ),
    child: Text(
      text,
      style: TextStyle(color: c.muted, fontSize: 11, height: 1.5),
    ),
  );
}

Widget _sectionLabel(String text) => Text(
  text,
  style: const TextStyle(
    color: AppTheme.textMuted,
    fontSize: 10,
    fontWeight: FontWeight.bold,
    letterSpacing: 0.8,
  ),
);

class _AiInsightBottomSheet extends StatelessWidget {
  final AppProvider provider;
  final _Metrics m;
  const _AiInsightBottomSheet({required this.provider, required this.m});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: c.sep),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: c.muted,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  _CategoryTags(m: m),
                  _AiSummaryCard(provider: provider, m: m),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Expense Insight Card ────────────────────────────────────────────────────
const _expCatColors = {
  'Food': Color(0xFFFFD166),
  'Travelling': Color(0xFF4DAAFF),
  'Clothes': Color(0xFFCB80FF),
  'Gadgets': Color(0xFF2EC4B6),
  'Medical': Color(0xFF50E3A4),
  'Other': Color(0xFFAFAFCF),
};
const _expCatIcons = {
  'Food': Icons.restaurant_rounded,
  'Travelling': Icons.flight_rounded,
  'Clothes': Icons.checkroom_rounded,
  'Gadgets': Icons.devices_rounded,
  'Medical': Icons.local_hospital_rounded,
  'Other': Icons.category_rounded,
};

Color _expColor(String cat) => _expCatColors[cat] ?? const Color(0xFFAFAFCF);
IconData _expIcon(String cat) =>
    _expCatIcons[cat] ?? Icons.category_rounded;

class _ExpenseInsightCard extends StatelessWidget {
  final List<ExpenseModel> expenses;
  final DateTime now;

  const _ExpenseInsightCard({required this.expenses, required this.now});

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    if (expenses.isEmpty) return const SizedBox.shrink();

    // ── pre-compute ──────────────────────────────────────────────────────────
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final monthStart = DateTime(now.year, now.month, 1);

    double todayTotal = 0, yesterdayTotal = 0, monthTotal = 0;
    final Map<String, double> todayCats = {};
    final Map<String, double> monthCats = {};

    for (final e in expenses) {
      if (_sameDay(e.timestamp, today)) {
        todayTotal += e.amount;
        todayCats[e.category] = (todayCats[e.category] ?? 0) + e.amount;
      }
      if (_sameDay(e.timestamp, yesterday)) {
        yesterdayTotal += e.amount;
      }
      if (!e.timestamp.isBefore(monthStart)) {
        monthTotal += e.amount;
        monthCats[e.category] = (monthCats[e.category] ?? 0) + e.amount;
      }
    }

    final daysElapsed = math.max(1, now.day);
    final dailyAvg = monthTotal / daysElapsed;
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final daysLeft = daysInMonth - now.day;
    final projected = monthTotal + dailyAvg * daysLeft;

    final activeCats = todayCats.isNotEmpty ? todayCats : monthCats;
    String? topCat;
    double topAmt = 0;
    activeCats.forEach((k, v) {
      if (v > topAmt) { topAmt = v; topCat = k; }
    });

    final spark = List.generate(7, (i) {
      final day = today.subtract(Duration(days: 6 - i));
      return expenses
          .where((e) => _sameDay(e.timestamp, day))
          .fold<double>(0, (s, e) => s + e.amount);
    });
    final sparkMax = spark.fold<double>(1, math.max);

    final delta = todayTotal - yesterdayTotal;
    final hasYesterday = yesterdayTotal > 0;
    final fmt = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.sep),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ───────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppTheme.accentGold.withAlpha(28),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: AppTheme.accentGold,
                      size: 15,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Text(
                    'SPENDING PULSE',
                    style: TextStyle(
                      color: c.text,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Spacer(),
                  if (hasYesterday) ...[
                    Icon(
                      delta > 0
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded,
                      color:
                          delta > 0 ? Colors.redAccent : AppTheme.accentGreen,
                      size: 13,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${delta > 0 ? '+' : ''}${fmt.format(delta.abs())} vs yday',
                      style: TextStyle(
                        color: delta > 0
                            ? Colors.redAccent
                            : AppTheme.accentGreen,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ── Today total + sparkline ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fmt.format(todayTotal),
                        style: TextStyle(
                          color: c.text,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        'today',
                        style: TextStyle(
                          color: c.muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  _ExpSparkline(values: spark, max: sparkMax),
                ],
              ),
            ),

            const SizedBox(height: 14),
            Divider(height: 1, color: c.sep),

            // ── 3-stat row ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  _ExpStat(
                    label: 'Daily avg',
                    value: fmt.format(dailyAvg),
                    icon: Icons.show_chart_rounded,
                    color: AppTheme.accentBlue,
                  ),
                  _ExpVSep(c: c),
                  _ExpStat(
                    label: 'Month so far',
                    value: fmt.format(monthTotal),
                    icon: Icons.calendar_month_rounded,
                    color: AppTheme.accentOrange,
                  ),
                  _ExpVSep(c: c),
                  _ExpStat(
                    label: 'Projected',
                    value: fmt.format(projected),
                    icon: Icons.trending_up_rounded,
                    color: projected > monthTotal * 1.5
                        ? Colors.redAccent
                        : AppTheme.accentGreen,
                  ),
                ],
              ),
            ),

            // ── Category breakdown ────────────────────────────────────────────
            if (activeCats.isNotEmpty) ...[
              Divider(height: 1, color: c.sep),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Text(
                  todayCats.isNotEmpty ? 'TODAY\'S BREAKDOWN' : 'MONTH BREAKDOWN',
                  style: TextStyle(
                    color: c.muted,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _ExpCatBar(cats: activeCats),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: (activeCats.entries.toList()
                        ..sort((a, b) => b.value.compareTo(a.value)))
                      .map((e) {
                    final col = _expColor(e.key);
                    final total = activeCats.values
                        .fold<double>(0, (s, v) => s + v);
                    final pct = total == 0
                        ? 0
                        : (e.value / total * 100).round();
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: col.withAlpha(22),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: col.withAlpha(60)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_expIcon(e.key), color: col, size: 11),
                          const SizedBox(width: 4),
                          Text(
                            '${e.key}  $pct%',
                            style: TextStyle(
                              color: col,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ] else
              const SizedBox(height: 12),

            // ── Top category highlight ────────────────────────────────────────
            if (topCat != null) ...[
              Divider(height: 1, color: c.sep),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Row(
                  children: [
                    const Icon(
                      Icons.local_fire_department_rounded,
                      color: AppTheme.accentGold,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Biggest drain: ',
                      style: TextStyle(color: c.muted, fontSize: 11),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _expColor(topCat!).withAlpha(25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$topCat  ${fmt.format(topAmt)}',
                        style: TextStyle(
                          color: _expColor(topCat!),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExpCatBar extends StatelessWidget {
  final Map<String, double> cats;
  const _ExpCatBar({required this.cats});

  @override
  Widget build(BuildContext context) {
    final total = cats.values.fold<double>(0, (s, v) => s + v);
    if (total == 0) return const SizedBox.shrink();
    final sorted = cats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 7,
        child: Row(
          children: sorted.map((e) {
            return Flexible(
              flex: (e.value / total * 1000).round(),
              child: Container(color: _expColor(e.key)),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _ExpSparkline extends StatelessWidget {
  final List<double> values;
  final double max;
  const _ExpSparkline({required this.values, required this.max});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(values.length, (i) {
        final frac = max == 0 ? 0.0 : (values[i] / max).clamp(0.0, 1.0);
        final isToday = i == values.length - 1;
        return Padding(
          padding: const EdgeInsets.only(left: 3),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutCubic,
                width: 8,
                height: math.max(3, 32 * frac),
                decoration: BoxDecoration(
                  color: isToday
                      ? AppTheme.accentGold
                      : (values[i] > 0
                          ? c.primary.withAlpha(140)
                          : c.surfaceMid),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 3),
              isToday
                  ? const Text(
                      'T',
                      style: TextStyle(
                        color: AppTheme.accentGold,
                        fontSize: 7,
                        fontWeight: FontWeight.w800,
                      ),
                    )
                  : const SizedBox(height: 9),
            ],
          ),
        );
      }),
    );
  }
}

class _ExpStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _ExpStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: c.text,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: c.muted,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpVSep extends StatelessWidget {
  final AppColors c;
  const _ExpVSep({required this.c});
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 36, color: c.sep);
}
