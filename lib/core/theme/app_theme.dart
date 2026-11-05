import 'package:flutter/material.dart';

import 'app_radius.dart';
import 'app_typography.dart';
import 'finote_colors.dart';

/// Light and dark themes built from one token set (`docs/design/tokens.json`),
/// so both modes share the same brand hue and component shapes.
abstract final class AppTheme {
  static final light = _build(Brightness.light, FinoteColors.light);
  static final dark = _build(Brightness.dark, FinoteColors.dark);

  static ColorScheme _scheme(Brightness brightness, FinoteColors c) =>
      ColorScheme(
        brightness: brightness,
        primary: c.primary,
        onPrimary: c.onPrimary,
        primaryContainer: c.primaryContainer,
        onPrimaryContainer: c.onPrimaryContainer,
        // One brand hue: tokens define no secondary/tertiary palette, so those
        // roles reuse primary instead of introducing a second color identity.
        secondary: c.primary,
        onSecondary: c.onPrimary,
        secondaryContainer: c.primaryContainer,
        onSecondaryContainer: c.onPrimaryContainer,
        tertiary: c.primary,
        onTertiary: c.onPrimary,
        tertiaryContainer: c.primaryContainer,
        onTertiaryContainer: c.onPrimaryContainer,
        error: c.error,
        onError: c.onError,
        errorContainer: c.errorContainer,
        onErrorContainer: c.onErrorContainer,
        surface: c.surface,
        onSurface: c.text,
        onSurfaceVariant: c.textMuted,
        surfaceContainerLowest: c.surface,
        surfaceContainerLow: c.surfaceAlt,
        surfaceContainer: c.surfaceAlt,
        surfaceContainerHigh: c.surfaceAlt,
        surfaceContainerHighest: c.disabled,
        surfaceTint: Colors.transparent,
        outline: c.outline,
        outlineVariant: c.divider,
        shadow: Colors.black,
        scrim: c.scrim,
        inverseSurface: c.inverseSurface,
        onInverseSurface: c.onInverseSurface,
        inversePrimary: c.inversePrimary,
      );

  static ThemeData _build(Brightness brightness, FinoteColors c) {
    final text = AppTypography.textTheme(c);
    const buttonShape = RoundedRectangleBorder(borderRadius: AppRadius.mdAll);
    const buttonMinSize = Size(64, 48);
    final buttonText = WidgetStatePropertyAll(text.labelLarge);

    OutlineInputBorder inputBorder(Color color, double width) =>
        OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: _scheme(brightness, c),
      textTheme: text,
      extensions: [c],
      // Visuals may be smaller (chip 34, icon button 40); hit area stays 48.
      materialTapTargetSize: MaterialTapTargetSize.padded,
      scaffoldBackgroundColor: c.bg,
      // Surfaces are separated by tone, not borders or elevation.
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: c.bg,
        foregroundColor: c.text,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: c.primaryContainer,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? c.onPrimaryContainer
                : c.textMuted,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppTypography.captionSemibold.copyWith(
                  color: c.onPrimaryContainer,
                )
              : AppTypography.captionMedium.copyWith(color: c.textMuted),
        ),
      ),
      // Enabled colors resolve to null so FilledButton.tonal keeps its own.
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.disabled) ? c.disabled : null,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.disabled) ? c.onDisabled : null,
          ),
          elevation: const WidgetStatePropertyAll(0),
          minimumSize: const WidgetStatePropertyAll(buttonMinSize),
          shape: const WidgetStatePropertyAll(buttonShape),
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          side: WidgetStateProperty.resolveWith(
            (states) => BorderSide(
              color: states.contains(WidgetState.disabled)
                  ? c.divider
                  : c.outline,
            ),
          ),
          minimumSize: const WidgetStatePropertyAll(buttonMinSize),
          shape: const WidgetStatePropertyAll(buttonShape),
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
          shape: const WidgetStatePropertyAll(buttonShape),
          textStyle: buttonText,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(buttonMinSize),
          shape: const WidgetStatePropertyAll(buttonShape),
          textStyle: buttonText,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.primary,
        foregroundColor: c.onPrimary,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: const CircleBorder(),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        barrierColor: c.scrim,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.xlAll),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        modalBackgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: c.scrim,
        dragHandleColor: c.outline,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: c.surface,
          foregroundColor: c.textMuted,
          selectedBackgroundColor: c.primary,
          selectedForegroundColor: c.onPrimary,
          disabledBackgroundColor: c.disabled,
          disabledForegroundColor: c.onDisabled,
          side: BorderSide.none,
          minimumSize: const Size(0, 48),
          textStyle: AppTypography.labelMd,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        ),
      ),
      chipTheme: ChipThemeData(
        showCheckmark: false,
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        color: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return c.disabled;
          if (states.contains(WidgetState.selected)) return c.primary;
          return c.surfaceAlt;
        }),
        labelStyle: AppTypography.labelSm.copyWith(
          color: WidgetStateColor.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return c.onDisabled;
            if (states.contains(WidgetState.selected)) return c.onPrimary;
            return c.text;
          }),
        ),
      ),
      // Inputs are the only bordered surface besides Outline buttons.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: WidgetStateColor.resolveWith(
          (states) =>
              states.contains(WidgetState.disabled) ? c.disabled : c.surface,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: inputBorder(c.outline, 1),
        enabledBorder: inputBorder(c.outline, 1),
        focusedBorder: inputBorder(c.focus, 2),
        errorBorder: inputBorder(c.error, 2),
        focusedErrorBorder: inputBorder(c.error, 2),
        disabledBorder: const OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide.none,
        ),
        helperStyle: AppTypography.captionRegular.copyWith(color: c.textMuted),
        errorStyle: AppTypography.captionRegular.copyWith(color: c.error),
      ),
      searchBarTheme: SearchBarThemeData(
        backgroundColor: WidgetStatePropertyAll(c.surface),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(0),
        constraints: const BoxConstraints(minHeight: 48),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 16),
        ),
        shape: const WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: AppRadius.xlAll),
        ),
        side: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.focused)
              ? BorderSide(color: c.focus)
              : BorderSide.none,
        ),
        textStyle: WidgetStatePropertyAll(
          AppTypography.bodyLg.copyWith(color: c.text),
        ),
        hintStyle: WidgetStatePropertyAll(
          AppTypography.bodyLg.copyWith(color: c.textMuted),
        ),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        minTileHeight: 56,
        iconColor: c.textMuted,
        subtitleTextStyle: text.bodySmall,
      ),
      dividerTheme: DividerThemeData(color: c.divider, space: 1, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.inverseSurface,
        contentTextStyle: AppTypography.bodyMd.copyWith(
          color: c.onInverseSurface,
        ),
        actionTextColor: c.inversePrimary,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      ),
    );
  }
}
