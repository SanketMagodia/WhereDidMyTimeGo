import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../models/expense_model.dart';
import '../theme/app_theme.dart';
import 'investments_screen.dart';

// ─── Category visual config ───────────────────────────────────────────────────
const _catIcons = {
  'Food': Icons.restaurant_rounded,
  'Travelling': Icons.flight_rounded,
  'Clothes': Icons.checkroom_rounded,
  'Gadgets': Icons.devices_rounded,
  'Medical': Icons.local_hospital_rounded,
  'Other': Icons.category_rounded,
};

const _catColors = {
  'Food': Color(0xFFFFD166), // golden yellow — pops on orange
  'Travelling': Color(0xFF4DAAFF), // sky blue
  'Clothes': Color(0xFFCB80FF), // soft purple
  'Gadgets': Color(0xFF2EC4B6), // teal
  'Medical': Color(0xFF50E3A4), // mint green
  'Other': Color(0xFFAFAFCF), // cool grey
};

Color _catColor(String cat) => _catColors[cat] ?? const Color(0xFF7A7A9A);
IconData _catIcon(String cat) => _catIcons[cat] ?? Icons.category_rounded;

final _currency = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
final _shortFmt = DateFormat('d MMM');
final _dayFmt = DateFormat('EEE, d MMM');

// ─── Screen ───────────────────────────────────────────────────────────────────
class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});
  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  bool _sortByAmount = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _openAdd(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddExpenseSheet(),
    );
  }

  void _openFixedExpenses(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _FixedExpensesSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final c = AppColors.of(context);
    final expenses = _sorted(provider.expenses);

    return Scaffold(
      backgroundColor: c.bg,
      floatingActionButton: FloatingActionButton(
        heroTag: 'add_expense_fab',
        onPressed: () => _openAdd(context),
        backgroundColor: c.primary,
        foregroundColor: Colors.white,
        elevation: 5,
        child: const Icon(Icons.add_rounded),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(
              expenses: expenses,
              sortByAmount: _sortByAmount,
              onToggleSort: () =>
                  setState(() => _sortByAmount = !_sortByAmount),
            ),
            // ── Recurring shortcut row ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Row(
                children: [
                  // Fixed Monthly Expenses button
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _openFixedExpenses(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: c.surfaceMid,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: c.sep),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.repeat_rounded,
                              size: 14,
                              color: AppTheme.accentGold,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Fixed Monthly',
                                style: TextStyle(
                                  color: c.text,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Consumer<AppProvider>(
                              builder: (context, p, child) {
                                final count = p.fixedTemplates.length;
                                if (count == 0) return const SizedBox.shrink();
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.accentGold.withAlpha(40),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '$count',
                                    style: const TextStyle(
                                      color: AppTheme.accentGold,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 2),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: c.muted,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Investments button
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const InvestmentsScreen(),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF1B5E20).withAlpha(60),
                              const Color(0xFF2E7D32).withAlpha(40),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF4CAF50).withAlpha(80),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.trending_up_rounded,
                              size: 14,
                              color: Color(0xFF66BB6A),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Investments',
                                style: TextStyle(
                                  color: c.text,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Consumer<AppProvider>(
                              builder: (context, p, child) {
                                final count = p.sips.length;
                                if (count == 0) return const SizedBox.shrink();
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF4CAF50,
                                    ).withAlpha(40),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '$count',
                                    style: const TextStyle(
                                      color: Color(0xFF66BB6A),
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 2),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: c.muted,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _TabBar(controller: _tabs),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _PeriodView(
                    key: const ValueKey('day'),
                    expenses: expenses,
                    period: _Period.day,
                    sortByAmount: _sortByAmount,
                  ),
                  _PeriodView(
                    key: const ValueKey('week'),
                    expenses: expenses,
                    period: _Period.week,
                    sortByAmount: _sortByAmount,
                  ),
                  _PeriodView(
                    key: const ValueKey('month'),
                    expenses: expenses,
                    period: _Period.month,
                    sortByAmount: _sortByAmount,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<ExpenseModel> _sorted(List<ExpenseModel> src) {
    final list = List<ExpenseModel>.from(src);
    if (_sortByAmount) {
      list.sort((a, b) => b.amount.compareTo(a.amount));
    } else {
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    }
    return list;
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final List<ExpenseModel> expenses;
  final bool sortByAmount;
  final VoidCallback onToggleSort;
  const _Header({
    required this.expenses,
    required this.sortByAmount,
    required this.onToggleSort,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final thisMonth = expenses.where(
      (e) =>
          e.timestamp.isAfter(monthStart) || _sameDay(e.timestamp, monthStart),
    );
    final total = thisMonth.fold<double>(0, (s, e) => s + e.amount);

    // top category this month
    final catTotals = <String, double>{};
    for (final e in thisMonth) {
      catTotals[e.category] = (catTotals[e.category] ?? 0) + e.amount;
    }
    String? topCat;
    double topAmt = 0;
    catTotals.forEach((cat, amt) {
      if (amt > topAmt) {
        topAmt = amt;
        topCat = cat;
      }
    });

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFF6B2B), // vibrant burnt orange
            Color(0xFFD44A10), // deep ember
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6B2B).withAlpha(100),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'FINANCE',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              _SortButton(sortByAmount: sortByAmount, onTap: onToggleSort),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _currency.format(total),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
          Text(
            'This month · ${DateFormat('MMMM yyyy').format(now)}',
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
          if (topCat != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _catColor(topCat!).withAlpha(50),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _catIcon(topCat!),
                    color: _catColor(topCat!),
                    size: 14,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Mostly $topCat  ·  ${_currency.format(topAmt)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          _CategoryBar(expenses: thisMonth.toList()),
        ],
      ),
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _SortButton extends StatelessWidget {
  final bool sortByAmount;
  final VoidCallback onTap;
  const _SortButton({required this.sortByAmount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(30),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withAlpha(50)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              sortByAmount
                  ? Icons.attach_money_rounded
                  : Icons.access_time_rounded,
              color: Colors.white,
              size: 12,
            ),
            const SizedBox(width: 4),
            Text(
              sortByAmount ? 'By amount' : 'By date',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Category colour bar ─────────────────────────────────────────────────────
class _CategoryBar extends StatelessWidget {
  final List<ExpenseModel> expenses;
  const _CategoryBar({required this.expenses});

  @override
  Widget build(BuildContext context) {
    if (expenses.isEmpty) return const SizedBox.shrink();
    final total = expenses.fold<double>(0, (s, e) => s + e.amount);
    if (total == 0) return const SizedBox.shrink();
    final catTotals = <String, double>{};
    for (final e in expenses) {
      catTotals[e.category] = (catTotals[e.category] ?? 0) + e.amount;
    }
    final sorted = catTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 8,
            child: Row(
              children: sorted.map((e) {
                return Flexible(
                  flex: (e.value / total * 1000).round(),
                  child: Container(color: _catColor(e.key)),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 4,
          children: sorted.map((e) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: _catColor(e.key),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 3),
                Text(
                  '${e.key} ${(e.value / total * 100).round()}%',
                  style: const TextStyle(color: Colors.white70, fontSize: 9),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ─── Tab bar ─────────────────────────────────────────────────────────────────
class _TabBar extends StatelessWidget {
  final TabController controller;
  const _TabBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: c.surfaceMid,
          borderRadius: BorderRadius.circular(12),
        ),
        child: TabBar(
          controller: controller,
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: BoxDecoration(
            color: c.primary,
            borderRadius: BorderRadius.circular(10),
          ),
          dividerColor: Colors.transparent,
          labelColor: Colors.white,
          unselectedLabelColor: c.muted,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
          tabs: const [
            Tab(text: 'Day'),
            Tab(text: 'Week'),
            Tab(text: 'Month'),
          ],
        ),
      ),
    );
  }
}

// ─── Period filter ────────────────────────────────────────────────────────────
enum _Period { day, week, month }

class _PeriodView extends StatefulWidget {
  final List<ExpenseModel> expenses;
  final _Period period;
  final bool sortByAmount;
  const _PeriodView({
    super.key,
    required this.expenses,
    required this.period,
    required this.sortByAmount,
  });

  @override
  State<_PeriodView> createState() => _PeriodViewState();
}

class _PeriodViewState extends State<_PeriodView> {
  int _offset = 0;

  DateTime get _now => DateTime.now();

  DateTime _periodStart(DateTime now) {
    switch (widget.period) {
      case _Period.day:
        return DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: _offset));
      case _Period.week:
        final monday = now.subtract(Duration(days: now.weekday - 1));
        return DateTime(
          monday.year,
          monday.month,
          monday.day,
        ).subtract(Duration(days: _offset * 7));
      case _Period.month:
        final m = now.month - _offset;
        final y = now.year + (m - 1) ~/ 12;
        final month = ((m - 1) % 12) + 1;
        return DateTime(y, month, 1);
    }
  }

  DateTime _periodEnd(DateTime start) {
    switch (widget.period) {
      case _Period.day:
        return start.add(const Duration(days: 1));
      case _Period.week:
        return start.add(const Duration(days: 7));
      case _Period.month:
        return DateTime(start.year, start.month + 1, 1);
    }
  }

  String _periodLabel(DateTime start, DateTime end) {
    final now = DateTime.now();
    switch (widget.period) {
      case _Period.day:
        if (_offset == 0) return 'Today';
        if (_offset == 1) return 'Yesterday';
        return _dayFmt.format(start);
      case _Period.week:
        if (_offset == 0) return 'This week';
        if (_offset == 1) return 'Last week';
        return '${_shortFmt.format(start)} – ${_shortFmt.format(end.subtract(const Duration(days: 1)))}';
      case _Period.month:
        if (start.year == now.year && start.month == now.month) {
          return 'This month';
        }
        return DateFormat('MMMM yyyy').format(start);
    }
  }

  List<ExpenseModel> get _filtered {
    final start = _periodStart(_now);
    final end = _periodEnd(start);
    return widget.expenses.where((e) {
      return !e.timestamp.isBefore(start) && e.timestamp.isBefore(end);
    }).toList();
  }

  /// Returns a human-readable filename segment based on period + start date.
  String _csvFileName(_Period period, DateTime start) {
    switch (period) {
      case _Period.day:
        // e.g.  10_Mar_2026
        return 'expenses_${DateFormat('d_MMM_yyyy').format(start)}.csv';
      case _Period.week:
        // e.g.  W10_Mar_2026  (ISO week number of the Monday)
        final weekNum = _isoWeekNumber(start);
        return 'expenses_W${weekNum}_${DateFormat('MMM_yyyy').format(start)}.csv';
      case _Period.month:
        // e.g.  Mar_2026
        return 'expenses_${DateFormat('MMM_yyyy').format(start)}.csv';
    }
  }

  /// ISO-8601 week number for a given date.
  int _isoWeekNumber(DateTime date) {
    final dayOfYear = date.difference(DateTime(date.year, 1, 1)).inDays + 1;
    final wday = date.weekday; // 1 = Mon … 7 = Sun
    return ((dayOfYear - wday + 10) / 7).floor();
  }

  Future<void> _exportCsv(
    BuildContext context,
    List<ExpenseModel> items,
    _Period period,
    DateTime start,
  ) async {
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No expenses to export for this period.')),
      );
      return;
    }

    // Build CSV content
    final buf = StringBuffer();
    buf.writeln('Date,Time,Title,Category,Amount,Note');
    final dateFmt = DateFormat('yyyy-MM-dd');
    final timeFmt = DateFormat('HH:mm');
    for (final e in items) {
      final note = (e.note ?? '').replaceAll('"', '""');
      final title = e.title.replaceAll('"', '""');
      buf.writeln(
        '${dateFmt.format(e.timestamp)},'
        '${timeFmt.format(e.timestamp)},'
        '"$title",'
        '${e.category},'
        '${e.amount.toStringAsFixed(2)},'
        '"$note"',
      );
    }

    final fileName = _csvFileName(period, start);

    // Try Android Downloads, fall back to app documents dir
    String? savedPath;
    try {
      const downloadsPath = '/storage/emulated/0/Download';
      final dir = Directory(downloadsPath);
      if (await dir.exists()) {
        final file = File('$downloadsPath/$fileName');
        await file.writeAsString(buf.toString());
        savedPath = file.path;
      }
    } catch (_) {}

    if (savedPath == null) {
      try {
        // Fallback: current directory (desktop / documents)
        final file = File('${Directory.current.path}/$fileName');
        await file.writeAsString(buf.toString());
        savedPath = file.path;
      } catch (_) {}
    }

    if (!context.mounted) return;
    if (savedPath != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved: $savedPath'),
          backgroundColor: const Color(0xFF1D6F42),
          duration: const Duration(seconds: 4),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save CSV — permission denied.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final start = _periodStart(_now);
    final end = _periodEnd(start);
    final items = _filtered;
    final total = items.fold<double>(0, (s, e) => s + e.amount);
    final label = _periodLabel(start, end);

    // Group by day for day-headers in week/month view
    final grouped = <String, List<ExpenseModel>>{};
    for (final e in items) {
      final key = _dayFmt.format(e.timestamp);
      grouped.putIfAbsent(key, () => []).add(e);
    }

    return Column(
      children: [
        // navigation + period summary
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Row(
            children: [
              _NavBtn(
                icon: Icons.chevron_left_rounded,
                onTap: () => setState(() => _offset++),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: c.text,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      _currency.format(total),
                      style: TextStyle(
                        color: c.primary,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              // ── CSV export button (before >) ──────────────────────────────
              const SizedBox(width: 8),
              Tooltip(
                message: 'Export to CSV',
                child: GestureDetector(
                  onTap: () => _exportCsv(context, items, widget.period, start),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1D6F42),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1D6F42).withAlpha(80),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Excel-style "X" grid icon
                          Icon(
                            Icons.grid_on_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                          Positioned(
                            right: 5,
                            bottom: 5,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1D6F42),
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: const Icon(
                                Icons.download_rounded,
                                color: Colors.white,
                                size: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _NavBtn(
                icon: Icons.chevron_right_rounded,
                onTap: _offset == 0 ? null : () => setState(() => _offset--),
                disabled: _offset == 0,
              ),
            ],
          ),
        ),
        // analytics bar chart
        if (items.isNotEmpty)
          _AnalyticsBar(expenses: items, period: widget.period, start: start),
        // transaction list
        Expanded(
          child: items.isEmpty
              ? _EmptyState(period: widget.period)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  itemCount: grouped.length,
                  itemBuilder: (context, gi) {
                    final dayKey = grouped.keys.elementAt(gi);
                    final dayItems = grouped[dayKey]!;
                    final dayTotal = dayItems.fold<double>(
                      0,
                      (s, e) => s + e.amount,
                    );
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.period != _Period.day) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(0, 8, 0, 6),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  dayKey,
                                  style: TextStyle(
                                    color: c.muted,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                Text(
                                  _currency.format(dayTotal),
                                  style: TextStyle(
                                    color: c.muted,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        ...dayItems.map((e) => _ExpenseTile(expense: e)),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool disabled;
  const _NavBtn({required this.icon, this.onTap, this.disabled = false});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: disabled ? c.surfaceMid.withAlpha(80) : c.surfaceMid,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: disabled ? c.muted.withAlpha(80) : c.muted,
          size: 18,
        ),
      ),
    );
  }
}

// ─── Analytics bar chart ─────────────────────────────────────────────────────
class _AnalyticsBar extends StatelessWidget {
  final List<ExpenseModel> expenses;
  final _Period period;
  final DateTime start;
  const _AnalyticsBar({
    required this.expenses,
    required this.period,
    required this.start,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    // Build bucket data
    final List<_Bucket> buckets;
    switch (period) {
      case _Period.day:
        // 6 × 4-hour blocks
        buckets = List.generate(6, (i) {
          final bStart = start.add(Duration(hours: i * 4));
          final bEnd = bStart.add(const Duration(hours: 4));
          final amt = expenses
              .where(
                (e) =>
                    !e.timestamp.isBefore(bStart) && e.timestamp.isBefore(bEnd),
              )
              .fold<double>(0, (s, e) => s + e.amount);
          return _Bucket(
            label: '${bStart.hour.toString().padLeft(2, '0')}h',
            amount: amt,
          );
        });
      case _Period.week:
        buckets = List.generate(7, (i) {
          final day = start.add(Duration(days: i));
          final dayNext = day.add(const Duration(days: 1));
          final amt = expenses
              .where(
                (e) =>
                    !e.timestamp.isBefore(day) && e.timestamp.isBefore(dayNext),
              )
              .fold<double>(0, (s, e) => s + e.amount);
          return _Bucket(label: DateFormat('E').format(day), amount: amt);
        });
      case _Period.month:
        final daysInMonth = DateTime(start.year, start.month + 1, 0).day;
        final weeks = (daysInMonth / 7).ceil();
        buckets = List.generate(weeks, (i) {
          final wStart = start.add(Duration(days: i * 7));
          final wEnd = DateTime(
            wStart.year,
            wStart.month,
            math.min(wStart.day + 7, daysInMonth + 1),
          );
          final amt = expenses
              .where(
                (e) =>
                    !e.timestamp.isBefore(wStart) && e.timestamp.isBefore(wEnd),
              )
              .fold<double>(0, (s, e) => s + e.amount);
          return _Bucket(label: 'W${i + 1}', amount: amt);
        });
    }

    final maxAmt = buckets.fold<double>(0, (m, b) => math.max(m, b.amount));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Container(
        height: 100,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.sep),
        ),
        child: LayoutBuilder(
          builder: (ctx, constraints) {
            // Reserve fixed space for bottom label + bottom spacing + top spacing
            const labelH = 13.0;
            const topGap = 2.0;
            const bottomGap = 4.0;
            final maxBarH =
                constraints.maxHeight - labelH - topGap - bottomGap - 2;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: buckets.map((b) {
                final frac = maxAmt == 0
                    ? 0.0
                    : (b.amount / maxAmt).clamp(0.0, 1.0);
                // Reserve space for amount label if present; bar gets the rest
                final amtReserved = b.amount > 0 ? 11.0 : 0.0;
                final barH = math.max(3.0, (maxBarH - amtReserved) * frac);

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (b.amount > 0)
                          Text(
                            _currency.format(b.amount).replaceAll('₹', ''),
                            style: TextStyle(
                              color: c.primary,
                              fontSize: 7,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        SizedBox(height: topGap),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeOutCubic,
                          height: barH,
                          decoration: BoxDecoration(
                            color: b.amount > 0 ? c.primary : c.surfaceMid,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                        ),
                        SizedBox(height: bottomGap),
                        SizedBox(
                          height: labelH,
                          child: Text(
                            b.label,
                            style: TextStyle(
                              color: c.muted,
                              fontSize: 8,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ),
    );
  }
}

class _Bucket {
  final String label;
  final double amount;
  const _Bucket({required this.label, required this.amount});
}

// ─── Expense tile ─────────────────────────────────────────────────────────────
class _ExpenseTile extends StatelessWidget {
  final ExpenseModel expense;
  const _ExpenseTile({required this.expense});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final color = _catColor(expense.category);

    return GestureDetector(
      onTap: () => _openEdit(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.sep),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withAlpha(30),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_catIcon(expense.category), color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    expense.title,
                    style: TextStyle(
                      color: c.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: color.withAlpha(25),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          expense.category,
                          style: TextStyle(
                            color: color,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        DateFormat('d MMM · HH:mm').format(expense.timestamp),
                        style: TextStyle(color: c.muted, fontSize: 9),
                      ),
                    ],
                  ),
                  if (expense.note != null && expense.note!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      expense.note!,
                      style: TextStyle(color: c.muted, fontSize: 10),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _currency.format(expense.amount),
              style: TextStyle(
                color: c.text,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openEdit(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddExpenseSheet(existing: expense),
    );
  }
}

// ─── Add / Edit sheet ─────────────────────────────────────────────────────────
class AddExpenseSheet extends StatefulWidget {
  final ExpenseModel? existing;
  const AddExpenseSheet({super.key, this.existing});

  @override
  State<AddExpenseSheet> createState() => AddExpenseSheetState();
}

class AddExpenseSheetState extends State<AddExpenseSheet> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _noteCtrl;
  late String _category;
  late DateTime _timestamp;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _titleCtrl = TextEditingController(text: e?.title ?? '');
    _amountCtrl = TextEditingController(
      text: e != null ? e.amount.toStringAsFixed(0) : '',
    );
    _noteCtrl = TextEditingController(text: e?.note ?? '');
    _category = e?.category ?? 'Other';
    _timestamp = e?.timestamp ?? DateTime.now();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final c = AppColors.of(context);
    final provider = Provider.of<AppProvider>(context, listen: false);
    final nav = Navigator.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Delete expense?',
          style: TextStyle(
            color: c.text,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          '"${widget.existing!.title}" will be permanently removed.',
          style: TextStyle(color: c.muted, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: c.muted)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.delete_rounded, size: 16),
            label: const Text(
              'Delete',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      provider.removeExpense(widget.existing!.id);
      nav.pop();
    }
  }

  void _submit() {
    final title = _titleCtrl.text.trim();
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (title.isEmpty || amount == null || amount <= 0) return;

    final provider = Provider.of<AppProvider>(context, listen: false);
    final e = widget.existing;
    if (e == null) {
      provider.addExpense(
        ExpenseModel(
          title: title,
          amount: amount,
          timestamp: _timestamp,
          category: _category,
          note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        ),
      );
    } else {
      provider.updateExpense(
        e.copyWith(
          title: title,
          amount: amount,
          timestamp: _timestamp,
          category: _category,
          note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        ),
      );
    }
    Navigator.pop(context);
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _timestamp,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (date == null) return;
    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_timestamp),
    );
    if (time == null) return;
    setState(() {
      _timestamp = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final isEdit = widget.existing != null;

    final mq = MediaQuery.of(context);
    final keyboardH = mq.viewInsets.bottom;
    final maxSheetH = mq.size.height * 0.92 - keyboardH;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboardH),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxSheetH),
        child: Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: c.muted.withAlpha(80),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      isEdit ? 'Edit Expense' : 'New Expense',
                      style: TextStyle(
                        color: c.text,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),
                    if (isEdit)
                      GestureDetector(
                        onTap: () => _confirmDelete(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.withAlpha(22),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.red.withAlpha(60)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.red,
                                size: 15,
                              ),
                              SizedBox(width: 5),
                              Text(
                                'Delete',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 18),

                // Title
                _Field(
                  controller: _titleCtrl,
                  label: 'What did you spend on?',
                  hint: 'Lunch, Uber, New shoes…',
                  keyboardType: TextInputType.text,
                ),
                const SizedBox(height: 12),

                // Amount
                _Field(
                  controller: _amountCtrl,
                  label: 'Amount (₹)',
                  hint: '0',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),

                // Note
                _Field(
                  controller: _noteCtrl,
                  label: 'Note (optional)',
                  hint: 'Any extra detail…',
                  keyboardType: TextInputType.text,
                ),
                const SizedBox(height: 16),

                // Date
                GestureDetector(
                  onTap: _pickDateTime,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: c.surfaceMid,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          color: c.muted,
                          size: 16,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          DateFormat(
                            'EEE, d MMM yyyy · HH:mm',
                          ).format(_timestamp),
                          style: TextStyle(color: c.text, fontSize: 13),
                        ),
                        const Spacer(),
                        Icon(Icons.edit_rounded, color: c.muted, size: 14),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Category chips
                Text(
                  'CATEGORY',
                  style: TextStyle(
                    color: c.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: kExpenseCategories.map((cat) {
                    final selected = _category == cat;
                    final col = _catColor(cat);
                    return GestureDetector(
                      onTap: () => setState(() => _category = cat),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: selected ? col.withAlpha(220) : c.surfaceMid,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: selected ? col : c.sep,
                            width: selected ? 0 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _catIcon(cat),
                              color: selected ? Colors.white : col,
                              size: 14,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              cat,
                              style: TextStyle(
                                color: selected ? Colors.white : c.text,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: c.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _submit,
                    child: Text(
                      isEdit ? 'Save changes' : 'Add expense',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
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
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType keyboardType;
  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    required this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: c.muted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: TextStyle(color: c.text, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: c.muted),
            filled: true,
            fillColor: c.surfaceMid,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final _Period period;
  const _EmptyState({required this.period});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    const labels = {
      _Period.day: 'No expenses today',
      _Period.week: 'No expenses this week',
      _Period.month: 'No expenses this month',
    };
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt_long_rounded, color: c.muted, size: 42),
          const SizedBox(height: 10),
          Text(
            labels[period]!,
            style: TextStyle(
              color: c.muted,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap + to add one',
            style: TextStyle(color: c.muted.withAlpha(150), fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ─── Fixed Monthly Expenses Sheet ────────────────────────────────────────────
class _FixedExpensesSheet extends StatelessWidget {
  const _FixedExpensesSheet();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, scrollCtrl) {
        return Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              // handle
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: c.muted.withAlpha(80),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              // title row
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.repeat_rounded,
                      color: AppTheme.accentGold,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Fixed Monthly Expenses',
                      style: TextStyle(
                        color: c.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.add_rounded),
                      color: c.primary,
                      onPressed: () => _openAddTemplate(context),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: Text(
                  'These are added automatically on the 1st of every month '
                  'and excluded from spending projections.',
                  style: TextStyle(color: c.muted, fontSize: 11),
                ),
              ),
              Divider(height: 1, color: c.sep),
              Expanded(
                child: Consumer<AppProvider>(
                  builder: (context, provider, child) {
                    final templates = provider.fixedTemplates;
                    if (templates.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.repeat_rounded,
                              color: c.muted,
                              size: 40,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'No fixed expenses yet',
                              style: TextStyle(
                                color: c.muted,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tap + to add rent, subscriptions…',
                              style: TextStyle(
                                color: c.muted.withAlpha(150),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    final monthlyTotal = templates.fold<double>(
                      0,
                      (s, t) => s + t.amount,
                    );
                    return ListView(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                      children: [
                        // Monthly total pill
                        Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.accentGold.withAlpha(20),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.accentGold.withAlpha(60),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.calendar_month_rounded,
                                color: AppTheme.accentGold,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Total each month',
                                style: TextStyle(color: c.muted, fontSize: 12),
                              ),
                              const Spacer(),
                              Text(
                                NumberFormat.currency(
                                  symbol: '₹',
                                  decimalDigits: 0,
                                ).format(monthlyTotal),
                                style: const TextStyle(
                                  color: AppTheme.accentGold,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ...templates.map(
                          (t) => _FixedTemplateTile(template: t),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openAddTemplate(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _FixedTemplateEditSheet(),
    );
  }
}

class _FixedTemplateTile extends StatelessWidget {
  final FixedExpenseTemplate template;
  const _FixedTemplateTile({required this.template});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final color = _catColor(template.category);
    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _FixedTemplateEditSheet(existing: template),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: c.surfaceMid,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.sep),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withAlpha(30),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(_catIcon(template.category), color: color, size: 17),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    template.title,
                    style: TextStyle(
                      color: c.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: color.withAlpha(25),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          template.category,
                          style: TextStyle(
                            color: color,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.repeat_rounded,
                        size: 10,
                        color: AppTheme.accentGold,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'Every 1st',
                        style: TextStyle(color: c.muted, fontSize: 9),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Text(
              NumberFormat.currency(
                symbol: '₹',
                decimalDigits: 0,
              ).format(template.amount),
              style: TextStyle(
                color: c.text,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FixedTemplateEditSheet extends StatefulWidget {
  final FixedExpenseTemplate? existing;
  const _FixedTemplateEditSheet({this.existing});

  @override
  State<_FixedTemplateEditSheet> createState() =>
      _FixedTemplateEditSheetState();
}

class _FixedTemplateEditSheetState extends State<_FixedTemplateEditSheet> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _noteCtrl;
  late String _category;

  @override
  void initState() {
    super.initState();
    final t = widget.existing;
    _titleCtrl = TextEditingController(text: t?.title ?? '');
    _amountCtrl = TextEditingController(
      text: t != null ? t.amount.toStringAsFixed(0) : '',
    );
    _noteCtrl = TextEditingController(text: t?.note ?? '');
    _category = t?.category ?? 'Other';
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _titleCtrl.text.trim();
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (title.isEmpty || amount == null || amount <= 0) return;
    final provider = Provider.of<AppProvider>(context, listen: false);
    final existing = widget.existing;
    if (existing == null) {
      provider.addFixedTemplate(
        FixedExpenseTemplate(
          title: title,
          amount: amount,
          category: _category,
          note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        ),
      );
    } else {
      provider.updateFixedTemplate(
        existing.copyWith(
          title: title,
          amount: amount,
          category: _category,
          note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        ),
      );
    }
    Navigator.pop(context);
  }

  Future<void> _delete() async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final nav = Navigator.of(context);
    final c = AppColors.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Remove fixed expense?',
          style: TextStyle(
            color: c.text,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          'It will stop being added on the 1st of each month.',
          style: TextStyle(color: c.muted, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: c.muted)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.delete_rounded, size: 16),
            label: const Text(
              'Remove',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      provider.removeFixedTemplate(widget.existing!.id);
      nav.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final isEdit = widget.existing != null;
    final mq = MediaQuery.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: mq.size.height * 0.88),
        child: Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: c.muted.withAlpha(80),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      isEdit ? 'Edit Fixed Expense' : 'New Fixed Expense',
                      style: TextStyle(
                        color: c.text,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),
                    if (isEdit)
                      GestureDetector(
                        onTap: _delete,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.withAlpha(22),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.red.withAlpha(60)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.red,
                                size: 15,
                              ),
                              SizedBox(width: 5),
                              Text(
                                'Remove',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.repeat_rounded,
                      color: AppTheme.accentGold,
                      size: 13,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Auto-added on the 1st of every month',
                      style: TextStyle(color: c.muted, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _Field(
                  controller: _titleCtrl,
                  label: 'What is this fixed expense?',
                  hint: 'Rent, Netflix, Gym membership…',
                  keyboardType: TextInputType.text,
                ),
                const SizedBox(height: 12),
                _Field(
                  controller: _amountCtrl,
                  label: 'Amount (₹)',
                  hint: '0',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                _Field(
                  controller: _noteCtrl,
                  label: 'Note (optional)',
                  hint: 'Any detail…',
                  keyboardType: TextInputType.text,
                ),
                const SizedBox(height: 16),
                Text(
                  'CATEGORY',
                  style: TextStyle(
                    color: c.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: kExpenseCategories.map((cat) {
                    final selected = _category == cat;
                    final col = _catColor(cat);
                    return GestureDetector(
                      onTap: () => setState(() => _category = cat),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: selected ? col.withAlpha(220) : c.surfaceMid,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: selected ? col : c.sep),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _catIcon(cat),
                              color: selected ? Colors.white : col,
                              size: 14,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              cat,
                              style: TextStyle(
                                color: selected ? Colors.white : c.text,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: c.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _submit,
                    child: Text(
                      isEdit ? 'Save changes' : 'Add fixed expense',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
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
}
