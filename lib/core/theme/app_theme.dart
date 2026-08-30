import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const _seedColor = Color(0xFF1D6B57);

  // ---------------------------------------------------------------------------
  // Color schemes
  // ---------------------------------------------------------------------------

  static final _lightScheme = ColorScheme.fromSeed(seedColor: _seedColor);

  static final _darkScheme = ColorScheme.fromSeed(
    seedColor: _seedColor,
    brightness: Brightness.dark,
  );

  // ---------------------------------------------------------------------------
  // Typography
  // ---------------------------------------------------------------------------

  /// Builds a [TextTheme] with deliberate weight/size choices.
  ///
  /// Financial apps benefit from clear hierarchy: display for the
  /// big balance number, headline for amounts inside cards, and
  /// tighter body text for lists.
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
  // Component themes (shared between light & dark)
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
    cardTheme: _cardTheme.copyWith(
      color: _lightScheme.surfaceContainerLow,
    ),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
      backgroundColor: _lightScheme.surface,
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
    cardTheme: _cardTheme.copyWith(
      color: _darkScheme.surfaceContainerLow,
    ),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
      backgroundColor: _darkScheme.surface,
    ),
    listTileTheme: _listTileTheme,
    inputDecorationTheme: _inputTheme,
    chipTheme: _chipTheme,
    floatingActionButtonTheme: _fabTheme,
    dividerTheme: _dividerTheme,
    snackBarTheme: _snackBarTheme,
  );
}
