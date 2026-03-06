import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/task_model.dart';
import '../models/log_entry_model.dart';
import '../theme/app_theme.dart';
import 'add_task_dialog.dart';
import 'package:intl/intl.dart';

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

    final lastLog = logs.isNotEmpty ? logs.last : null;
    final trackedMin = todayTasks.fold<int>(
      0,
      (s, t) => s + t.endTime.difference(t.startTime).inMinutes,
    );
    final loggedMin =
        todayLogs.length *
        30; // approximate (actual interval unknown per entry)
    final elapsedMin = (now.hour * 60 + now.minute - 6 * 60).clamp(0, 18 * 60);
    final tasksDone = todayTasks.where((t) => t.endTime.isBefore(now)).length;

    // Top activity from logs
    final freq = <String, int>{};
    for (final l in todayLogs) {
      freq[l.text] = (freq[l.text] ?? 0) + 1;
    }
    String? topActivity;
    if (freq.isNotEmpty) {
      topActivity = freq.entries
          .reduce((a, b) => a.value >= b.value ? a : b)
          .key;
    }

    return _Metrics(
      prev: prev,
      current: current,
      next: next,
      lastLog: lastLog,
      todayTasks: todayTasks,
      todayLogs: todayLogs,
      trackedMin: trackedMin,
      loggedMin: loggedMin,
      elapsedMin: elapsedMin,
      tasksTotal: todayTasks.length,
      tasksDone: tasksDone,
      topActivity: topActivity,
    );
  }

  void _addTask(BuildContext context, DateTime now) {
    final snapped = ((now.hour * 60 + now.minute) / 30).round() * 30;
    final start = DateTime(
      now.year,
      now.month,
      now.day,
      snapped ~/ 60,
      snapped % 60,
    );
    showDialog(
      context: context,
      builder: (_) => AddTaskDialog(
        initialStartTime: start,
        initialEndTime: start.add(const Duration(minutes: 30)),
      ),
    );
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

    return Scaffold(
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'log_now_fab',
            onPressed: () => _logNow(context),
            backgroundColor: AppTheme.accentGold,
            icon: const Icon(Icons.edit_note_rounded, color: Colors.white),
            label: const Text(
              'Log Now',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          FloatingActionButton(
            heroTag: 'add_task_fab',
            onPressed: () => _addTask(context, now),
            backgroundColor: AppTheme.accentPrimary,
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
          ),
        ],
      ),
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _Header(provider: provider, now: now),
            ),
            SliverToBoxAdapter(
              child: _NowCard(metrics: m, now: now),
            ),
            SliverToBoxAdapter(child: _StatStrip(m: m)),
            SliverToBoxAdapter(
              child: _DonutCard(m: m, now: now),
            ),
            SliverToBoxAdapter(
              child: _AnimatedFeed(m: m, now: now),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }
}

// ── Data ─────────────────────────────────────────────────────────────────────
class _Metrics {
  final TaskModel? prev, current, next;
  final LogEntry? lastLog;
  final List<TaskModel> todayTasks;
  final List<LogEntry> todayLogs;
  final int trackedMin, loggedMin, elapsedMin;
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
    required this.loggedMin,
    required this.elapsedMin,
    required this.tasksTotal,
    required this.tasksDone,
    this.topActivity,
  });

  double get dayFraction => (elapsedMin / (18 * 60)).clamp(0.0, 1.0);
  double get planCoverage =>
      elapsedMin == 0 ? 0 : (trackedMin / elapsedMin).clamp(0.0, 1.0);
  double get taskDoneRatio => tasksTotal == 0 ? 0 : tasksDone / tasksTotal;
}

// ── Header ────────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final AppProvider provider;
  final DateTime now;
  const _Header({required this.provider, required this.now});

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

  @override
  Widget build(BuildContext context) {
    final th = m.trackedMin ~/ 60;
    final tm = m.trackedMin % 60;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: _Chip(
              icon: Icons.calendar_today_rounded,
              label: 'Planned',
              value: th > 0 ? '${th}h ${tm}m' : '${tm}m',
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
              icon: Icons.edit_note_rounded,
              label: 'Time logs',
              value: '${m.todayLogs.length}',
              sub: 'entries today',
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

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final remMin = ((1 - m.dayFraction) * 18 * 60).round();
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
                  const SizedBox(height: 8),
                  _Legend(
                    color: AppTheme.accentPrimary,
                    label: 'Tasks planned',
                    value: '${(m.planCoverage * 100).round()}% of elapsed',
                  ),
                  const SizedBox(height: 4),
                  _Legend(
                    color: AppTheme.accentGold,
                    label: 'Time log entries',
                    value: '${m.todayLogs.length} so far',
                  ),
                  const SizedBox(height: 4),
                  _Legend(
                    color: AppTheme.separator,
                    label: 'Remaining',
                    value: '~${remMin ~/ 60}h ${remMin % 60}m left',
                  ),
                  if (m.topActivity != null) ...[
                    const SizedBox(height: 8),
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

class _Legend extends StatelessWidget {
  final Color color;
  final String label, value;
  const _Legend({
    super.key,
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
    final c = AppColors.of(context);
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
                    SizedBox(
                      // Max 5 items roughly ~350px tall to enable scrolling
                      height: 350,
                      child: ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.zero,
                        itemCount: tasks.length,
                        itemBuilder: (context, index) {
                          final t = tasks[index];
                          final isOngoing =
                              t.startTime.isBefore(now) &&
                              t.endTime.isAfter(now);
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
                    SizedBox(
                      height: 350,
                      child: ListView.builder(
                        physics: const BouncingScrollPhysics(),
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
