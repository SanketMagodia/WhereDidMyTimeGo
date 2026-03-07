import 'dart:ui'; // For DartPluginRegistrant
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/app_provider.dart';
import 'theme/app_theme.dart';
import 'models/log_entry_model.dart';
import 'services/notification_service.dart';
import 'screens/splash_screen.dart';

@pragma('vm:entry-point')
void _backgroundNotificationHandler(NotificationResponse response) async {
  try {
    final text = NotificationService.extractReply(response);
    if (text != null) {
      WidgetsFlutterBinding.ensureInitialized();
      DartPluginRegistrant.ensureInitialized();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pending_log_reply', text);

      int timeMs = DateTime.now().millisecondsSinceEpoch;
      if (response.payload != null) {
        timeMs = int.tryParse(response.payload!) ?? timeMs;
      }

      await prefs.setInt('pending_log_time', timeMs);
    }
  } catch (e) {
    debugPrint("Background handler error: $e");
  } finally {
    try {
      // MUST cancel the notification ID here so Android clears the UI loading spinner
      FlutterLocalNotificationsPlugin().cancel(id: 1);
    } catch (_) {}
  }
}

AppProvider? _providerRef; // weak singleton ref for foreground handler

void _onForegroundNotificationResponse(NotificationResponse response) {
  final text = NotificationService.extractReply(response);
  if (text != null && _providerRef != null) {
    DateTime time = DateTime.now();
    if (response.payload != null) {
      final parsed = int.tryParse(response.payload!);
      if (parsed != null) {
        time = DateTime.fromMillisecondsSinceEpoch(parsed);
      }
    }
    _providerRef!.handleNotificationReply(text, time);
    // Explicitly cancel the notification to clear the inline reply spinner
    FlutterLocalNotificationsPlugin().cancel(id: 1);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    debugPrint("Initializing FlutterGemma...");
    await FlutterGemma.initialize();
    debugPrint("FlutterGemma initialized successfully.");
  } catch (e, stack) {
    debugPrint("CRITICAL ERROR initializing FlutterGemma: $e\n$stack");
  }

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
      child: const WDMTGApp(),
    ),
  );
}

class WDMTGApp extends StatelessWidget {
  const WDMTGApp({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'WDMTG',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: provider.themeMode,
      home: const SplashScreen(),
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

    // Use the exact prompt time from the provider rather than DateTime.now() if answering the prompt
    final logTime = provider.notificationShownAt ?? DateTime.now();

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
                String lastText = 'Continued previous task';
                for (var i = provider.logs.length - 1; i >= 0; i--) {
                  if (!provider.logs[i].isSleep) {
                    lastText = provider.logs[i].text.split(' • ').last;
                    if (lastText.startsWith('Continued: ')) {
                      lastText = lastText.substring(11).trim();
                    }
                    break;
                  }
                }
                provider.addLog(
                  LogEntry(
                    id: logTime.millisecondsSinceEpoch.toString(),
                    timestamp: logTime,
                    text: 'Continued: $lastText',
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
                    id: logTime.millisecondsSinceEpoch.toString(),
                    timestamp: logTime,
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
