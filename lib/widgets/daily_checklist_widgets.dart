import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';

/// Horizontal strip on Home — tick today’s recurring checklist items.
class DailyChecklistHomeStrip extends StatelessWidget {
  const DailyChecklistHomeStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final items = provider.dailyChecklistItems;
    final c = AppColors.of(context);
    final today = DateTime.now();
    final d = DateTime(today.year, today.month, today.day);

    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: c.surfaceMid.withAlpha(90),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.sep),
          ),
          child: Row(
            children: [
              Icon(Icons.checklist_rounded, color: c.muted, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Add daily checklists in the Checklists tab — they appear here each day.',
                  style: TextStyle(color: c.muted, fontSize: 12, height: 1.25),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Row(
              children: [
                Icon(Icons.checklist_rounded, color: c.primary, size: 16),
                const SizedBox(width: 6),
                Text(
                  'TODAY’S CHECKLIST',
                  style: TextStyle(
                    color: c.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
                const Spacer(),
                Text(
                  _progressLabel(provider, d),
                  style: TextStyle(
                    color: c.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 88,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: items.length,
              separatorBuilder: (context, index) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final item = items[index];
                final checked =
                    provider.isDailyChecklistItemChecked(item.id, d);
                return _HomeCheckChip(
                  title: item.title,
                  checked: checked,
                  accent: c.primary,
                  onTap: () =>
                      provider.toggleDailyChecklistItem(item.id, d),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _progressLabel(AppProvider p, DateTime d) {
    final r = p.dailyChecklistProgress(d);
    return '${r.checked}/${r.total}';
  }
}

class _HomeCheckChip extends StatelessWidget {
  final String title;
  final bool checked;
  final Color accent;
  final VoidCallback onTap;

  const _HomeCheckChip({
    required this.title,
    required this.checked,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 132,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: checked
                ? accent.withAlpha(35)
                : c.surfaceMid.withAlpha(120),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: checked ? accent.withAlpha(180) : c.sep,
              width: checked ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    checked
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    color: checked ? accent : c.muted,
                    size: 20,
                  ),
                  const Spacer(),
                ],
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: checked ? c.text : c.muted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                    decoration:
                        checked ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Footer on Schedule tab — progress for the selected calendar day.
class ScheduleDailyChecklistFooter extends StatelessWidget {
  final DateTime selectedDate;

  const ScheduleDailyChecklistFooter({super.key, required this.selectedDate});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final items = provider.dailyChecklistItems;
    final c = AppColors.of(context);
    final d = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );
    final prog = provider.dailyChecklistProgress(d);

    if (items.isEmpty) return const SizedBox.shrink();

    final ratio = prog.total == 0 ? 0.0 : prog.checked / prog.total;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.sep),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.checklist_rtl_rounded, size: 16, color: c.primary),
                const SizedBox(width: 8),
                Text(
                  'Daily checklist',
                  style: TextStyle(
                    color: c.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  '${prog.checked} of ${prog.total} done',
                  style: TextStyle(color: c.muted, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: ratio.clamp(0.0, 1.0),
                minHeight: 7,
                backgroundColor: c.surfaceMid,
                color: AppTheme.accentPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
