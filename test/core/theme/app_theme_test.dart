import 'package:finote/core/theme/app_colors.dart';
import 'package:finote/core/theme/app_radius.dart';
import 'package:finote/core/theme/app_theme.dart';
import 'package:finote/core/theme/category_style.dart';
import 'package:finote/core/theme/finote_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('both modes share one brand hue', () {
    expect(AppTheme.light.colorScheme.primary, const Color(0xFF3B5BDB));
    expect(AppTheme.dark.colorScheme.primary, const Color(0xFF8EA2FF));
    final lightHue = HSVColor.fromColor(AppTheme.light.colorScheme.primary).hue;
    for (final theme in [AppTheme.light, AppTheme.dark]) {
      final colors = theme.colorScheme;
      expect(colors.secondary, colors.primary);
      expect(colors.tertiary, colors.primary);
      expect(HSVColor.fromColor(colors.primary).hue, closeTo(lightHue, 3));
    }
  });

  for (final theme in [AppTheme.light, AppTheme.dark]) {
    final mode = theme.brightness.name;
    final c = theme.finote;
    final colors = theme.colorScheme;

    test('$mode theme maps tokens onto Material roles', () {
      expect(theme.extension<FinoteColors>(), same(c));
      expect(theme.scaffoldBackgroundColor, c.bg);
      expect(colors.surface, c.surface);
      expect(colors.onSurface, c.text);
      expect(colors.onSurfaceVariant, c.textMuted);
      expect(colors.error, c.error);
      expect(colors.scrim, c.scrim);
      expect(colors.outline, c.outline);
      expect(colors.outlineVariant, c.divider);
      expect(colors.incomeColor, c.income);
      expect(colors.expenseColor, c.expense);
      expect(colors.warningColor, c.warning);
      expect(theme.materialTapTargetSize, MaterialTapTargetSize.padded);
    });

    test('$mode component themes are complete and tone-based', () {
      final card = theme.cardTheme.shape! as RoundedRectangleBorder;
      expect(theme.cardTheme.color, c.surface);
      expect(card.borderRadius, AppRadius.lgAll);
      expect(card.side, BorderSide.none);
      expect(theme.navigationBarTheme.backgroundColor, c.surface);
      expect(
        theme.navigationBarTheme.iconTheme?.resolve({})?.color,
        c.textMuted,
      );
      expect(
        theme.navigationBarTheme.iconTheme?.resolve({
          WidgetState.selected,
        })?.color,
        c.onPrimaryContainer,
      );
      expect(theme.dialogTheme.backgroundColor, c.surface);
      expect(theme.dialogTheme.barrierColor, c.scrim);
      expect(theme.bottomSheetTheme.modalBarrierColor, c.scrim);
      expect(theme.floatingActionButtonTheme.backgroundColor, c.primary);
      expect(theme.floatingActionButtonTheme.foregroundColor, c.onPrimary);
      expect(theme.inputDecorationTheme.fillColor, isA<WidgetStateColor>());
      expect(
        theme.inputDecorationTheme.focusedBorder?.borderSide.color,
        c.focus,
      );
      expect(theme.inputDecorationTheme.focusedBorder?.borderSide.width, 2);
      expect(theme.chipTheme.color?.resolve({WidgetState.selected}), c.primary);
      expect(theme.chipTheme.color?.resolve({}), c.surfaceAlt);
      expect(theme.snackBarTheme.backgroundColor, c.inverseSurface);
      expect(theme.dividerTheme.color, c.divider);
      expect(theme.searchBarTheme.backgroundColor?.resolve({}), c.surface);
    });

    test('$mode text pairs meet WCAG AA', () {
      final pairs = {
        'text/bg': (c.text, c.bg),
        'textMuted/bg': (c.textMuted, c.bg),
        'textMuted/surface': (c.textMuted, c.surface),
        'textMuted/surfaceAlt': (c.textMuted, c.surfaceAlt),
        'income/surface': (c.income, c.surface),
        'expense/surface': (c.expense, c.surface),
        'error/surface': (c.error, c.surface),
        'onPrimary/primary': (c.onPrimary, c.primary),
        'onPrimaryContainer/primaryContainer': (
          c.onPrimaryContainer,
          c.primaryContainer,
        ),
        'onHero/heroFrom': (c.onHero, c.heroFrom),
        'onHeroMuted/heroFrom': (c.onHeroMuted, c.heroFrom),
        'onWarningContainer/warningContainer': (
          c.onWarningContainer,
          c.warningContainer,
        ),
        'onInverseSurface/inverseSurface': (
          c.onInverseSurface,
          c.inverseSurface,
        ),
      };
      pairs.forEach((name, pair) {
        expect(_contrast(pair.$1, pair.$2), greaterThan(4.5), reason: name);
      });
    });

    test('$mode category icons meet non-text contrast (3:1)', () {
      for (final pair in [...c.categories.values, c.transfer]) {
        expect(_contrast(pair.foreground, pair.background), greaterThan(3));
      }
    });
  }

  test('all 17 default categories resolve to their own style', () {
    const c = FinoteColors.light;
    expect(FinoteCategory.values, hasLength(17));
    expect(c.categories.keys.toSet(), FinoteCategory.values.toSet());
    expect(
      FinoteColors.dark.categories.keys.toSet(),
      c.categories.keys.toSet(),
    );
    final food = c.categoryStyle('Makanan & Minuman');
    expect(food.icon, Icons.restaurant_rounded);
    expect(food.colors, c.categories[FinoteCategory.food]);
    expect(c.categoryStyle('Lainnya').icon, Icons.more_horiz_rounded);
    expect(c.transferStyle.icon, Icons.swap_horiz_rounded);
    expect(c.transferStyle.colors, c.transfer);
  });

  test('custom categories use the tokens.json hash, deterministically', () {
    // Reference indices computed independently from the tokens.json formula.
    const expected = {
      'Kopi': 1,
      'Langganan': 3,
      'Parkir Kantor': 2,
      'Cicilan Motor': 0,
      'A': 5,
      '': 0,
    };
    const c = FinoteColors.dark;
    expected.forEach((name, index) {
      expect(customCategoryIndex(name), index, reason: name);
      final style = c.categoryStyle(name);
      expect(style.icon, customCategoryIcon);
      expect(style.colors, c.categories[customCategoryPalette[index]]);
    });
  });

  testWidgets('tonal filter remains a secondary-container action', (
    tester,
  ) async {
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
