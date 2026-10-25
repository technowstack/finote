import 'package:finote/core/theme/app_colors.dart';
import 'package:finote/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('light theme uses porcelain surfaces and electric blue actions', () {
    final theme = AppTheme.light;
    final colors = theme.colorScheme;
    expect(theme.scaffoldBackgroundColor, const Color(0xFFF8F9FC));
    expect(colors.surface, Colors.white);
    expect(colors.surfaceContainerLow, const Color(0xFFF8F9FC));
    expect(colors.surfaceContainer, const Color(0xFFF1F4FA));
    expect(colors.primary, const Color(0xFF4263EB));
    expect(colors.onPrimary, Colors.white);
    expect(colors.primaryContainer, const Color(0xFFE8EDFF));
    expect(colors.onPrimaryContainer, const Color(0xFF233D9F));
    expect(colors.onSurface, const Color(0xFF182238));
    expect(colors.onSurfaceVariant, const Color(0xFF657188));
    expect(colors.outline, const Color(0xFFB9C3D7));
    expect(colors.outlineVariant, const Color(0xFFE3E8F1));
    expect(colors.incomeColor, const Color(0xFF0D806A));
    expect(colors.expenseColor, const Color(0xFFAE534B));
    expect(colors.incomeAccentColor, const Color(0xFF0F8B72));
    expect(colors.expenseAccentColor, const Color(0xFFC96B63));
    expect(theme.navigationBarTheme.backgroundColor, Colors.white);
    expect(theme.navigationBarTheme.indicatorColor, const Color(0xFFE8EDFF));
    expect(theme.cardTheme.color, Colors.white);
    expect(theme.dialogTheme.backgroundColor, Colors.white);
    expect(theme.bottomSheetTheme.backgroundColor, Colors.white);
    expect(theme.chipTheme.selectedColor, colors.primaryContainer);
    expect(theme.inputDecorationTheme.fillColor, Colors.white);
    expect(
      theme.inputDecorationTheme.focusedBorder?.borderSide.color,
      colors.primary,
    );
    expect(theme.floatingActionButtonTheme.backgroundColor, colors.primary);
    expect(theme.floatingActionButtonTheme.foregroundColor, Colors.white);
    expect(
      theme.navigationBarTheme.iconTheme?.resolve({
        WidgetState.selected,
      })?.color,
      colors.onPrimaryContainer,
    );
    expect(
      theme.navigationBarTheme.iconTheme?.resolve({})?.color,
      const Color(0xFF758096),
    );
    expect(theme.textTheme.bodyLarge?.fontFamily, 'Roboto');
    expect(
      _contrast(colors.onSurface, colors.surfaceContainerLow),
      greaterThan(4.5),
    );
    expect(_contrast(colors.onPrimary, colors.primary), greaterThan(4.5));
    expect(
      _contrast(colors.onSurfaceVariant, theme.scaffoldBackgroundColor),
      greaterThan(4.5),
    );
    expect(
      _contrast(colors.incomeColor, theme.scaffoldBackgroundColor),
      greaterThan(4.5),
    );
    expect(
      _contrast(colors.expenseColor, theme.scaffoldBackgroundColor),
      greaterThan(4.5),
    );
    expect(
      _contrast(colors.error, theme.scaffoldBackgroundColor),
      greaterThan(4.5),
    );
    expect(
      _contrast(colors.onPrimaryContainer, colors.primaryContainer),
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

  testWidgets('light tonal filter remains a secondary action', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: FilledButton.tonalIcon(
            onPressed: () {},
            icon: const Icon(Icons.filter_list),
            label: const Text('Filter'),
          ),
        ),
      ),
    );
    final material = tester.widget<Material>(
      find
          .ancestor(of: find.text('Filter'), matching: find.byType(Material))
          .first,
    );
    expect(material.color, AppTheme.light.colorScheme.secondaryContainer);
  });
}

double _contrast(Color first, Color second) {
  final a = first.computeLuminance();
  final b = second.computeLuminance();
  return (a > b ? a + 0.05 : b + 0.05) / (a > b ? b + 0.05 : a + 0.05);
}
