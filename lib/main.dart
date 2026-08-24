import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/reminder_provider.dart';
import 'providers/favorites_provider.dart';
import 'providers/settings_provider.dart';
import 'services/notification_service.dart';
import 'screens/splash_screen.dart';
import 'utils/app_theme.dart';

import 'providers/auth_provider.dart';
import 'providers/live_location_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Production Global Error Handlers
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('SmartSpot FlutterError: ${details.exception}');
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('SmartSpot PlatformError: $error\n$stack');
    return true;
  };

  await NotificationService.instance.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(),
        ),
        ChangeNotifierProvider<ReminderProvider>(
          create: (_) => ReminderProvider(),
        ),
        ChangeNotifierProvider<FavoritesProvider>(
          create: (_) => FavoritesProvider(),
        ),
        ChangeNotifierProvider<SettingsProvider>(
          create: (_) => SettingsProvider(),
        ),
        ChangeNotifierProvider<LiveLocationProvider>(
          create: (_) => LiveLocationProvider(),
        ),
      ],
      child: const _AppRoot(),
    );
  }

  /// SmartSpot's soft pastel/friendly theme. Generous rounding (buttons are
  /// full pills, cards/sheets/inputs are 20-28px), warm cream canvas, and
  /// Baloo 2 + Nunito typography instead of a default Material sans.
  static ThemeData _buildLightTheme() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
        primary: AppColors.primary,
        secondary: AppColors.sage,
        tertiary: AppColors.periwinkle,
        error: AppColors.error,
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: AppColors.creamBackground,
      textTheme: AppTypography.textTheme(Brightness.light),
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: AppColors.creamBackground,
        foregroundColor: const Color(0xFF10131C),
        titleTextStyle: AppTypography.display(
          fontSize: 19,
          weight: FontWeight.w700,
          color: const Color(0xFF10131C),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF10131C)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: AppTypography.body(fontSize: 14, weight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryDark,
          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4), width: 1.4),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: AppTypography.body(fontSize: 13, weight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryDark,
          textStyle: AppTypography.body(fontSize: 13, weight: FontWeight.w700),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        color: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.primary.withValues(alpha: 0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        hintStyle: AppTypography.body(fontSize: 14, color: Colors.grey[400]),
      ),
      iconTheme: const IconThemeData(color: Color(0xFF10131C), size: 24),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.primary.withValues(alpha: 0.08),
        disabledColor: Colors.grey[200],
        selectedColor: AppColors.primary,
        labelStyle: AppTypography.body(fontSize: 12, weight: FontWeight.w700, color: const Color(0xFF10131C)),
        secondaryLabelStyle: AppTypography.body(fontSize: 12, weight: FontWeight.w700, color: Colors.white),
        brightness: Brightness.light,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        shape: StadiumBorder(
          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.25)),
        ),
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.primary
              : Colors.grey[300],
        ),
        thumbColor: const WidgetStatePropertyAll(Colors.white),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.primary,
        thumbColor: AppColors.primary,
        overlayColor: AppColors.primary.withValues(alpha: 0.15),
        inactiveTrackColor: AppColors.primary.withValues(alpha: 0.15),
      ),
      dividerTheme: DividerThemeData(color: AppColors.primary.withValues(alpha: 0.1), thickness: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF10131C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentTextStyle: AppTypography.body(fontSize: 13, color: Colors.white),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.primary),
    );
  }

  static ThemeData _buildDarkTheme() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.dark,
        primary: AppColors.primaryLight,
        secondary: AppColors.sage,
        tertiary: AppColors.periwinkle,
        error: AppColors.error,
        surface: AppColors.surfaceDark,
      ),
      scaffoldBackgroundColor: AppColors.creamBackgroundDark,
      textTheme: AppTypography.textTheme(Brightness.dark),
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: AppColors.creamBackgroundDark,
        foregroundColor: Colors.white,
        titleTextStyle: AppTypography.display(fontSize: 19, weight: FontWeight.w700, color: Colors.white),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primaryLight,
        foregroundColor: const Color(0xFF10131C),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: AppTypography.body(fontSize: 14, weight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryLight,
          side: BorderSide(color: AppColors.primaryLight.withValues(alpha: 0.5), width: 1.4),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: AppTypography.body(fontSize: 13, weight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryLight,
          textStyle: AppTypography.body(fontSize: 13, weight: FontWeight.w700),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        color: AppColors.surfaceDark,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: AppColors.primaryLight, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        hintStyle: AppTypography.body(fontSize: 14, color: Colors.grey[500]),
      ),
      iconTheme: const IconThemeData(color: Colors.white, size: 24),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.primary.withValues(alpha: 0.2),
        disabledColor: Colors.grey[800],
        selectedColor: AppColors.primary,
        labelStyle: AppTypography.body(fontSize: 12, weight: FontWeight.w700, color: Colors.white),
        secondaryLabelStyle: AppTypography.body(fontSize: 12, weight: FontWeight.w700, color: Colors.white),
        brightness: Brightness.dark,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        shape: StadiumBorder(
          side: BorderSide(color: AppColors.primaryLight.withValues(alpha: 0.4)),
        ),
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.primaryLight
              : Colors.grey[700],
        ),
        thumbColor: const WidgetStatePropertyAll(Colors.white),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.primaryLight,
        thumbColor: AppColors.primaryLight,
        overlayColor: AppColors.primaryLight.withValues(alpha: 0.15),
        inactiveTrackColor: AppColors.primaryLight.withValues(alpha: 0.15),
      ),
      dividerTheme: DividerThemeData(color: Colors.white.withValues(alpha: 0.08), thickness: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentTextStyle: AppTypography.body(fontSize: 13, color: Colors.white),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.primaryLight),
    );
  }
}

/// Sits just below [MultiProvider] so it can read [SettingsProvider] for
/// the live theme mode (light/dark/system), which changes immediately as
/// soon as the person picks a different option in Settings.
class _AppRoot extends StatelessWidget {
  const _AppRoot();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return MaterialApp(
      title: 'SmartSpot',
      theme: MyApp._buildLightTheme(),
      darkTheme: MyApp._buildDarkTheme(),
      themeMode: settings.themeMode,
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
