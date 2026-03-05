import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/app_provider.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'models/log_entry_model.dart';
import 'services/notification_service.dart';

// ─── Background notification handler ─────────────────────────────────────────
// Must be a top-level function (not a class method) to run in background isolate.
// Saves reply to SharedPreferences; main isolate picks it up on resume.
@pragma('vm:entry-point')
void _backgroundNotificationHandler(NotificationResponse response) async {
  final text = NotificationService.extractReply(response);
  if (text != null) {
    // We can't access the provider from a background isolate.
    // Store in SharedPreferences; main isolate reads on next _init().
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pending_log_reply', text);
    await prefs.setInt(
      'pending_log_time',
      DateTime.now().millisecondsSinceEpoch,
    );
  }
}

AppProvider? _providerRef; // weak singleton ref for foreground handler

void _onForegroundNotificationResponse(NotificationResponse response) {
  final text = NotificationService.extractReply(response);
  if (text != null && _providerRef != null) {
    _providerRef!.handleNotificationReply(text, DateTime.now());
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.init(
    onResponse: _onForegroundNotificationResponse,
    onBackgroundResponse: _backgroundNotificationHandler,
  );
  runApp(
    ChangeNotifierProvider(
      create: (_) {
        final p = AppProvider();
        _providerRef = p;
        return p;
      },
      child: const TimelogApp(),
    ),
  );
}

class TimelogApp extends StatelessWidget {
  const TimelogApp({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    return MaterialApp(
      title: 'WDMTG',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: provider.themeMode,
      home: const GlobalPromptWrapper(child: HomeScreen()),
      debugShowCheckedModeBanner: false,
    );
  }
}

class GlobalPromptWrapper extends StatefulWidget {
  final Widget child;
  const GlobalPromptWrapper({super.key, required this.child});

  @override
  State<GlobalPromptWrapper> createState() => _GlobalPromptWrapperState();
}

class _GlobalPromptWrapperState extends State<GlobalPromptWrapper> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<AppProvider>(context, listen: false);
      _providerRef = provider;
      provider.addListener(_onProviderChange);
    });
  }

  void _onProviderChange() {
    final provider = Provider.of<AppProvider>(context, listen: false);
    if (provider.isPromptOwed && mounted) {
      _showLogPromptDialog(context, provider);
    }
  }

  void _showLogPromptDialog(BuildContext context, AppProvider provider) {
    provider.clearPrompt();
    final textController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        // Read colors from dialog context so light/dark theme propagates correctly
        final colors = AppColors.of(ctx);
        return AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.access_time_rounded, color: colors.primary, size: 22),
              const SizedBox(width: 8),
              Text(
                'Time check!',
                style: TextStyle(
                  color: colors.text,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'What have you been up to?',
                style: TextStyle(color: colors.muted, fontSize: 13),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: textController,
                style: TextStyle(color: colors.text),
                decoration: InputDecoration(
                  hintText: 'Describe your activity…',
                  hintStyle: TextStyle(color: colors.muted),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: colors.primary, width: 2),
                  ),
                  filled: true,
                  fillColor: colors.surfaceMid,
                ),
                autofocus: false,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                provider.toggleAwakeStatus(false);
                Navigator.of(ctx).pop();
              },
              child: Text(
                'Sleeping',
                style: TextStyle(color: colors.muted, fontSize: 13),
              ),
            ),
            TextButton(
              onPressed: () {
                final lastText = provider.logs.isNotEmpty
                    ? provider.logs.last.text
                    : 'Continued previous task';
                provider.addLog(
                  LogEntry(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    timestamp: DateTime.now(),
                    text: lastText,
                  ),
                );
                Navigator.of(ctx).pop();
              },
              child: Text(
                'Same as before',
                style: TextStyle(color: colors.secondary, fontSize: 13),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                provider.addLog(
                  LogEntry(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    timestamp: DateTime.now(),
                    text: textController.text.isNotEmpty
                        ? textController.text
                        : 'No details provided',
                  ),
                );
                Navigator.of(ctx).pop();
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
