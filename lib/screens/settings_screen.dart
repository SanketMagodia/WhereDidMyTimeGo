import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/calendar_sync_service.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        title: Text(
          'Settings',
          style: TextStyle(color: c.text, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: const SettingsBody(),
    );
  }
}

/// Settings content without a Scaffold — safe to embed inside a Drawer.
class SettingsBody extends StatelessWidget {
  const SettingsBody({super.key});
  static const _gemmaDownloadUrl =
      'https://drive.google.com/file/d/1LwPtoiEs0NxaIoRfv9xBVzKncfS2fmQK/view?usp=sharing';

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final c = AppColors.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── USER PROFILE ────────────────────────────────────────────────
        _SectionLabel('USER PROFILE', c),
        const SizedBox(height: 8),
        _UserNameInput(provider: provider, c: c),
        const SizedBox(height: 24),

        // ── APPEARANCE ──────────────────────────────────────────────────
        _SectionLabel('APPEARANCE', c),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.sep),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.contrast_rounded, color: c.primary, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      'Theme',
                      style: TextStyle(
                        color: c.text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Center(
                  child: _ThemeSegment(provider: provider, c: c),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // ── NOTIFICATION INTERVAL ───────────────────────────────────────
        _SectionLabel('NOTIFICATION INTERVAL', c),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.sep),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: provider.logIntervalMinutes,
              dropdownColor: c.surface,
              icon: Icon(Icons.keyboard_arrow_down_rounded, color: c.muted),
              style: TextStyle(color: c.text, fontSize: 14),
              items: [
                _item(15, 'Every 15 min  (:00, :15, :30, :45)', c),
                _item(20, 'Every 20 min  (:00, :20, :40)', c),
                _item(30, 'Every 30 min  (:00, :30)', c),
                _item(60, 'Every 60 min  (:00)', c),
              ],
              onChanged: (v) {
                if (v != null) provider.setLogInterval(v);
              },
            ),
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            'You\'ll get a notification to log your activity at each boundary. '
            'Ignoring it auto-logs "Continued: [last activity]".',
            style: TextStyle(color: c.muted, fontSize: 11, height: 1.5),
          ),
        ),

        const SizedBox(height: 24),

        // ── ARTIFICIAL INTELLIGENCE ──────────────────────────────────────
        _SectionLabel('LOCAL ARTIFICIAL INTELLIGENCE', c),
        const SizedBox(height: 8),
        _DataTile(
          icon: Icons.smart_toy_rounded,
          title: provider.isAiReady
              ? 'AI Model Loaded'
              : 'Import Local AI Model',
          sub: provider.isAiReady
              ? 'Gemma is successfully running offline'
              : 'Select a downloaded .bin weights file',
          c: c,
          onTap: () async {
            await provider.importAiModel();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: c.surface,
                  content: Text(
                    provider.isAiReady
                        ? 'AI Model loaded successfully!'
                        : 'Model import failed or cancelled.',
                    style: TextStyle(color: c.text),
                  ),
                ),
              );
            }
          },
        ),
        const SizedBox(height: 8),
        _DataTile(
          icon: Icons.download_for_offline_rounded,
          title: 'Download Gemma 3 1B Model',
          sub: 'Open/copy Google Drive link for gemma3-1B-it-int4.task',
          c: c,
          onTap: () async {
            await Clipboard.setData(
              const ClipboardData(text: _gemmaDownloadUrl),
            );
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: c.surface,
                  content: Text(
                    'Model link copied to clipboard.',
                    style: TextStyle(color: c.text),
                  ),
                  action: SnackBarAction(
                    label: 'VIEW',
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Gemma 3 1B Download URL'),
                          content: SelectableText(_gemmaDownloadUrl),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              );
            }
          },
        ),
        const SizedBox(height: 24),

        // ── CALENDAR SYNC ────────────────────────────────────────────────
        _SectionLabel('CALENDAR SYNC', c),
        const SizedBox(height: 8),
        _CalendarSyncTile(provider: provider, c: c),
        const SizedBox(height: 24),

        // ── DATA ────────────────────────────────────────────────────────
        _SectionLabel('DATA MANAGEMENT', c),
        const SizedBox(height: 8),
        _DataTile(
          icon: Icons.download_rounded,
          title: 'Export Data',
          sub: 'Save logs & tasks to JSON',
          c: c,
          onTap: () async {
            final exportedPath = await provider.exportData();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: c.surface,
                  content: Text(
                    exportedPath != null
                        ? 'Exported to: $exportedPath'
                        : 'Export cancelled or failed',
                    style: TextStyle(color: c.text),
                  ),
                ),
              );
            }
          },
        ),
        const SizedBox(height: 8),
        _DataTile(
          icon: Icons.upload_rounded,
          title: 'Import Data',
          sub: 'Merge data from another device',
          c: c,
          onTap: () async {
            await provider.importData();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: c.surface,
                  content: Text(
                    'Import completed',
                    style: TextStyle(color: c.text),
                  ),
                ),
              );
            }
          },
        ),
      ],
    );
  }

  DropdownMenuItem<int> _item(int v, String label, AppColors c) =>
      DropdownMenuItem(
        value: v,
        child: Text(label, style: TextStyle(color: c.text)),
      );
}

class _UserNameInput extends StatefulWidget {
  final AppProvider provider;
  final AppColors c;
  const _UserNameInput({required this.provider, required this.c});

  @override
  State<_UserNameInput> createState() => _UserNameInputState();
}

class _UserNameInputState extends State<_UserNameInput> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.provider.userName);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: widget.c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: widget.c.sep),
      ),
      child: TextField(
        controller: _ctrl,
        style: TextStyle(color: widget.c.text, fontSize: 14),
        onChanged: (val) {
          widget.provider.setUserName(val);
        },
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: 'Enter your name...',
          hintStyle: TextStyle(color: widget.c.muted),
          icon: Icon(Icons.person_rounded, color: widget.c.muted, size: 20),
        ),
      ),
    );
  }
}

class _ThemeSegment extends StatelessWidget {
  final AppProvider provider;
  final AppColors c;
  const _ThemeSegment({required this.provider, required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: c.surfaceMid,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _seg(context, ThemeMode.light, Icons.light_mode_rounded, 'Light'),
          _seg(
            context,
            ThemeMode.system,
            Icons.brightness_auto_rounded,
            'Auto',
          ),
          _seg(context, ThemeMode.dark, Icons.dark_mode_rounded, 'Dark'),
        ],
      ),
    );
  }

  Widget _seg(BuildContext ctx, ThemeMode mode, IconData icon, String label) {
    final selected = provider.themeMode == mode;
    return GestureDetector(
      onTap: () => provider.setThemeMode(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? c.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: selected ? Colors.white : c.muted),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: selected ? Colors.white : c.muted,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final AppColors c;
  const _SectionLabel(this.text, this.c);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      color: c.primary,
      fontSize: 11,
      fontWeight: FontWeight.bold,
      letterSpacing: 1.2,
    ),
  );
}

class _DataTile extends StatelessWidget {
  final IconData icon;
  final String title, sub;
  final AppColors c;
  final VoidCallback onTap;
  const _DataTile({
    required this.icon,
    required this.title,
    required this.sub,
    required this.c,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      tileColor: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: c.primary.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: c.primary, size: 18),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: c.text,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(sub, style: TextStyle(color: c.muted, fontSize: 12)),
      trailing: Icon(Icons.chevron_right_rounded, color: c.muted),
    );
  }
}

// ─── Calendar Sync tile ───────────────────────────────────────────────────────
class _CalendarSyncTile extends StatefulWidget {
  final AppProvider provider;
  final AppColors c;
  const _CalendarSyncTile({required this.provider, required this.c});

  @override
  State<_CalendarSyncTile> createState() => _CalendarSyncTileState();
}

class _CalendarSyncTileState extends State<_CalendarSyncTile> {
  bool _loading = false;

  Future<void> _toggle(bool enable) async {
    if (_loading) return;
    setState(() => _loading = true);

    if (enable) {
      // Request permission first
      final granted = await CalendarSyncService.instance.requestPermission();
      if (!granted) {
        setState(() => _loading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Calendar permission denied.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }

      // Any calendar we can read (import); writable ones can also mirror app → calendar.
      final calendars = await CalendarSyncService.instance.getAllCalendars();
      final usable = calendars
          .where((c) => c.id != null && c.id!.isNotEmpty)
          .toList();
      if (usable.isEmpty) {
        setState(() => _loading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No calendars found on this device.')),
          );
        }
        return;
      }

      if (!mounted) return;
      final chosen = await showDialog<Calendar>(
        context: context,
        builder: (ctx) => SimpleDialog(
          backgroundColor: widget.c.surface,
          title: Text(
            'Which calendar?',
            style: TextStyle(color: widget.c.text, fontSize: 15),
          ),
          children: usable.map((cal) {
            final ro = cal.isReadOnly == true;
            return SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, cal),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: cal.color != null
                          ? Color(cal.color!)
                          : widget.c.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cal.name ?? 'Unknown',
                          style: TextStyle(color: widget.c.text, fontSize: 13),
                        ),
                        if (ro)
                          Text(
                            'Read-only — import only',
                            style: TextStyle(
                              color: widget.c.muted,
                              fontSize: 10,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      );

      if (chosen == null || chosen.id == null) {
        setState(() => _loading = false);
        return;
      }

      final imported = await widget.provider.setCalendarSync(
        true,
        calendarId: chosen.id,
        calendarReadOnly: chosen.isReadOnly == true,
      );
      if (mounted) {
        if (imported < 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Could not enable calendar link (permission denied).',
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                imported == 0
                    ? 'Calendar linked — no new events to import (pull to refresh anytime).'
                    : 'Calendar linked — imported $imported event${imported == 1 ? '' : 's'} into Schedule.',
              ),
              backgroundColor: const Color(0xFF1D6F42),
            ),
          );
        }
      }
    } else {
      await widget.provider.setCalendarSync(false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Calendar sync disabled.')),
        );
      }
    }

    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final enabled = widget.provider.calendarSyncEnabled;
    final calId = CalendarSyncService.instance.calendarId;

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.sep),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: (enabled ? Colors.green : c.primary).withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.calendar_month_rounded,
                color: enabled ? Colors.green : c.primary,
                size: 18,
              ),
            ),
            title: Text(
              'Calendar & Schedule',
              style: TextStyle(
                color: c.text,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              enabled && calId != null
                  ? (widget.provider.calendarReadOnly
                        ? 'Phone events import into Schedule (read-only calendar)'
                        : 'Events import here; new/edited blocks also appear in your calendar')
                  : 'Import calendar events into Schedule; writable calendars stay two-way',
              style: TextStyle(color: c.muted, fontSize: 11),
            ),
            trailing: _loading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: c.primary,
                    ),
                  )
                : Switch(
                    value: enabled,
                    onChanged: _toggle,
                    activeThumbColor: Colors.green,
                  ),
          ),
          if (enabled && calId != null) ...[
            if (widget.provider.calendarReadOnly)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                child: Text(
                  'This calendar is read-only — events still import into Schedule.',
                  style: TextStyle(color: c.muted, fontSize: 11),
                ),
              ),
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _loading
                          ? null
                          : () async {
                              setState(() => _loading = true);
                              final count = await widget.provider
                                  .importTasksFromPhoneCalendar();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      count == 0
                                          ? 'No new events found to import.'
                                          : 'Imported $count event${count == 1 ? '' : 's'} into Schedule.',
                                    ),
                                  ),
                                );
                              }
                              if (mounted) setState(() => _loading = false);
                            },
                      icon: const Icon(Icons.sync_alt_rounded, size: 16),
                      label: const Text('Import again from calendar'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
