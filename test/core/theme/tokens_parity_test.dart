import 'dart:convert';
import 'dart:io';

import 'package:finote/core/theme/app_radius.dart';
import 'package:finote/core/theme/app_spacing.dart';
import 'package:finote/core/theme/app_typography.dart';
import 'package:finote/core/theme/category_style.dart';
import 'package:finote/core/theme/finote_colors.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards against transcription drift between docs/design/tokens.json and
/// the Dart theme. Regenerated tokens that change a value fail here.
void main() {
  final tokens = jsonDecode(
    File('docs/design/tokens.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  Color hex(String value) {
    final h = value.substring(1);
    final rgb = int.parse(h.substring(0, 6), radix: 16);
    final alpha = h.length == 8 ? int.parse(h.substring(6), radix: 16) : 0xFF;
    return Color((alpha << 24) | rgb);
  }

  Map<String, dynamic> node(String path) {
    var current = tokens;
    for (final key in path.split('.')) {
      current = current[key] as Map<String, dynamic>;
    }
    return current;
  }

  Color tokenColor(String path, String mode) {
    final ext = node(path)[r'$extensions'] as Map<String, dynamic>;
    final modes = ext['finote.mode'] as Map<String, dynamic>;
    return hex(modes[mode] as String);
  }

  final colorGetters = <String, Color Function(FinoteColors)>{
    'color.bg': (c) => c.bg,
    'color.surface': (c) => c.surface,
    'color.surfaceAlt': (c) => c.surfaceAlt,
    'color.primary': (c) => c.primary,
    'color.onPrimary': (c) => c.onPrimary,
    'color.primaryContainer': (c) => c.primaryContainer,
    'color.onPrimaryContainer': (c) => c.onPrimaryContainer,
    'color.text': (c) => c.text,
    'color.textMuted': (c) => c.textMuted,
    'color.income': (c) => c.income,
    'color.expense': (c) => c.expense,
    'color.heroFrom': (c) => c.heroFrom,
    'color.heroTo': (c) => c.heroTo,
    'color.onHero': (c) => c.onHero,
    'color.onHeroMuted': (c) => c.onHeroMuted,
    'color.onHeroChip': (c) => c.onHeroChip,
    'color.transfer.fg': (c) => c.transfer.foreground,
    'color.transfer.bg': (c) => c.transfer.background,
    'color.error': (c) => c.error,
    'color.onError': (c) => c.onError,
    'color.errorContainer': (c) => c.errorContainer,
    'color.onErrorContainer': (c) => c.onErrorContainer,
    'color.warning': (c) => c.warning,
    'color.warningContainer': (c) => c.warningContainer,
    'color.onWarningContainer': (c) => c.onWarningContainer,
    'color.outline': (c) => c.outline,
    'color.focus': (c) => c.focus,
    'color.disabled': (c) => c.disabled,
    'color.onDisabled': (c) => c.onDisabled,
    'color.divider': (c) => c.divider,
    'color.scrim': (c) => c.scrim,
    'color.inverseSurface': (c) => c.inverseSurface,
    'color.onInverseSurface': (c) => c.onInverseSurface,
    'color.inversePrimary': (c) => c.inversePrimary,
    'shadowColor.hero': (c) => c.shadowHero,
    'shadowColor.fab': (c) => c.shadowFab,
    for (final category in FinoteCategory.values) ...{
      'color.category.${category.name}.fg': (c) =>
          c.categories[category]!.foreground,
      'color.category.${category.name}.bg': (c) =>
          c.categories[category]!.background,
    },
  };

  for (final mode in ['light', 'dark']) {
    test('every non-alias color token matches ($mode)', () {
      final c = mode == 'light' ? FinoteColors.light : FinoteColors.dark;
      final seen = <String>{};
      void walk(Map<String, dynamic> map, String prefix) {
        for (final entry in map.entries) {
          if (entry.key.startsWith(r'$')) continue;
          final path = prefix.isEmpty ? entry.key : '$prefix.${entry.key}';
          final value = entry.value as Map<String, dynamic>;
          if (value[r'$type'] == 'color') {
            if ((value[r'$value'] as String).startsWith('{')) continue;
            expect(colorGetters, contains(path), reason: 'unmapped $path');
            expect(
              colorGetters[path]!(c),
              tokenColor(path, mode),
              reason: path,
            );
            seen.add(path);
          } else if (!value.containsKey(r'$value')) {
            walk(value, path);
          }
        }
      }

      walk(tokens, '');
      expect(seen, colorGetters.keys.toSet());
    });
  }

  test('custom category aliases match the palette order', () {
    for (var i = 0; i < customCategoryPalette.length; i++) {
      final alias =
          node('color.category.custom${i + 1}.fg')[r'$value'] as String;
      expect(alias, '{color.category.${customCategoryPalette[i].name}.fg}');
    }
  });

  test('category map names match the enum', () {
    final ext = tokens[r'$extensions'] as Map<String, dynamic>;
    final map = ext['finote.categoryMap'] as Map<String, dynamic>;
    for (final category in FinoteCategory.values) {
      expect(map[category.categoryName], category.name);
    }
  });

  double px(String path) {
    final value = node(path)[r'$value'] as Map<String, dynamic>;
    return (value['value'] as num).toDouble();
  }

  test('radius and spacing scales match', () {
    expect(px('radius.sm'), AppRadius.sm);
    expect(px('radius.md'), AppRadius.md);
    expect(px('radius.lg'), AppRadius.lg);
    expect(px('radius.xl'), AppRadius.xl);
    expect(px('spacing.xs'), AppSpacing.xs);
    expect(px('spacing.sm'), AppSpacing.sm);
    expect(px('spacing.md'), AppSpacing.md);
    expect(px('spacing.lg'), AppSpacing.lg);
    expect(px('spacing.xl'), AppSpacing.xl);
    expect(px('spacing.xxl'), AppSpacing.xxl);
  });

  test('typography sizes, weights, line heights and tnum match', () {
    final styles = <String, TextStyle>{
      'amount.hero': AppTypography.amountHero,
      'amount.xl': AppTypography.amountXl,
      'amount.lg': AppTypography.amountLg,
      'amount.md': AppTypography.amountMd,
      'amount.item': AppTypography.amountItem,
      'amount.sm': AppTypography.amountSm,
      'amount.xs': AppTypography.amountXs,
      'amount.caption': AppTypography.amountCaption,
      'title.screen': AppTypography.titleScreen,
      'title.screenSub': AppTypography.titleScreenSub,
      'title.dialog': AppTypography.titleDialog,
      'title.sheet': AppTypography.titleSheet,
      'title.section': AppTypography.titleSection,
      'title.card': AppTypography.titleCard,
      'body.lg': AppTypography.bodyLg,
      'body.input': AppTypography.bodyInput,
      'body.md': AppTypography.bodyMd,
      'body.sm': AppTypography.bodySm,
      'label.lg': AppTypography.labelLg,
      'label.md': AppTypography.labelMd,
      'label.sm': AppTypography.labelSm,
      'label.button': AppTypography.labelButton,
      'caption.regular': AppTypography.captionRegular,
      'caption.medium': AppTypography.captionMedium,
      'caption.semibold': AppTypography.captionSemibold,
      'caption.overline': AppTypography.captionOverline,
    };
    final groups = node('typography');
    final all = <String>{
      for (final group in groups.entries)
        if (!group.key.startsWith(r'$'))
          for (final key in (group.value as Map<String, dynamic>).keys)
            '${group.key}.$key',
    };
    expect(all, styles.keys.toSet());

    styles.forEach((name, style) {
      final token = node('typography.$name');
      final value = token[r'$value'] as Map<String, dynamic>;
      final ext = token[r'$extensions'] as Map<String, dynamic>;
      double unit(String key) =>
          ((value[key] as Map<String, dynamic>)['value'] as num).toDouble();
      final size = unit('fontSize');
      expect(style.fontSize, size, reason: name);
      expect(size, greaterThanOrEqualTo(12), reason: name);
      expect(style.fontWeight?.value, value['fontWeight'], reason: name);
      expect(style.letterSpacing, unit('letterSpacing'), reason: name);
      expect(
        style.height! * size,
        closeTo((ext['finote.lineHeightPx'] as num).toDouble(), 0.01),
        reason: name,
      );
      final tnum = ext.containsKey('finote.fontFeatureSettings');
      final hasTnum =
          style.fontFeatures?.contains(const FontFeature.tabularFigures()) ??
          false;
      expect(hasTnum, tnum, reason: name);
    });
  });
}
