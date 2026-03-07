import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── APPEARANCE ──────────────────────────────────────────────────
          _SectionLabel('APPEARANCE', c),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.sep),
            ),
            child: Column(
              children: [
                // Light / System / Dark segmented control
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
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
                      const Spacer(),
                      _ThemeSegment(provider: provider, c: c),
                    ],
                  ),
                ),
              ],
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
              await provider.exportData();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: c.surface,
                    content: Text('Exported!', style: TextStyle(color: c.text)),
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
      ),
    );
  }

  DropdownMenuItem<int> _item(int v, String label, AppColors c) =>
      DropdownMenuItem(
        value: v,
        child: Text(label, style: TextStyle(color: c.text)),
      );
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
