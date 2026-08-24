import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';
import 'login_screen.dart';
import 'main_navigation_shell.dart';
import 'onboarding_screen.dart';
import '../utils/app_theme.dart';
import '../utils/app_motion.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.7, curve: Curves.easeOut)),
    );
    _scaleAnimation = Tween<double>(begin: 0.96, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _controller.forward();
    _checkAuthStateAndNavigate();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkAuthStateAndNavigate() async {
    final startTime = DateTime.now();

    bool hasToken = false;
    try {
      final token = await AuthService.instance.getToken();
      if (token != null && token.isNotEmpty) {
        hasToken = true;
      }
    } catch (_) {
      hasToken = false;
    }

    final elapsed = DateTime.now().difference(startTime);
    final minDisplay = const Duration(milliseconds: 1800);
    if (elapsed < minDisplay) {
      await Future.delayed(minDisplay - elapsed);
    }

    if (!mounted) return;

    if (hasToken) {
      Navigator.pushReplacement(
        context,
        AppPageRoute(child: const MainNavigationShell()),
      );
    } else {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      final onboardingDone = prefs.getBool('onboarding_completed') ?? false;

      if (onboardingDone) {
        Navigator.pushReplacement(
          context,
          AppPageRoute(child: const LoginScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          AppPageRoute(child: const OnboardingScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamBackgroundDark,
      body: Stack(
        children: [
          // Background fade-in from deep dark to dark SmartSpot gradient
          FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
            ),
          ),
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 28,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.location_on_rounded,
                          size: 58,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'SmartSpot',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Location Based Reminder',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
