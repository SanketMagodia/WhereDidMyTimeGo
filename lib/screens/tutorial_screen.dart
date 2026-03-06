import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import '../main.dart';

class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _pages = [
    {
      'icon': Icons.settings_suggest_rounded,
      'color': AppTheme.accentGold,
      'title': 'Setup Your Preferences',
      'body':
          'Go to settings inside the app to set your time log interval, customize notifications, and choose your favorite app theme.',
    },
    {
      'icon': Icons.calendar_month_rounded,
      'color': AppTheme.accentPrimary,
      'title': 'Schedule Your Day',
      'body':
          'Click on the Tasks icon and simply tap the grid to schedule an activity for today. Keep track of what matters.',
    },
    {
      'icon': Icons.analytics_rounded,
      'color': const Color(0xFFF05A7E),
      'title': 'Track Your Reality',
      'body':
          'On the Home screen, you will dynamically see what you scheduled versus what you were actually doing.',
    },
    {
      'icon': Icons.lock_person_rounded,
      'color': const Color(0xFF0EA5E9),
      'title': '100% Offline & Secure',
      'body':
          'Everything is offline! Your data is safe with you. You can export your data anytime and import it on a new device to continue your progress.',
    },
  ];

  Future<void> _finishTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_tutorial', true);

    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) =>
              const GlobalPromptWrapper(child: HomeScreen()),
          transitionsBuilder: (_, a, __, c) =>
              FadeTransition(opacity: a, child: c),
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    }
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finishTutorial();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (idx) => setState(() => _currentPage = idx),
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.all(40.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: (page['color'] as Color).withValues(
                              alpha: 0.1,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            page['icon'] as IconData,
                            size: 100,
                            color: page['color'] as Color,
                          ),
                        ),
                        const SizedBox(height: 60),
                        Text(
                          page['title'] as String,
                          style: TextStyle(
                            color: c.text,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          page['body'] as String,
                          style: TextStyle(
                            color: c.muted,
                            fontSize: 16,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(30.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: List.generate(
                      _pages.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(right: 8),
                        height: 8,
                        width: _currentPage == i ? 24 : 8,
                        decoration: BoxDecoration(
                          color: _currentPage == i ? c.primary : c.surfaceMid,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _nextPage,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: _currentPage == _pages.length - 1
                            ? c.primary
                            : c.surface,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          if (_currentPage == _pages.length - 1)
                            BoxShadow(
                              color: c.primary.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                        ],
                      ),
                      child: Text(
                        _currentPage == _pages.length - 1
                            ? 'Get Started'
                            : 'Next',
                        style: TextStyle(
                          color: _currentPage == _pages.length - 1
                              ? Colors.white
                              : c.text,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
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
