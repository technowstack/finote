import 'package:flutter/material.dart';

abstract final class AppTheme {
  // Porcelain canvas, white cards, and electric-blue actions.
  static const _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF4263EB),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFE8EDFF),
    onPrimaryContainer: Color(0xFF233D9F),
    secondary: Color(0xFF415B92),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFEAF0FC),
    onSecondaryContainer: Color(0xFF243D71),
    tertiary: Color(0xFF0D806A),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFD9F2E8),
    onTertiaryContainer: Color(0xFF125B4D),
    error: Color(0xFFAE534B),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFFF0ED),
    onErrorContainer: Color(0xFF802E29),
    surface: Color(0xFFFFFFFF),
    onSurface: Color(0xFF182238),
    onSurfaceVariant: Color(0xFF657188),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFF8F9FC),
    surfaceContainer: Color(0xFFF1F4FA),
    surfaceContainerHigh: Color(0xFFEDF1F8),
    surfaceContainerHighest: Color(0xFFE8EDF6),
    outline: Color(0xFFB9C3D7),
    outlineVariant: Color(0xFFE3E8F1),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFF1D2A50),
    onInverseSurface: Color(0xFFF5FAF7),
    inversePrimary: Color(0xFFAEBFFF),
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
    scaffoldBackgroundColor: const Color(0xFFF8F9FC),
    cardTheme: _cardTheme.copyWith(
      color: _lightScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE3E8F1)),
      ),
    ),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
      backgroundColor: const Color(0xFFF8F9FC),
      foregroundColor: _lightScheme.onSurface,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: _lightScheme.surface,
      indicatorColor: _lightScheme.primaryContainer,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? _lightScheme.onPrimaryContainer
              : const Color(0xFF758096),
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontFamily: 'Roboto',
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w600
              : FontWeight.w500,
          color: states.contains(WidgetState.selected)
              ? _lightScheme.onPrimaryContainer
              : _lightScheme.onSurfaceVariant,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: _lightScheme.onPrimaryContainer,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(foregroundColor: _lightScheme.onSurface),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return const Color(0xFFEDF0F5);
          }
          return states.contains(WidgetState.pressed)
              ? const Color(0xFF3451CC)
              : null;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return const Color(0xFFA6AFBE);
          }
          return states.contains(WidgetState.pressed)
              ? _lightScheme.onPrimary
              : null;
        }),
      ),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      backgroundColor: _lightScheme.surface,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      backgroundColor: _lightScheme.surface,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    ),
    listTileTheme: _listTileTheme,
    inputDecorationTheme: _inputTheme.copyWith(
      fillColor: _lightScheme.surface,
      enabledBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: Color(0xFFB9C3D7)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: Color(0xFF4263EB), width: 2),
      ),
    ),
    chipTheme: _chipTheme.copyWith(
      backgroundColor: _lightScheme.surface,
      selectedColor: _lightScheme.primaryContainer,
      side: const BorderSide(color: Color(0xFFE3E8F1)),
    ),
    floatingActionButtonTheme: _fabTheme.copyWith(
      backgroundColor: _lightScheme.primary,
      foregroundColor: _lightScheme.onPrimary,
    ),
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
