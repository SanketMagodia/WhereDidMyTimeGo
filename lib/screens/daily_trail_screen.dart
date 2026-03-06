import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../models/task_model.dart';
import '../models/log_entry_model.dart';
import '../theme/app_theme.dart';
import 'add_task_dialog.dart';
import 'package:table_calendar/table_calendar.dart';

// ─── Constants ───────────────────────────────────────────────────────────────
const double _px = 2.0; // pixels per minute → 30 min = 60px, 1 hr = 120px
const double _tcw = 52.0; // time column width
const int _snap = 30; // snap grid in minutes

// ─── Helpers ─────────────────────────────────────────────────────────────────
int _toMin(DateTime t) => t.hour * 60 + t.minute;

DateTime _fromMin(DateTime base, int minutes) =>
    DateTime(base.year, base.month, base.day, minutes ~/ 60, minutes % 60);

int _snapMin(int minutes) => (minutes / _snap).round() * _snap;

DateTime _snapTo30(DateTime t) {
  final s = _snapMin(_toMin(t)).clamp(0, 23 * 60 + 30);
  return _fromMin(t, s);
}

// ─── Screen ───────────────────────────────────────────────────────────────────
class DailyTrailScreen extends StatefulWidget {
  const DailyTrailScreen({super.key});
  @override
  State<DailyTrailScreen> createState() => _DailyTrailScreenState();
}

class _DailyTrailScreenState extends State<DailyTrailScreen> {
  final ScrollController _gridScroll = ScrollController();

  DateTime _currentDate = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.week;
  bool _taskResizing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final now = DateTime.now();
      final offset = (now.hour * 60 + now.minute) * _px - 140;
      if (_gridScroll.hasClients) {
        _gridScroll.jumpTo(
          offset.clamp(0.0, _gridScroll.position.maxScrollExtent),
        );
      }
    });
  }

  @override
  void dispose() {
    _gridScroll.dispose();
    super.dispose();
  }

  void _setResizing(bool v) {
    if (_taskResizing != v) setState(() => _taskResizing = v);
  }

  void _onGridTap(TapUpDetails details) {
    final int snapped = _snapMin(
      (details.localPosition.dy / _px).floor(),
    ).clamp(0, 23 * 60 + 30);
    final start = _fromMin(_currentDate, snapped);
    showDialog(
      context: context,
      builder: (_) => AddTaskDialog(
        initialStartTime: start,
        initialEndTime: start.add(const Duration(minutes: _snap)),
      ),
    );
  }

  void _shiftAll(bool up) {
    final p = Provider.of<AppProvider>(context, listen: false);
    p.shiftTasksForDay(_currentDate, Duration(minutes: up ? -30 : 30));
  }

  // ── Resolve overlaps: push colliding tasks away ───────────────────────────
  // Called after a task is moved/resized. Sorts tasks by start, then cascades
  // pushdowns for any task that overlaps its predecessor.
  void _resolveOverlaps(
    AppProvider prov,
    String movedId,
    List<TaskModel> dayTasks,
  ) {
    // Sort tasks by start time
    final sorted = List<TaskModel>.from(dayTasks)
      ..sort((a, b) => _toMin(a.startTime).compareTo(_toMin(b.startTime)));

    bool changed = false;
    for (int i = 1; i < sorted.length; i++) {
      final prev = sorted[i - 1];
      final curr = sorted[i];
      final prevEnd = _toMin(prev.endTime);
      final currStart = _toMin(curr.startTime);
      if (currStart < prevEnd) {
        // Push current task down
        final dur = curr.endTime.difference(curr.startTime);
        final newStart = _fromMin(curr.startTime, prevEnd);
        final newEnd = newStart.add(dur);
        sorted[i] = TaskModel(
          id: curr.id,
          title: curr.title,
          description: curr.description,
          startTime: newStart,
          endTime: newEnd,
        );
        changed = true;
      }
    }

    if (changed) {
      for (final t in sorted) {
        // Only update tasks that actually shifted (not the moved one)
        final original = dayTasks.firstWhere((o) => o.id == t.id);
        if (_toMin(original.startTime) != _toMin(t.startTime)) {
          prov.updateTask(t);
        }
      }
    }
  }

  // ── Calendar ─────────────────────────────────────────────────────────────
  Widget _buildCalendar() {
    // colors read in build, passed here via closure — calendar is stateful
    // so we use Theme directly
    final c = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.sep, width: 1)),
      ),
      child: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.now().subtract(const Duration(days: 365)),
            lastDay: DateTime.now().add(const Duration(days: 365)),
            focusedDay: _currentDate,
            currentDay: DateTime.now(),
            calendarFormat: _calendarFormat,
            startingDayOfWeek: StartingDayOfWeek.monday,
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: false,
              titleTextStyle: TextStyle(
                color: c.text,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
              leftChevronIcon: Icon(
                Icons.chevron_left,
                color: c.text,
                size: 20,
              ),
              rightChevronIcon: Icon(
                Icons.chevron_right,
                color: c.text,
                size: 20,
              ),
              headerPadding: const EdgeInsets.symmetric(
                vertical: 4,
                horizontal: 8,
              ),
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: TextStyle(color: c.muted, fontSize: 11),
              weekendStyle: TextStyle(color: c.muted, fontSize: 11),
            ),
            calendarStyle: CalendarStyle(
              defaultTextStyle: TextStyle(color: c.text, fontSize: 13),
              weekendTextStyle: TextStyle(color: c.text, fontSize: 13),
              outsideTextStyle: TextStyle(color: c.muted, fontSize: 13),
              todayDecoration: BoxDecoration(
                color: c.surfaceMid,
                shape: BoxShape.circle,
                border: Border.all(color: c.primary, width: 1.5),
              ),
              todayTextStyle: TextStyle(
                color: c.primary,
                fontWeight: FontWeight.bold,
              ),
              selectedDecoration: BoxDecoration(
                color: c.primary,
                shape: BoxShape.circle,
              ),
              selectedTextStyle: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              cellMargin: const EdgeInsets.all(3),
            ),
            selectedDayPredicate: (d) => isSameDay(_currentDate, d),
            onDaySelected: (sel, _) => setState(() => _currentDate = sel),
            onFormatChanged: (f) => setState(() => _calendarFormat = f),
            calendarBuilders: CalendarBuilders(
              headerTitleBuilder: (ctx, day) => Row(
                children: [
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('MMMM yyyy').format(day),
                    style: TextStyle(
                      color: c.text,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  _iconBtn(
                    Icons.keyboard_arrow_up_rounded,
                    () => _shiftAll(true),
                    tooltip: 'Shift all earlier',
                  ),
                  _iconBtn(
                    Icons.keyboard_arrow_down_rounded,
                    () => _shiftAll(false),
                    tooltip: 'Shift all later',
                  ),
                ],
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() {
              _calendarFormat = _calendarFormat == CalendarFormat.week
                  ? CalendarFormat.month
                  : CalendarFormat.week;
            }),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Icon(
                _calendarFormat == CalendarFormat.week
                    ? Icons.keyboard_arrow_down_rounded
                    : Icons.keyboard_arrow_up_rounded,
                color: AppTheme.textMuted,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap, {String? tooltip}) =>
      Tooltip(
        message: tooltip ?? '',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(icon, color: AppTheme.textMuted, size: 20),
          ),
        ),
      );

  Widget _buildSectionHeader(
    IconData icon,
    String title,
    Color color, {
    double? width,
  }) {
    final c = AppColors.of(context);
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(
          bottom: BorderSide(color: c.sep, width: 0.5),
          left: BorderSide(color: c.sep, width: 0.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 10, color: color.withValues(alpha: 0.7)),
          const SizedBox(width: 4),
          Text(
            title,
            style: TextStyle(
              color: color.withValues(alpha: 0.9),
              fontSize: 8.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  // ── Grid ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final tasks = provider.tasks
        .where(
          (t) =>
              t.startTime.year == _currentDate.year &&
              t.startTime.month == _currentDate.month &&
              t.startTime.day == _currentDate.day,
        )
        .toList();
    final logs = provider.logs
        .where(
          (l) =>
              l.timestamp.year == _currentDate.year &&
              l.timestamp.month == _currentDate.month &&
              l.timestamp.day == _currentDate.day,
        )
        .toList();

    const double totalH = 24 * 60 * _px;

    final intervalMinutes = provider.logIntervalMinutes;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildCalendar(),
                Expanded(
                  child: Column(
                    children: [
                      // ── Headers ───────────────────────────────────────────
                      Row(
                        children: [
                          _buildSectionHeader(
                            Icons.access_time_rounded,
                            'TIME',
                            AppColors.of(context).muted,
                            width: _tcw,
                          ),
                          Expanded(
                            child: _buildSectionHeader(
                              Icons.calendar_today_rounded,
                              'SCHEDULE',
                              AppColors.of(context).primary,
                            ),
                          ),
                          _buildSectionHeader(
                            Icons.history_rounded,
                            'TIME LOGS',
                            AppColors.of(context).gold,
                            width: 96,
                          ),
                        ],
                      ),
                      // ── Columns ───────────────────────────────────────────
                      Expanded(
                        child: SingleChildScrollView(
                          controller: _gridScroll,
                          physics: _taskResizing
                              ? const NeverScrollableScrollPhysics()
                              : const ClampingScrollPhysics(),
                          child: SizedBox(
                            height: totalH,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: _tcw,
                                  child: Stack(
                                    children: List.generate(
                                      25,
                                      (i) => Positioned(
                                        top: i * 60 * _px - 8,
                                        left: 0,
                                        right: 4,
                                        child: Text(
                                          '${i.toString().padLeft(2, '0')}:00',
                                          textAlign: TextAlign.right,
                                          style: TextStyle(
                                            color: AppColors.of(context).muted,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Stack(
                                    children: [
                                      // Tap-to-create: covers full grid area
                                      Positioned.fill(
                                        child: GestureDetector(
                                          onTapUp: _onGridTap,
                                          behavior: HitTestBehavior.opaque,
                                          child: CustomPaint(
                                            painter: _GridPainter(),
                                          ),
                                        ),
                                      ),
                                      ...tasks.map(
                                        (t) => _TaskBlock(
                                          key: ValueKey(t.id),
                                          task: t,
                                          allDayTasks: tasks,
                                          onResizeStart: () =>
                                              _setResizing(true),
                                          onResizeEnd: () {
                                            _setResizing(false);
                                          },
                                          onCommit: (updated) {
                                            final prov =
                                                Provider.of<AppProvider>(
                                                  context,
                                                  listen: false,
                                                );
                                            prov.updateTask(updated);
                                            _resolveOverlaps(
                                              prov,
                                              updated.id,
                                              tasks.map((t2) {
                                                return t2.id == updated.id
                                                    ? updated
                                                    : t2;
                                              }).toList(),
                                            );
                                          },
                                        ),
                                      ),
                                      if (isSameDay(
                                        _currentDate,
                                        DateTime.now(),
                                      ))
                                        _NowLine(),
                                    ],
                                  ),
                                ),
                                SizedBox(
                                  width: 96,
                                  child: Stack(
                                    children: [
                                      // subtle grid lines for logs column
                                      Positioned.fill(
                                        child: GestureDetector(
                                          onTapUp: (details) {
                                            final int snapped = _snapMin(
                                              (details.localPosition.dy / _px)
                                                  .floor(),
                                            ).clamp(0, 23 * 60 + 30);
                                            final t = _fromMin(
                                              _currentDate,
                                              snapped,
                                            );
                                            final hourStart = DateTime(
                                              t.year,
                                              t.month,
                                              t.day,
                                              t.hour,
                                              0,
                                            );

                                            // Check if log already exists
                                            final existingLog = logs
                                                .where(
                                                  (l) =>
                                                      l.timestamp ==
                                                          hourStart &&
                                                      !l.isSleep,
                                                )
                                                .firstOrNull;

                                            if (existingLog != null) {
                                              // Already exists, just edit it (optional enhancement, but _HourlyLogBlock already handles its own tap)
                                              return;
                                            }

                                            // Create template LogEntry
                                            final n = 60 ~/ intervalMinutes;
                                            final emptyText = List.filled(
                                              n,
                                              '',
                                            ).join(' • ');

                                            showDialog(
                                              context: context,
                                              builder: (_) => _LogEditDialog(
                                                log: LogEntry(
                                                  id: hourStart
                                                      .millisecondsSinceEpoch
                                                      .toString(),
                                                  timestamp: hourStart,
                                                  text: emptyText,
                                                ),
                                                sections: List.filled(n, ''),
                                                intervalMinutes:
                                                    intervalMinutes,
                                              ),
                                            );
                                          },
                                          behavior: HitTestBehavior.opaque,
                                          child: CustomPaint(
                                            painter: _GridPainter(),
                                          ),
                                        ),
                                      ),
                                      ...logs.map(
                                        (l) => _HourlyLogBlock(
                                          key: ValueKey('log_${l.id}'),
                                          log: l,
                                          intervalMinutes: intervalMinutes,
                                        ),
                                      ),
                                      if (isSameDay(
                                        _currentDate,
                                        DateTime.now(),
                                      ))
                                        _NowLine(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // ── Shift FAB — bottom right, above nav bar ─────────────────────
            Positioned(
              bottom: 16,
              right: 16,
              child: _ShiftButtons(
                onShift: (delay) => _shiftFutureTasks(delay, provider),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Shifts only tasks whose startTime is AFTER now by [intervalMinutes].
  /// Tasks that have already started or are in the past are NOT moved.
  void _shiftFutureTasks(bool delay, AppProvider provider) {
    final now = DateTime.now();
    const interval = 30; // fixed 30-minute shift regardless of log interval
    final dt = Duration(minutes: delay ? interval : -interval);
    final tasks = provider.tasks
        .where(
          (t) =>
              t.startTime.year == _currentDate.year &&
              t.startTime.month == _currentDate.month &&
              t.startTime.day == _currentDate.day &&
              t.startTime.isAfter(now), // ← future only
        )
        .toList();

    for (final task in tasks) {
      final newStart = task.startTime.add(dt);
      // Never move before current time
      if (!delay && newStart.isBefore(now)) continue;
      provider.updateTask(
        TaskModel(
          id: task.id,
          title: task.title,
          description: task.description,
          startTime: newStart,
          endTime: task.endTime.add(dt),
        ),
      );
    }
  }
} // end _DailyTrailScreenState

// ─── Shift buttons widget ─────────────────────────────────────────────────────
// Floating bottom-right buttons; shifts tasks by a fixed 30 minutes.
class _ShiftButtons extends StatelessWidget {
  final void Function(bool delay) onShift;
  const _ShiftButtons({required this.onShift});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: 'Move future tasks 30 min earlier',
          child: Material(
            color: c.surface,
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onShift(false),
              child: Container(
                width: 110,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(color: c.secondary),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.arrow_upward_rounded,
                      color: c.secondary,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '-30m earlier',
                      style: TextStyle(
                        color: c.secondary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Tooltip(
          message: 'Delay future tasks by 30 min',
          child: Material(
            color: c.surface,
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onShift(true),
              child: Container(
                width: 110,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(color: c.primary),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.arrow_downward_rounded,
                      color: c.primary,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '+30m delay',
                      style: TextStyle(
                        color: c.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Hourly log block ─────────────────────────────────────────────────────────
// Fills the full 60-minute height for that hour, divided into sub-sections
// matching the user's log interval. Tap to edit any section.
class _HourlyLogBlock extends StatelessWidget {
  final dynamic log;
  final int intervalMinutes;
  const _HourlyLogBlock({
    super.key,
    required this.log,
    required this.intervalMinutes,
  });

  @override
  Widget build(BuildContext context) {
    final t = log.timestamp as DateTime;
    final bool isSleep = (log.isSleep as bool?) ?? false;

    // Always anchored to the start of the hour (bucketStart = log.timestamp)
    final double top = (t.hour * 60) * _px;
    final double blockHeight = 60 * _px;

    // Number of sub-sections
    final int n = isSleep ? 1 : (60 ~/ intervalMinutes).clamp(1, 6);
    // Note: no manual sectionH arithmetic — we use Expanded to avoid float rounding errors.

    // Parse text into per-section strings
    final List<String> rawParts = (log.text as String).split(' • ');
    final List<String> sections = List.generate(n, (i) {
      if (i < rawParts.length) return rawParts[i];
      return ''; // future sub-slots not yet logged — show blank
    });

    final Color baseColor = isSleep
        ? AppTheme.accentPrimary.withValues(alpha: 0.85)
        : AppTheme.accentGold.withValues(alpha: 0.85);
    final Color accentColor = isSleep
        ? AppTheme.accentPrimary
        : AppTheme.accentGold;

    return Positioned(
      top: top,
      left: 0,
      right: 0,
      height: blockHeight,
      child: GestureDetector(
        onTap: isSleep ? null : () => _showEditDialog(context, sections),
        child: Container(
          decoration: BoxDecoration(
            color: baseColor,
            border: Border(
              left: BorderSide(color: accentColor, width: 2.5),
              top: BorderSide(
                color: accentColor.withValues(alpha: 0.4),
                width: 0.5,
              ),
              bottom: BorderSide(
                color: accentColor.withValues(alpha: 0.4),
                width: 0.5,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 3,
                offset: const Offset(-1, 1),
              ),
            ],
          ),
          clipBehavior: Clip.hardEdge,
          child: Column(
            children: List.generate(n, (i) {
              final sectionTime = DateTime(
                t.year,
                t.month,
                t.day,
                t.hour,
                i * intervalMinutes,
              );
              final timeLabel =
                  '${sectionTime.hour.toString().padLeft(2, '0')}:${sectionTime.minute.toString().padLeft(2, '0')}';
              return Expanded(
                child: ClipRect(
                  child: Container(
                    decoration: i < n - 1
                        ? BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: Colors.white.withValues(alpha: 0.25),
                                width: 0.5,
                              ),
                            ),
                          )
                        : null,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    child: OverflowBox(
                      alignment: Alignment.topLeft,
                      maxHeight: double.infinity,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            timeLabel,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 7,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                          Text(
                            sections[i],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              height: 1.2,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, List<String> sections) {
    showDialog(
      context: context,
      builder: (_) => _LogEditDialog(
        log: log,
        sections: sections,
        intervalMinutes: intervalMinutes,
      ),
    );
  }
}

// ─── Log edit dialog ───────────────────────────────────────────────────────────
class _LogEditDialog extends StatefulWidget {
  final dynamic log;
  final List<String> sections;
  final int intervalMinutes;
  const _LogEditDialog({
    required this.log,
    required this.sections,
    required this.intervalMinutes,
  });

  @override
  State<_LogEditDialog> createState() => _LogEditDialogState();
}

class _LogEditDialogState extends State<_LogEditDialog> {
  late final List<TextEditingController> _ctrls;

  @override
  void initState() {
    super.initState();
    _ctrls = widget.sections
        .map((s) => TextEditingController(text: s))
        .toList();
  }

  @override
  void dispose() {
    for (final c in _ctrls) c.dispose();
    super.dispose();
  }

  void _copyDown(int fromIndex) {
    final text = _ctrls[fromIndex].text.trim();
    for (var j = fromIndex + 1; j < _ctrls.length; j++) {
      _ctrls[j].text = text;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final t = widget.log.timestamp as DateTime;
    final n = widget.sections.length;

    return AlertDialog(
      backgroundColor: colors.surface,
      title: Text(
        'Edit ${t.hour.toString().padLeft(2, '0')}:00 – ${(t.hour + 1).toString().padLeft(2, '0')}:00',
        style: TextStyle(
          color: colors.text,
          fontSize: 15,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(n, (i) {
            final secStart = DateTime(
              t.year,
              t.month,
              t.day,
              t.hour,
              i * widget.intervalMinutes,
            );
            final secEnd = DateTime(
              t.year,
              t.month,
              t.day,
              t.hour,
              (i + 1) * widget.intervalMinutes,
            );
            final label =
                '${secStart.hour.toString().padLeft(2, '0')}:${secStart.minute.toString().padLeft(2, '0')}'
                ' – '
                '${secEnd.hour.toString().padLeft(2, '0')}:${secEnd.minute.toString().padLeft(2, '0')}';
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        label,
                        style: TextStyle(color: colors.muted, fontSize: 11),
                      ),
                      const Spacer(),
                      // Copy this section's text to all sections below
                      if (i < n - 1)
                        Tooltip(
                          message: 'Copy to remaining sections',
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => _copyDown(i),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                Icons.arrow_downward_rounded,
                                size: 14,
                                color: AppTheme.accentGold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _ctrls[i],
                    style: TextStyle(color: colors.text, fontSize: 13),
                    maxLines: 2,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: colors.surfaceMid,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: colors.muted)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accentGold,
            foregroundColor: Colors.black87,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: () {
            final newText = _ctrls
                .map((c) => c.text.trim())
                .where((s) => s.isNotEmpty)
                .join(' • ');
            final updated = (widget.log as LogEntry).copyWith(text: newText);
            Provider.of<AppProvider>(context, listen: false).updateLog(updated);
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

// ─── Now line ─────────────────────────────────────────────────────────────────
class _NowLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final top = (now.hour * 60 + now.minute) * _px;
    return Positioned(
      top: top,
      left: 0,
      right: 0,
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: AppTheme.accentSecondary,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Container(height: 1.5, color: AppTheme.accentSecondary),
          ),
        ],
      ),
    );
  }
}

// ─── Grid painter ─────────────────────────────────────────────────────────────
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final hour = Paint()
      ..color = AppTheme.separator
      ..strokeWidth = 1;
    final half = Paint()
      ..color = AppTheme.separator.withValues(alpha: 0.4)
      ..strokeWidth = 0.5;
    for (int i = 0; i <= 24; i++) {
      canvas.drawLine(
        Offset(0, i * 60 * _px),
        Offset(size.width, i * 60 * _px),
        hour,
      );
      if (i < 24) {
        final y2 = (i * 60 + 30) * _px;
        canvas.drawLine(Offset(0, y2), Offset(size.width, y2), half);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ─── Task colors ──────────────────────────────────────────────────────────────
const List<Color> _taskColors = [
  Color(0xFF8B80FF), // indigo-violet
  Color(0xFF4ECDC4), // teal
  Color(0xFFFF6B8A), // rose
  Color(0xFFFFBB40), // amber
  Color(0xFF06D6A0), // mint
  Color(0xFFFF9E7E), // peach
  Color(0xFFA855F7), // purple
];

Color _taskColor(String id) =>
    _taskColors[id.hashCode.abs() % _taskColors.length];

// ─── Task block ───────────────────────────────────────────────────────────────
class _TaskBlock extends StatefulWidget {
  final TaskModel task;
  final List<TaskModel> allDayTasks;
  final VoidCallback onResizeStart;
  final VoidCallback onResizeEnd;
  final void Function(TaskModel) onCommit;

  const _TaskBlock({
    super.key,
    required this.task,
    required this.allDayTasks,
    required this.onResizeStart,
    required this.onResizeEnd,
    required this.onCommit,
  });

  @override
  State<_TaskBlock> createState() => _TaskBlockState();
}

class _TaskBlockState extends State<_TaskBlock>
    with SingleTickerProviderStateMixin {
  late DateTime _start;
  late DateTime _end;
  bool _dragging = false;
  double _tailResidue = 0;

  late final AnimationController _anim;
  late Animation<double> _elevation;

  @override
  void initState() {
    super.initState();
    _start = widget.task.startTime;
    _end = widget.task.endTime;
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _elevation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_TaskBlock old) {
    super.didUpdateWidget(old);
    if (!_dragging) {
      _start = widget.task.startTime;
      _end = widget.task.endTime;
    }
  }

  void _commit() {
    _anim.reverse();
    setState(() => _dragging = false);
    widget.onCommit(
      TaskModel(
        id: widget.task.id,
        title: widget.task.title,
        description: widget.task.description,
        startTime: _start,
        endTime: _end,
      ),
    );
  }

  // ── Body drag ────────────────────────────────────────────────────────────
  void _onBodyLongStart(LongPressStartDetails _) {
    HapticFeedback.mediumImpact();
    _anim.forward();
    setState(() => _dragging = true);
  }

  void _onBodyLongMove(LongPressMoveUpdateDetails d) {
    final rawOffset = d.localOffsetFromOrigin.dy;
    final rawMin = (rawOffset / _px).round();
    final snappedDelta = (rawMin / _snap).round() * _snap;
    final dur = widget.task.endTime.difference(widget.task.startTime);
    final newStart = _snapTo30(
      widget.task.startTime.add(Duration(minutes: snappedDelta)),
    );
    setState(() {
      _start = newStart;
      _end = newStart.add(dur);
    });
  }

  void _onBodyLongEnd(LongPressEndDetails _) {
    HapticFeedback.lightImpact();
    _commit();
  }

  // ── Tail drag (resize) ─────────────────────────────────────────────────
  void _onTailDragStart(DragStartDetails _) {
    widget.onResizeStart();
    HapticFeedback.selectionClick();
    setState(() {
      _dragging = true;
      _tailResidue = 0;
    });
  }

  void _onTailDragUpdate(DragUpdateDetails d) {
    _tailResidue += d.delta.dy;
    const double pps = _snap * _px;
    while (_tailResidue >= pps) {
      final candidate = _end.add(const Duration(minutes: _snap));
      if (candidate.difference(_start).inMinutes <= 23 * 60) {
        setState(() => _end = candidate);
        HapticFeedback.selectionClick();
      }
      _tailResidue -= pps;
    }
    while (_tailResidue <= -pps) {
      final candidate = _end.subtract(const Duration(minutes: _snap));
      if (candidate.difference(_start).inMinutes >= _snap) {
        setState(() => _end = candidate);
        HapticFeedback.selectionClick();
      }
      _tailResidue += pps;
    }
  }

  void _onTailDragEnd(DragEndDetails _) {
    widget.onResizeEnd();
    _commit();
  }

  // ── Edit / detail modal ──────────────────────────────────────────────────
  void _openDetail() {
    if (_dragging) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceDark,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.textMuted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _taskColor(widget.task.id),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.task.title,
                        style: const TextStyle(
                          color: AppTheme.textMain,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${_fmt(_start)} – ${_fmt(_end)}',
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.edit_outlined,
                    color: AppTheme.textMuted,
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    Future.delayed(const Duration(milliseconds: 100), _edit);
                  },
                ),
              ],
            ),
            if (widget.task.description != null &&
                widget.task.description!.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Description',
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.task.description!,
                style: const TextStyle(
                  color: AppTheme.textMain,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _edit() {
    showDialog(
      context: context,
      builder: (_) => AddTaskDialog(
        initialStartTime: _start,
        initialEndTime: _end,
        existingTask: widget.task,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double top = (_start.hour * 60 + _start.minute) * _px;
    final int durMin = _end.difference(_start).inMinutes.clamp(_snap, 24 * 60);
    final double h = durMin * _px;
    final Color col = _taskColor(widget.task.id);

    return AnimatedPositioned(
      duration: _dragging ? Duration.zero : const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      top: top,
      left: 3,
      right: 3,
      height: h,
      child: AnimatedBuilder(
        animation: _elevation,
        builder: (_, child) => Material(
          color: Colors.transparent,
          elevation: _elevation.value * 12,
          borderRadius: BorderRadius.circular(8),
          child: child,
        ),
        child: GestureDetector(
          onTap: _openDetail,
          onLongPressStart: _onBodyLongStart,
          onLongPressMoveUpdate: _onBodyLongMove,
          onLongPressEnd: _onBodyLongEnd,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: _dragging
                  ? col.withValues(alpha: 0.75)
                  : col.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(8),
              boxShadow: _dragging
                  ? [
                      BoxShadow(
                        color: col.withValues(alpha: 0.45),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
            ),
            child: Stack(
              children: [
                // Content
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(7, 4, 22, 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left accent bar
                        Container(
                          width: 3,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 5),
                        // title / description / time
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.task.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (h > 52 &&
                                  widget.task.description != null &&
                                  widget.task.description!.isNotEmpty)
                                Text(
                                  widget.task.description!,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.72),
                                    fontSize: 10,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              if (h > 36)
                                Text(
                                  '${_fmt(_start)} – ${_fmt(_end)}',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.55),
                                    fontSize: 9,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Resize handle — small '⌐' corner in bottom-right
                Positioned(
                  bottom: 2,
                  right: 4,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragStart: _onTailDragStart,
                    onVerticalDragUpdate: _onTailDragUpdate,
                    onVerticalDragEnd: _onTailDragEnd,
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: Center(
                        child: Text(
                          '⌐',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _fmt(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}
