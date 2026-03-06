import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'tutorial_screen.dart';
import '../main.dart'; // For GlobalPromptWrapper

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fade = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeIn));

    _anim.forward();

    // 1-second delay before navigating
    Future.delayed(const Duration(seconds: 1), () async {
      final prefs = await SharedPreferences.getInstance();
      final hasSeenTutorial = prefs.getBool('has_seen_tutorial') ?? false;

      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => hasSeenTutorial
                ? const GlobalPromptWrapper(child: HomeScreen())
                : const TutorialScreen(),
            transitionsBuilder: (_, a, __, c) =>
                FadeTransition(opacity: a, child: c),
            transitionDuration: const Duration(milliseconds: 400),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The visual styling matches the top of the Focus page.
    return Scaffold(
      backgroundColor: AppColors.of(context).bg,
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/images/logo.png', width: 120, height: 120),
              const SizedBox(height: 20),
              // "WhereDidMyTimeGo?" styled like Focus page top text
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'WhereDid',
                      style: TextStyle(
                        color: AppColors.of(context).text,
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                        letterSpacing: -0.5,
                      ),
                    ),
                    TextSpan(
                      text: 'My',
                      style: TextStyle(
                        color: AppColors.of(context).primary,
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                        letterSpacing: -0.5,
                      ),
                    ),
                    TextSpan(
                      text: 'TimeGo?',
                      style: TextStyle(
                        color: AppColors.of(context).text,
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
