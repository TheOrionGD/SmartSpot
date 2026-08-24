import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'analytics_screen.dart';
import 'completed_screen.dart';
import 'settings_screen.dart';
import 'profile_screen.dart';
import '../widgets/geofence_binder.dart';
import '../utils/app_theme.dart';
import '../utils/app_translations.dart';
import '../utils/app_motion.dart';

/// Hosts the primary sections of the app behind a persistent morphing bottom navigation bar.
class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;
  int _previousIndex = 0;

  static const _tabs = [
    HomeScreen(),
    AnalyticsScreen(),
    CompletedScreen(),
    SettingsScreen(),
    ProfileScreen(),
  ];

  static const _items = [
    (icon: Icons.home_outlined, activeIcon: Icons.home_rounded, key: 'home'),
    (icon: Icons.insights_outlined, activeIcon: Icons.insights_rounded, key: 'analytics'),
    (icon: Icons.check_circle_outline_rounded, activeIcon: Icons.check_circle_rounded, key: 'completed'),
    (icon: Icons.settings_outlined, activeIcon: Icons.settings_rounded, key: 'settings'),
    (icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, key: 'profile'),
  ];

  void _onTabTapped(int index) {
    if (index == _currentIndex) return;
    setState(() {
      _previousIndex = _currentIndex;
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const primary = AppColors.primaryLight;
    final animate = AppMotion.shouldAnimate(context);

    // Direction calculation for page transition (rightwards vs leftwards slide)
    final isForward = _currentIndex >= _previousIndex;
    final beginOffset = isForward ? const Offset(0.025, 0) : const Offset(-0.025, 0);

    return Scaffold(
      backgroundColor: isDark ? AppColors.creamBackgroundDark : AppColors.creamBackground,
      body: GeofenceBinder(
        child: AnimatedSwitcher(
          duration: animate ? AppMotion.screen : Duration.zero,
          switchInCurve: AppMotion.screenCurve,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) {
            if (!animate) return child;
            final isEntering = child.key == ValueKey(_currentIndex);
            final slideTween = isEntering
                ? Tween<Offset>(begin: beginOffset, end: Offset.zero)
                : Tween<Offset>(begin: Offset.zero, end: isForward ? const Offset(-0.025, 0) : const Offset(0.025, 0));

            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: slideTween.animate(animation),
                child: child,
              ),
            );
          },
          child: KeyedSubtree(
            key: ValueKey(_currentIndex),
            child: _tabs[_currentIndex],
          ),
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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final itemWidth = constraints.maxWidth / _items.length;

                  return Stack(
                    children: [
                      // Smooth morphing background pill sliding behind active item
                      AnimatedPositioned(
                        duration: animate ? AppMotion.component : Duration.zero,
                        curve: AppMotion.springCurve,
                        left: _currentIndex * itemWidth + 4,
                        top: 8,
                        width: itemWidth - 8,
                        height: 50,
                        child: Container(
                          decoration: BoxDecoration(
                            color: primary.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: primary.withValues(alpha: 0.35),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: primary.withValues(alpha: 0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Navigation item buttons
                      Row(
                        children: List.generate(_items.length, (index) {
                          final item = _items[index];
                          final selected = index == _currentIndex;
                          final labelText = AppTranslations.tr(context, item.key);

                          return Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(24),
                              onTap: () => _onTabTapped(index),
                              child: Container(
                                alignment: Alignment.center,
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    AnimatedScale(
                                      scale: selected ? 1.14 : 1.0,
                                      duration: animate ? AppMotion.micro : Duration.zero,
                                      curve: AppMotion.springCurve,
                                      child: Icon(
                                        selected ? item.activeIcon : item.icon,
                                        color: selected ? primary : Colors.grey[400],
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    AnimatedDefaultTextStyle(
                                      duration: animate ? AppMotion.micro : Duration.zero,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                                        color: selected ? primary : Colors.grey[400],
                                        letterSpacing: 0.2,
                                      ),
                                      child: Text(
                                        labelText,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
