import 'package:finote/core/theme/app_colors.dart';
import 'package:finote/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('light theme has mint surroundings and neutral readable surfaces', () {
    final theme = AppTheme.light;
    final colors = theme.colorScheme;
    expect(colors.surface, const Color(0xFFE8F1EC));
    expect(colors.surfaceContainerLow, Colors.white);
    expect(colors.primary, const Color(0xFF00A985));
    expect(colors.onSurface, const Color(0xFF102820));
    expect(colors.incomeColor, const Color(0xFF007A60));
    expect(colors.expenseColor, const Color(0xFFA84F43));
    expect(colors.incomeAccentColor, const Color(0xFF00896C));
    expect(colors.expenseAccentColor, const Color(0xFFC5685A));
    expect(theme.navigationBarTheme.backgroundColor, Colors.white);
    expect(theme.navigationBarTheme.indicatorColor, const Color(0xFFD8F2E8));
    expect(theme.textTheme.bodyLarge?.fontFamily, 'Roboto');
    expect(
      _contrast(colors.onSurface, colors.surfaceContainerLow),
      greaterThan(4.5),
    );
    expect(_contrast(colors.onPrimary, colors.primary), greaterThan(4.5));
    expect(
      _contrast(colors.onSurfaceVariant, colors.surface),
      greaterThan(4.5),
    );
    expect(_contrast(colors.incomeColor, colors.surface), greaterThan(4.5));
    expect(
      _contrast(colors.expenseColor, colors.surfaceContainerLow),
      greaterThan(4.5),
    );
  });

  test('dark theme has midnight surfaces and a legible lime action', () {
    final theme = AppTheme.dark;
    final colors = theme.colorScheme;
    expect(colors.surface, const Color(0xFF0D0B16));
    expect(colors.surfaceContainerLow, const Color(0xFF211D30));
    expect(colors.primary, const Color(0xFFEAFF86));
    expect(colors.onPrimary, const Color(0xFF171B11));
    expect(colors.incomeColor, const Color(0xFFA5DCC1));
    expect(colors.expenseColor, const Color(0xFFE9A19B));
    expect(theme.navigationBarTheme.backgroundColor, const Color(0xFF211D30));
    expect(
      _contrast(colors.onSurface, colors.surfaceContainerLow),
      greaterThan(4.5),
    );
    expect(_contrast(colors.onPrimary, colors.primary), greaterThan(4.5));
  });
}

double _contrast(Color first, Color second) {
  final a = first.computeLuminance();
  final b = second.computeLuminance();
  return (a > b ? a + 0.05 : b + 0.05) / (a > b ? b + 0.05 : a + 0.05);
}
