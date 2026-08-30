import 'package:flutter/material.dart';

abstract final class AppTheme {
  // ---------------------------------------------------------------------------
  // Color schemes — hand-tuned for comfort
  // ---------------------------------------------------------------------------

  /// Light palette: warm off-white background, soft teal primary, dark
  /// charcoal text. Avoids pure #FFFFFF for surfaces.
  static const _lightScheme = ColorScheme(
    brightness: Brightness.light,
    // Primary — soft teal
    primary: Color(0xFF2A7F67),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFD0F0E4),
    onPrimaryContainer: Color(0xFF0E3B2C),
    // Secondary — muted sage
    secondary: Color(0xFF4F6358),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFD2E8DA),
    onSecondaryContainer: Color(0xFF0C1F16),
    // Tertiary — soft warm accent
    tertiary: Color(0xFF3D6373),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFC1E8FB),
    onTertiaryContainer: Color(0xFF001F2A),
    // Error — muted coral-red
    error: Color(0xFFC0392B),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFCE4E4),
    onErrorContainer: Color(0xFF410002),
    // Surfaces — warm off-white, not pure white
    surface: Color(0xFFF7F5F2),
    onSurface: Color(0xFF1C1B1A),
    onSurfaceVariant: Color(0xFF5C5C5A),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFF1EFEC),
    surfaceContainer: Color(0xFFEBE9E6),
    surfaceContainerHigh: Color(0xFFE5E3E0),
    surfaceContainerHighest: Color(0xFFDFDDDA),
    // Outline
    outline: Color(0xFF8E8E8C),
    outlineVariant: Color(0xFFC8C6C3),
    // Misc
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFF313030),
    onInverseSurface: Color(0xFFF3F0EE),
    inversePrimary: Color(0xFF8DD4B8),
  );

  /// Dark palette: very dark neutral (no pure black), slightly warm.
  /// Green/teal is an accent, not the dominant background.
  static const _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    // Primary — desaturated teal
    primary: Color(0xFF8DD4B8),
    onPrimary: Color(0xFF003828),
    primaryContainer: Color(0xFF1A5E47),
    onPrimaryContainer: Color(0xFFD0F0E4),
    // Secondary — muted sage
    secondary: Color(0xFFB6CCBF),
    onSecondary: Color(0xFF21352B),
    secondaryContainer: Color(0xFF374B41),
    onSecondaryContainer: Color(0xFFD2E8DA),
    // Tertiary — soft cool accent
    tertiary: Color(0xFFA5CCDF),
    onTertiary: Color(0xFF073544),
    tertiaryContainer: Color(0xFF244B5B),
    onTertiaryContainer: Color(0xFFC1E8FB),
    // Error — muted peach-red
    error: Color(0xFFEF8E7E),
    onError: Color(0xFF601410),
    errorContainer: Color(0xFF8C1D18),
    onErrorContainer: Color(0xFFFCDAD5),
    // Surfaces — dark neutral, not pure black
    surface: Color(0xFF161615),
    onSurface: Color(0xFFE3E2DF),
    onSurfaceVariant: Color(0xFFADADAB),
    surfaceContainerLowest: Color(0xFF101010),
    surfaceContainerLow: Color(0xFF1D1D1C),
    surfaceContainer: Color(0xFF222221),
    surfaceContainerHigh: Color(0xFF2C2C2B),
    surfaceContainerHighest: Color(0xFF373736),
    // Outline
    outline: Color(0xFF7A7A78),
    outlineVariant: Color(0xFF484846),
    // Misc
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFFE3E2DF),
    onInverseSurface: Color(0xFF313030),
    inversePrimary: Color(0xFF2A7F67),
  );

  // ---------------------------------------------------------------------------
  // Typography
  // ---------------------------------------------------------------------------

  static TextTheme _textTheme(ColorScheme colors) {
    const baseFamily = 'Roboto';
    return TextTheme(
      displayLarge: TextStyle(
        fontFamily: baseFamily,
        fontSize: 34,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        color: colors.onSurface,
      ),
      displayMedium: TextStyle(
        fontFamily: baseFamily,
        fontSize: 28,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.25,
        color: colors.onSurface,
      ),
      headlineLarge: TextStyle(
        fontFamily: baseFamily,
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: colors.onSurface,
      ),
      headlineMedium: TextStyle(
        fontFamily: baseFamily,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: colors.onSurface,
      ),
      titleLarge: TextStyle(
        fontFamily: baseFamily,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: colors.onSurface,
      ),
      titleMedium: TextStyle(
        fontFamily: baseFamily,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: colors.onSurface,
      ),
      titleSmall: TextStyle(
        fontFamily: baseFamily,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: colors.onSurfaceVariant,
      ),
      bodyLarge: TextStyle(
        fontFamily: baseFamily,
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: colors.onSurface,
      ),
      bodyMedium: TextStyle(
        fontFamily: baseFamily,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: colors.onSurface,
      ),
      bodySmall: TextStyle(
        fontFamily: baseFamily,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: colors.onSurfaceVariant,
      ),
      labelLarge: TextStyle(
        fontFamily: baseFamily,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: colors.onSurface,
      ),
      labelMedium: TextStyle(
        fontFamily: baseFamily,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        color: colors.onSurfaceVariant,
      ),
      labelSmall: TextStyle(
        fontFamily: baseFamily,
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        color: colors.onSurfaceVariant,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Component themes
  // ---------------------------------------------------------------------------

  static const _cardTheme = CardThemeData(
    elevation: 0,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
    ),
  );

  static const _listTileTheme = ListTileThemeData(
    visualDensity: VisualDensity(horizontal: 0, vertical: -1),
    contentPadding: EdgeInsets.symmetric(horizontal: 16),
  );

  static const _inputTheme = InputDecorationTheme(
    filled: true,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
    ),
    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );

  static const _chipTheme = ChipThemeData(
    showCheckmark: false,
    shape: StadiumBorder(),
    padding: EdgeInsets.symmetric(horizontal: 4),
  );

  static const _fabTheme = FloatingActionButtonThemeData(
    elevation: 2,
    shape: CircleBorder(),
  );

  static const _dividerTheme = DividerThemeData(space: 1, thickness: 1);

  static const _snackBarTheme = SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(10)),
    ),
  );

  // ---------------------------------------------------------------------------
  // Assembled themes
  // ---------------------------------------------------------------------------

  static final light = ThemeData(
    colorScheme: _lightScheme,
    useMaterial3: true,
    textTheme: _textTheme(_lightScheme),
    scaffoldBackgroundColor: _lightScheme.surface,
    cardTheme: _cardTheme.copyWith(color: _lightScheme.surfaceContainerLow),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
      backgroundColor: _lightScheme.surface,
      foregroundColor: _lightScheme.onSurface,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: _lightScheme.surfaceContainer,
      indicatorColor: _lightScheme.primaryContainer,
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      backgroundColor: _lightScheme.surfaceContainerLow,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      backgroundColor: _lightScheme.surfaceContainerLow,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    ),
    listTileTheme: _listTileTheme,
    inputDecorationTheme: _inputTheme,
    chipTheme: _chipTheme,
    floatingActionButtonTheme: _fabTheme,
    dividerTheme: _dividerTheme,
    snackBarTheme: _snackBarTheme,
  );

  static final dark = ThemeData(
    colorScheme: _darkScheme,
    useMaterial3: true,
    textTheme: _textTheme(_darkScheme),
    scaffoldBackgroundColor: _darkScheme.surface,
    cardTheme: _cardTheme.copyWith(color: _darkScheme.surfaceContainerLow),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
      backgroundColor: _darkScheme.surface,
      foregroundColor: _darkScheme.onSurface,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: _darkScheme.surfaceContainer,
      indicatorColor: _darkScheme.primaryContainer,
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      backgroundColor: _darkScheme.surfaceContainerLow,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      backgroundColor: _darkScheme.surfaceContainerLow,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    ),
    listTileTheme: _listTileTheme,
    inputDecorationTheme: _inputTheme,
    chipTheme: _chipTheme,
    floatingActionButtonTheme: _fabTheme,
    dividerTheme: _dividerTheme,
    snackBarTheme: _snackBarTheme,
  );
}
