import 'package:flutter/material.dart';
import '../theme/app_theme.dart'; // AppColors
import 'focus_view_screen.dart';
import 'daily_trail_screen.dart';
import 'settings_screen.dart';
import 'todos_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  // IndexedStack keeps all screens alive — prevents ANR on tab switch
  static const _screens = [
    FocusViewScreen(),
    DailyTrailScreen(),
    TodosScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        backgroundColor: AppColors.of(context).surface,
        selectedItemColor: AppColors.of(context).primary,
        unselectedItemColor: AppColors.of(context).muted,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_rounded),
            label: 'Tasks',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.sticky_note_2_rounded),
            label: 'Notes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
