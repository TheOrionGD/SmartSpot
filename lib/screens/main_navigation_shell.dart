import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'analytics_screen.dart';
import 'completed_screen.dart';
import 'settings_screen.dart';
import 'profile_screen.dart';
import '../widgets/geofence_binder.dart';
import '../utils/app_theme.dart';

/// Hosts the four primary sections of the app behind a persistent bottom
/// navigation bar. Each tab keeps its own state via [IndexedStack] so
/// switching tabs doesn't reset scroll position or reload data.
class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;

  static const _tabs = [
    HomeScreen(),
    AnalyticsScreen(),
    CompletedScreen(),
    SettingsScreen(),
    ProfileScreen(),
  ];

  static const _items = [
    (icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home'),
    (icon: Icons.insights_outlined, activeIcon: Icons.insights_rounded, label: 'Analytics'),
    (icon: Icons.check_circle_outline_rounded, activeIcon: Icons.check_circle_rounded, label: 'Completed'),
    (icon: Icons.settings_outlined, activeIcon: Icons.settings_rounded, label: 'Settings'),
    (icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // The nav bar itself is always a solid dark navy floating pill —
    // a deliberate banking-app signature — regardless of the app's
    // light/dark theme mode, so the selected accent always pops.
    const primary = AppColors.primaryLight;

    return Scaffold(
      backgroundColor: isDark ? AppColors.creamBackgroundDark : AppColors.creamBackground,
      body: GeofenceBinder(
        child: IndexedStack(
          index: _currentIndex,
          children: _tabs,
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.creamBackgroundDark,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: SizedBox(
              height: 66,
              child: Row(
                children: List.generate(_items.length, (index) {
                  final item = _items[index];
                  final selected = index == _currentIndex;
                  return Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () => setState(() => _currentIndex = index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                        decoration: BoxDecoration(
                          color: selected ? primary.withValues(alpha: 0.16) : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              selected ? item.activeIcon : item.icon,
                              color: selected ? primary : Colors.grey[400],
                              size: 23,
                            ),
                            const SizedBox(height: 3),
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                                color: selected ? primary : Colors.grey[400],
                                letterSpacing: 0.2,
                              ),
                              child: Text(item.label),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
