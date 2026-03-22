import 'dart:ui';
import 'dart:isolate';
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
  // MUST initialize these FIRST in the background isolate
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  try {
    final text = NotificationService.extractReply(response);
    if (text != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload(); // Ensure we have latest data
      await prefs.setString('pending_log_reply', text);

      int timeMs = DateTime.now().millisecondsSinceE poch;
      if (response.payload != null) {
        timeMs = int.tryParse(response.payload!) ?? timeMs;
      }

      await prefs.setInt('pending_log_time', timeMs);

      // Signal the main isolate to refresh if the app is foreground
      final port = IsolateNameServer.lookupPortByName('wdmtg_notif_port');
      port?.send(true);
    }
  } catch (e) {
    debugPrint("Background handler error: $e");
  } finally {
    try {
      // Create a localized plugin instance just for cancelling
      final plugin = FlutterLocalNotificationsPlugin();
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/launcher_icon',
      );
      const initSettings = InitializationSettings(android: androidSettings);
      await plugin.initialize(settings: initSettings);
      // On some Android versions, small delay helps ensure OS captures the cancellation
      await plugin.cancel(id: 1);
    } catch (_) {}
  }
}

AppProvider? _providerRef; // weak singleton ref for foreground handler

Future<void> _onForegroundNotificationResponse(NotificationResponse response) async {
  final text = NotificationService.extractReply(response);
  if (text == null) return;

  DateTime time = DateTime.now();
  if (response.payload != null) {
    final parsed = int.tryParse(response.payload!);
    if (parsed != null) {
      time = DateTime.fromMillisecondsSinceEpoch(parsed);
    }
  }

  // Persist first so both foreground and background follow one reliable path.
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('pending_log_reply', text);
  await prefs.setInt('pending_log_time', time.millisecondsSinceEpoch);

  if (_providerRef == null) return;

  // Dismiss in-app prompt immediately if user replied from notification shade.
  _providerRef!.clearPrompt();
  await _providerRef!.checkPendingNotifications();
  await NotificationService.instance.cancelLogNotification();
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

  final port = ReceivePort();
  // Clean up any old mapping from Hot Restarts to prevent "already registered" errors
  IsolateNameServer.removePortNameMapping('wdmtg_notif_port');
  IsolateNameServer.registerPortWithName(port.sendPort, 'wdmtg_notif_port');
  port.listen((_) {
    _providerRef?.checkPendingNotifications();
  });
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

  bool _isShowingDialog = false;

  void _onProviderChange() {
    final provider = Provider.of<AppProvider>(context, listen: false);
    if (provider.isPromptOwed && mounted && !_isShowingDialog) {
      _showLogPromptDialog(context, provider);
    } else if (!provider.isPromptOwed && _isShowingDialog) {
      // If the notification was answered externally, dismiss the dialog
      _isShowingDialog = false;
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  void _showLogPromptDialog(BuildContext context, AppProvider provider) {
    // Keep the system notification active while showing the in-app prompt.
    // This allows replying from the notification panel and preserves notification sound behavior.

    _isShowingDialog = true;
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
                // No Navigator.pop here; _onProviderChange handles it
              },
              child: Text(
                'Sleeping',
                style: TextStyle(color: colors.muted, fontSize: 13),
              ),
            ),
            TextButton(
              onPressed: () async {
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
                await provider.addLog(
                  LogEntry(
                    id: logTime.millisecondsSinceEpoch.toString(),
                    timestamp: logTime,
                    text: 'Continued: $lastText',
                  ),
                );
                if (ctx.mounted && Navigator.of(ctx).canPop()) {
                  Navigator.of(ctx).pop();
                }
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
              onPressed: () async {
                await provider.addLog(
                  LogEntry(
                    id: logTime.millisecondsSinceEpoch.toString(),
                    timestamp: logTime,
                    text: textController.text.isNotEmpty
                        ? textController.text
                        : 'No details provided',
                  ),
                );
                if (ctx.mounted && Navigator.of(ctx).canPop()) {
                  Navigator.of(ctx).pop();
                }
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    ).then((_) {
      _isShowingDialog = false;
      // If it's still owed (e.g. user dismissed dialog by tapping outside - though dismissed here by false),
      // we might want to clear it? But barrierDismissible is false, so this shouldn't happen
      // except for system back button which might still work.
      if (provider.isPromptOwed) {
        provider.clearPrompt();
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
