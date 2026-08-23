import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// SmartSpot's design language — v2: a modern "digital banking app" look.
/// Deep navy canvas with an electric indigo + neon mint accent system,
/// flat minimal cards (no more peeled "sticky note" corners), and
/// geometric Manrope/Inter typography instead of the previous rounded
/// Baloo 2 + Nunito pairing.
///
/// Every screen/widget should pull colors from here instead of hardcoding
/// Material colors or hex literals, so the whole app stays visually
/// consistent and re-themeable from one place.
class AppColors {
  AppColors._();

  // --- Brand: Electric Indigo ---------------------------------------------
  static const Color primary = Color(0xFF5B5FEF); // Electric Indigo
  static const Color primaryLight = Color(0xFF8B8FF5); // Soft Violet
  static const Color primaryDark = Color(0xFF3E41B3);
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryDark],
  );

  // --- Secondary: Neon Mint (the "balance card" accent) -------------------
  static const Color sage = Color(0xFF00D9A3); // Neon Mint (kept as `sage`
  // for drop-in compatibility with existing screens/widgets)
  static const Color sageLight = Color(0xFF6FF0C9);

  // --- Tertiary: Sky Cyan ---------------------------------------------------
  static const Color periwinkle = Color(0xFF4FD1E8); // kept as `periwinkle`
  // for drop-in compatibility
  static const Color periwinkleLight = Color(0xFFA6EAF5);

  // --- Canvas -------------------------------------------------------------
  static const Color creamBackground = Color(0xFFF5F6FA); // clean fintech off-white
  static const Color creamBackgroundDark = Color(0xFF0B0E17); // deep navy-black
  static const Color surfaceDark = Color(0xFF141A2A); // card surface, dark mode

  // --- Status / semantic ---------------------------------------------------
  static const Color success = Color(0xFF00D9A3); // neon mint
  static const Color warning = Color(0xFFFFB020); // amber
  static const Color error = Color(0xFFFF5A66); // coral-red
  static const Color info = Color(0xFF4FD1E8); // sky cyan
  static const Color infoAlt = Color(0xFF5B5FEF);

  // --- Category colors (analytics, reminder details, filters) ------------
  static const Map<String, Color> category = {
    'shopping': Color(0xFF4FD1E8), // cyan
    'home': sage,
    'office': periwinkle,
    'college': Color(0xFFE8639B), // magenta-pink
    'health': error,
    'travel': Color(0xFF00B4D8), // deep teal
  };

  static Color categoryColor(String name) => category[name] ?? primary;

  static LinearGradient softGradient(Color c) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [c, c.withValues(alpha: 0.7)],
      );

  static List<BoxShadow> cardShadow(Color c, {double alpha = 0.12}) => [
        BoxShadow(
          color: c.withValues(alpha: alpha),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ];
}

/// Typography: Manrope for display (geometric, confident, fintech-standard)
/// paired with Inter for body copy (clean, highly legible at small sizes).
/// Requires the `google_fonts` package — already a project dependency.
class AppTypography {
  AppTypography._();

  static TextStyle display({
    double fontSize = 28,
    FontWeight weight = FontWeight.w700,
    Color? color,
    double letterSpacing = -0.2,
  }) =>
      GoogleFonts.manrope(
        fontSize: fontSize,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
      );

  static TextStyle body({
    double fontSize = 14,
    FontWeight weight = FontWeight.w500,
    Color? color,
    double letterSpacing = 0,
  }) =>
      GoogleFonts.inter(
        fontSize: fontSize,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
      );

  static TextTheme textTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final headline = isDark ? Colors.white : const Color(0xFF10131C);
    final bodyColor = isDark ? Colors.grey[400] : const Color(0xFF5B6072);

    return TextTheme(
      displayLarge: display(fontSize: 34, color: headline),
      displayMedium: display(fontSize: 28, color: headline),
      headlineSmall: display(fontSize: 20, weight: FontWeight.w600, color: headline),
      titleMedium: body(fontSize: 16, weight: FontWeight.w700, color: headline),
      bodyMedium: body(fontSize: 14, color: bodyColor),
      bodySmall: body(fontSize: 12, color: bodyColor),
      labelMedium: body(fontSize: 12, weight: FontWeight.w700, color: bodyColor, letterSpacing: 0.3),
    );
  }
}

/// Reusable card decoration — the app's new signature shape: a flat,
/// minimal, uniformly-rounded card with a subtle tinted border. Replaces
/// the old "sticky note" (asymmetric peeled-corner) decoration with the
/// clean, flat-design look common to modern banking apps.
BoxDecoration stickyNoteDecoration({
  required Color tint,
  bool isDark = false,
  double alpha = 0.14,
}) {
  return BoxDecoration(
    color: isDark ? tint.withValues(alpha: 0.14) : tint.withValues(alpha: alpha),
    borderRadius: const BorderRadius.all(Radius.circular(18)),
    border: Border.all(color: tint.withValues(alpha: isDark ? 0.32 : 0.20), width: 1),
  );
}

/// "Balance card" style decoration — a solid gradient block with soft glow,
/// used for hero/summary cards (home screen header, stat highlights) to
/// mirror the big gradient balance-card pattern from modern banking UI.
BoxDecoration heroCardDecoration({
  Gradient? gradient,
  double radius = 24,
}) {
  final g = gradient ?? AppColors.primaryGradient;
  final Color glow = (g is LinearGradient && g.colors.isNotEmpty) ? g.colors.first : AppColors.primary;
  return BoxDecoration(
    gradient: g,
    borderRadius: BorderRadius.circular(radius),
    boxShadow: [
      BoxShadow(
        color: glow.withValues(alpha: 0.35),
        blurRadius: 24,
        offset: const Offset(0, 10),
      ),
    ],
  );
}

/// Legacy static theme kept for backwards compatibility with any code
/// still referencing `AppTheme.lightTheme` directly. The app actually
/// builds its live light/dark themes in `main.dart`, which is the
/// canonical source of truth for ThemeData.
class AppTheme {
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      secondary: AppColors.sage,
    ),
    scaffoldBackgroundColor: AppColors.creamBackground,
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      backgroundColor: AppColors.creamBackground,
      foregroundColor: Color(0xFF10131C),
      elevation: 0,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
    ),
  );
}
