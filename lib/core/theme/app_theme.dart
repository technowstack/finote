import 'package:flutter/material.dart';

abstract final class AppTheme {
  // Fresh Mint Minimal: mint canvas, white cards, restrained teal actions.
  static const _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF00A985),
    onPrimary: Color(0xFF102820),
    primaryContainer: Color(0xFFD8F2E8),
    onPrimaryContainer: Color(0xFF102820),
    secondary: Color(0xFF008568),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFD8F2E8),
    onSecondaryContainer: Color(0xFF102820),
    tertiary: Color(0xFF657970),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFF3F6F4),
    onTertiaryContainer: Color(0xFF102820),
    error: Color(0xFFAE4F42),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFBE7E3),
    onErrorContainer: Color(0xFF4A1710),
    surface: Color(0xFFE8F1EC),
    onSurface: Color(0xFF102820),
    onSurfaceVariant: Color(0xFF5B6E65),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFFFFFFF),
    surfaceContainer: Color(0xFFF3F6F4),
    surfaceContainerHigh: Color(0xFFEAF1EC),
    surfaceContainerHighest: Color(0xFFE0EAE4),
    outline: Color(0xFF657970),
    outlineVariant: Color(0xFFE0EAE4),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFF102820),
    onInverseSurface: Color(0xFFFFFFFF),
    inversePrimary: Color(0xFFEAFF86),
  );

  // Midnight Aurora: solid plum surfaces; only the Dashboard hero uses light.
  static const _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFEAFF86),
    onPrimary: Color(0xFF171B11),
    primaryContainer: Color(0xFF423950),
    onPrimaryContainer: Color(0xFFF6F3FA),
    secondary: Color(0xFFB7A1D3),
    onSecondary: Color(0xFF211D30),
    secondaryContainer: Color(0xFF423950),
    onSecondaryContainer: Color(0xFFF6F3FA),
    tertiary: Color(0xFFC47D69),
    onTertiary: Color(0xFF171B11),
    tertiaryContainer: Color(0xFF423950),
    onTertiaryContainer: Color(0xFFF6F3FA),
    error: Color(0xFFE9A19B),
    onError: Color(0xFF301717),
    errorContainer: Color(0xFF59332F),
    onErrorContainer: Color(0xFFF6F3FA),
    surface: Color(0xFF0D0B16),
    onSurface: Color(0xFFF6F3FA),
    onSurfaceVariant: Color(0xFFB8B0C7),
    surfaceContainerLowest: Color(0xFF0D0B16),
    surfaceContainerLow: Color(0xFF211D30),
    surfaceContainer: Color(0xFF211D30),
    surfaceContainerHigh: Color(0xFF2C263B),
    surfaceContainerHighest: Color(0xFF423950),
    outline: Color(0xFFB8B0C7),
    outlineVariant: Color(0xFF423950),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFFF6F3FA),
    onInverseSurface: Color(0xFF211D30),
    inversePrimary: Color(0xFF008568),
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
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: colors.onSurface,
      ),
      displayMedium: TextStyle(
        fontFamily: baseFamily,
        fontSize: 28,
        fontWeight: FontWeight.w700,
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
      borderRadius: BorderRadius.all(Radius.circular(18)),
    ),
  );

  static const _listTileTheme = ListTileThemeData(
    visualDensity: VisualDensity(horizontal: 0, vertical: -1),
    contentPadding: EdgeInsets.symmetric(horizontal: 16),
  );

  static const _inputTheme = InputDecorationTheme(
    filled: true,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(14)),
    ),
    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );

  static const _chipTheme = ChipThemeData(
    showCheckmark: false,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
    ),
    padding: EdgeInsets.symmetric(horizontal: 4),
  );

  static const _fabTheme = FloatingActionButtonThemeData(
    elevation: 0,
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
      backgroundColor: _lightScheme.surfaceContainerLow,
      indicatorColor: _lightScheme.primaryContainer,
      labelTextStyle: const WidgetStatePropertyAll(
        TextStyle(
          fontFamily: 'Roboto',
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: const Color(0xFF007A60)),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF007A60)),
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
      backgroundColor: _darkScheme.surfaceContainerLow,
      indicatorColor: _darkScheme.primaryContainer,
      labelTextStyle: const WidgetStatePropertyAll(
        TextStyle(
          fontFamily: 'Roboto',
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
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
