import 'package:flutter/material.dart';

/// Professional Theme System for TaskFlow Pro
/// A modern, clean design language for professional productivity
class AppTheme {
  // Private constructor to prevent instantiation
  AppTheme._();

  // ==================== Professional Color Palette ====================
  
  /// Primary colors - Modern Blue
  static const Color primary = Color(0xFF2563EB);      // Professional Blue
  static const Color primaryLight = Color(0xFF3B82F6);
  static const Color primaryDark = Color(0xFF1E40AF);
  
  /// Secondary colors - Accent
  static const Color secondary = Color(0xFF7C3AED);    // Purple accent
  static const Color secondaryLight = Color(0xFF8B5CF6);
  static const Color secondaryDark = Color(0xFF6D28D9);
  
  /// Neutral colors
  static const Color surfaceLight = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFE2E8F0);  // Darker for better input field visibility
  static const Color surfaceDark = Color(0xFF1E293B);
  
  /// Background colors
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color background = Color(0xFFFFFFFF);
  static const Color backgroundDark = Color(0xFF0F172A);
  
  /// Text colors
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF475569);  // Darker for better contrast (WCAG AA)
  static const Color textTertiary = Color(0xFF64748B);   // Using old secondary for better visibility
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color textDisabled = Color(0xFF94A3B8);   // For disabled states
  
  /// Border colors
  static const Color borderLight = Color(0xFFCBD5E1);   // More visible borders
  static const Color borderMedium = Color(0xFF94A3B8);  // Even stronger for emphasis
  
  /// Status colors
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);
  
  /// Prayer-specific colors (subtle, professional)
  static const Color fajrColor = Color(0xFF6366F1);     // Indigo
  static const Color sunriseColor = Color(0xFFF59E0B);  // Amber
  static const Color dhuhrColor = Color(0xFF3B82F6);    // Blue
  static const Color asrColor = Color(0xFF8B5CF6);      // Purple
  static const Color maghribColor = Color(0xFFEC4899);  // Pink
  static const Color ishaColor = Color(0xFF6366F1);     // Indigo
  
  // ==================== Spacing ====================
  
  /// Consistent spacing values following 8pt grid system
  static const double space4 = 4.0;
  static const double space6 = 6.0;
  static const double space8 = 8.0;
  static const double space12 = 12.0;
  static const double space16 = 16.0;
  static const double space20 = 20.0;
  static const double space24 = 24.0;
  static const double space32 = 32.0;
  static const double space48 = 48.0;
  static const double space64 = 64.0;
  
  // ==================== Border Radius ====================
  
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusXLarge = 24.0;
  static const double radiusCircular = 999.0;
  
  // ==================== Elevation & Shadows ====================
  
  static List<BoxShadow> shadowSmall = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.05),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
  ];
  
  static List<BoxShadow> shadowMedium = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.1),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ];
  
  static List<BoxShadow> shadowLarge = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.1),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];
  
  // ==================== Text Styles ====================
  
  static const TextStyle displayLarge = TextStyle(
    fontSize: 57,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.25,
    height: 1.12,
  );
  
  static const TextStyle displayMedium = TextStyle(
    fontSize: 45,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.16,
  );
  
  static const TextStyle displaySmall = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.22,
  );
  
  static const TextStyle headlineLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
    height: 1.25,
  );
  
  static const TextStyle headlineMedium = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
    height: 1.29,
  );
  
  static const TextStyle headlineSmall = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
    height: 1.33,
  );
  
  static const TextStyle titleLarge = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
    height: 1.27,
  );
  
  static const TextStyle titleMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    height: 1.50,
  );
  
  static const TextStyle titleSmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
    height: 1.43,
  );
  
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.50,
  );
  
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.43,
  );
  
  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.33,
  );
  
  static const TextStyle labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    height: 1.43,
  );
  
  static const TextStyle labelMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    height: 1.33,
  );
  
  static const TextStyle labelSmall = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    height: 1.45,
  );
  
  // ==================== Component Styles ====================
  
  /// Card decoration with subtle shadow
  static BoxDecoration cardDecoration({
    Color? color,
    double? radius,
    List<BoxShadow>? boxShadow,
  }) {
    return BoxDecoration(
      color: color ?? surface,
      borderRadius: BorderRadius.circular(radius ?? radiusMedium),
      boxShadow: boxShadow ?? shadowMedium,
    );
  }
  
  /// Primary button style
  static ButtonStyle primaryButtonStyle({
    EdgeInsets? padding,
    double? radius,
  }) {
    return ElevatedButton.styleFrom(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      elevation: 0,
      padding: padding ?? const EdgeInsets.symmetric(
        horizontal: space24,
        vertical: space12,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius ?? radiusSmall),
      ),
    );
  }
  
  /// Secondary button style
  static ButtonStyle secondaryButtonStyle({
    EdgeInsets? padding,
    double? radius,
  }) {
    return ElevatedButton.styleFrom(
      backgroundColor: surface,
      foregroundColor: primary,
      elevation: 0,
      side: const BorderSide(color: borderLight, width: 1),
      padding: padding ?? const EdgeInsets.symmetric(
        horizontal: space24,
        vertical: space12,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius ?? radiusSmall),
      ),
    );
  }
  
  /// Text button style
  static ButtonStyle textButtonStyle() {
    return TextButton.styleFrom(
      foregroundColor: primary,
      padding: const EdgeInsets.symmetric(
        horizontal: space16,
        vertical: space8,
      ),
    );
  }
  
  // ==================== Animations ====================
  
  static const Duration animationFast = Duration(milliseconds: 200);
  static const Duration animationMedium = Duration(milliseconds: 300);
  static const Duration animationSlow = Duration(milliseconds: 500);
  
  static const Curve animationCurve = Curves.easeInOutCubic;
  
  // ==================== Theme Data ====================
  
  /// Light theme
  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
        primary: primary,
        secondary: secondary,
        surface: surface,
        background: background,
        error: error,
      ),
      scaffoldBackgroundColor: backgroundLight,
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: surface,
        foregroundColor: textPrimary,
        titleTextStyle: headlineSmall.copyWith(color: textPrimary),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          side: const BorderSide(color: borderLight, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: primaryButtonStyle(),
      ),
      textTheme: TextTheme(
        displayLarge: displayLarge.copyWith(color: textPrimary),
        displayMedium: displayMedium.copyWith(color: textPrimary),
        displaySmall: displaySmall.copyWith(color: textPrimary),
        headlineLarge: headlineLarge.copyWith(color: textPrimary),
        headlineMedium: headlineMedium.copyWith(color: textPrimary),
        headlineSmall: headlineSmall.copyWith(color: textPrimary),
        titleLarge: titleLarge.copyWith(color: textPrimary),
        titleMedium: titleMedium.copyWith(color: textPrimary),
        titleSmall: titleSmall.copyWith(color: textPrimary),
        bodyLarge: bodyLarge.copyWith(color: textPrimary),
        bodyMedium: bodyMedium.copyWith(color: textPrimary),
        bodySmall: bodySmall.copyWith(color: textSecondary),
        labelLarge: labelLarge.copyWith(color: textPrimary),
        labelMedium: labelMedium.copyWith(color: textPrimary),
        labelSmall: labelSmall.copyWith(color: textSecondary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,  // White background for better contrast
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: const BorderSide(color: borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: const BorderSide(color: borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: const BorderSide(color: error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: space16,
          vertical: space12,
        ),
        hintStyle: bodyMedium.copyWith(color: textTertiary),  // Better hint text contrast
        labelStyle: bodyMedium.copyWith(color: textSecondary), // Better label contrast
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceVariant,
        labelStyle: labelMedium,
        padding: const EdgeInsets.symmetric(
          horizontal: space12,
          vertical: space4,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCircular),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: borderLight,
        thickness: 1,
        space: 1,
      ),
    );
  }
  
  /// Dark theme
  static ThemeData darkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.dark,
        primary: primaryLight,
        secondary: secondaryLight,
        surface: surfaceDark,
        background: backgroundDark,
        error: error,
      ),
      scaffoldBackgroundColor: backgroundDark,
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: surfaceDark,
        foregroundColor: Colors.white,
        titleTextStyle: headlineSmall.copyWith(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          side: const BorderSide(color: Color(0xFF334155)),  // Solid dark border
        ),
        clipBehavior: Clip.antiAlias,
      ),
      textTheme: TextTheme(
        displayLarge: displayLarge.copyWith(color: Colors.white),
        displayMedium: displayMedium.copyWith(color: Colors.white),
        displaySmall: displaySmall.copyWith(color: Colors.white),
        headlineLarge: headlineLarge.copyWith(color: Colors.white),
        headlineMedium: headlineMedium.copyWith(color: Colors.white),
        headlineSmall: headlineSmall.copyWith(color: Colors.white),
        titleLarge: titleLarge.copyWith(color: Colors.white),
        titleMedium: titleMedium.copyWith(color: Colors.white),
        titleSmall: titleSmall.copyWith(color: Colors.white),
        bodyLarge: bodyLarge.copyWith(color: const Color(0xFFE2E8F0)),    // Solid light gray
        bodyMedium: bodyMedium.copyWith(color: const Color(0xFFE2E8F0)),  // Solid light gray
        bodySmall: bodySmall.copyWith(color: const Color(0xFF94A3B8)),    // Solid medium gray
        labelLarge: labelLarge.copyWith(color: Colors.white),
        labelMedium: labelMedium.copyWith(color: Colors.white),
        labelSmall: labelSmall.copyWith(color: const Color(0xFF94A3B8)),  // Solid medium gray
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF334155),  // Solid dark divider
        thickness: 1,
        space: 1,
      ),
    );
  }
}