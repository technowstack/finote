import 'package:flutter/material.dart';

import 'finote_colors.dart';

/// Legacy semantic color helpers on [ColorScheme], kept so existing screens
/// compile. Values now come from [FinoteColors] (tokens.json).
///
/// New code should read `Theme.of(context).finote` instead.
extension AppColors on ColorScheme {
  FinoteColors get _tokens => FinoteColors.of(brightness);

  // Design rule: red/green only on amounts, never on icons.
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
