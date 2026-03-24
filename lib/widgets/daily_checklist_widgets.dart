import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';

/// Compact checklist strip on Home — minimal checkmark-style items.
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
        child: Row(
          children: [
            Icon(Icons.playlist_add_check_rounded, color: c.muted, size: 16),
            const SizedBox(width: 8),
            Text(
              'Add daily habits in Checklists tab',
              style: TextStyle(color: c.muted, fontSize: 11),
            ),
          ],
        ),
      );
    }

    final prog = provider.dailyChecklistProgress(d);
    final allDone = prog.checked == prog.total && prog.total > 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: allDone
              ? c.secondary.withAlpha(12)
              : c.surfaceMid.withAlpha(60),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: allDone ? c.secondary.withAlpha(60) : c.sep.withAlpha(80),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: allDone
                        ? c.secondary.withAlpha(30)
                        : c.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    allDone
                        ? Icons.done_all_rounded
                        : Icons.playlist_add_check_rounded,
                    color: allDone ? c.secondary : c.primary,
                    size: 13,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Daily habits',
                  style: TextStyle(
                    color: c.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: allDone
                        ? c.secondary.withAlpha(25)
                        : c.muted.withAlpha(18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${prog.checked}/${prog.total}',
                    style: TextStyle(
                      color: allDone ? c.secondary : c.muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Compact checklist items
            Wrap(
              spacing: 0,
              runSpacing: 2,
              children: items.map((item) {
                final checked = provider.isDailyChecklistItemChecked(
                  item.id,
                  d,
                );
                return _CompactCheckItem(
                  title: item.title,
                  checked: checked,
                  onTap: () => provider.toggleDailyChecklistItem(item.id, d),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactCheckItem extends StatelessWidget {
  final String title;
  final bool checked;
  final VoidCallback onTap;

  const _CompactCheckItem({
    required this.title,
    required this.checked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: checked ? c.secondary : Colors.transparent,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: checked ? c.secondary : c.muted.withAlpha(100),
                    width: 1.5,
                  ),
                ),
                child: checked
                    ? const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 12,
                      )
                    : null,
              ),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.6,
                ),
                child: Text(
                  title,
                  style: TextStyle(
                    color: checked ? c.muted : c.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    decoration: checked ? TextDecoration.lineThrough : null,
                    decorationColor: c.muted,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
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
    final d = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
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
