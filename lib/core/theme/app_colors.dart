import 'package:flutter/material.dart';

import 'category_style.dart';
import 'finote_colors.dart';

/// Legacy semantic color helpers on [ColorScheme], kept so existing screens
/// compile. Values now come from [FinoteColors] (tokens.json).
///
/// New code should read `Theme.of(context).finote` instead.
extension AppColors on ColorScheme {
  FinoteColors get _tokens => FinoteColors.of(brightness);

  @Deprecated('Use Theme.of(context).finote.heroGradient')
  Color get dashboardHeroColor => _tokens.heroTo;

  @Deprecated('Use Theme.of(context).finote.onHeroMuted')
  Color get dashboardHeroLabel => _tokens.onHeroMuted;

  @Deprecated('Use Theme.of(context).finote.onHeroChip')
  Color get dashboardHeroDivider => _tokens.onHeroChip;

  /// First entry stays [primary] so single-slice charts keep the brand color;
  /// transport is skipped because its blue sits too close to primary.
  @Deprecated('Use Theme.of(context).finote.categoryStyle(name).foreground')
  List<Color> get categoryChartColors => [
    primary,
    for (final c in customCategoryPalette)
      if (c != FinoteCategory.transport) _tokens.categories[c]!.foreground,
  ];

  @Deprecated('Use Theme.of(context).finote.categoryStyle(name).foreground')
  Color get categoryChartOtherColor =>
      _tokens.categories[FinoteCategory.other]!.foreground;

  // Design rule: red/green only on amounts, never on icons.
  @Deprecated('Icons use category colors; keep incomeColor for amounts only')
  Color get incomeAccentColor => _tokens.income;

  @Deprecated('Icons use category colors; keep expenseColor for amounts only')
  Color get expenseAccentColor => _tokens.expense;

  /// Color for income amounts.
  Color get incomeColor => _tokens.income;

  /// Color for expense amounts.
  Color get expenseColor => _tokens.expense;

  /// Color for a positive balance value (alias of income).
  Color get positiveBalance => incomeColor;

  /// Color for a negative balance value (alias of expense).
  Color get negativeBalance => expenseColor;

  /// Color for warning badges/indicators.
  Color get warningColor => _tokens.warning;

  /// Color for success badges/indicators.
  Color get successColor => incomeColor;

  /// Returns [incomeColor] or [expenseColor] based on [isExpense].
  Color amountColor({required bool isExpense}) =>
      isExpense ? expenseColor : incomeColor;
}
