import 'package:flutter/material.dart';

/// Semantic color helpers built on top of the current [ColorScheme].
///
/// Usage: `Theme.of(context).colorScheme.incomeColor`
///
/// These keep financial color semantics in one place instead of
/// repeating `colorScheme.primary` / `colorScheme.error` ad-hoc.
extension AppColors on ColorScheme {
  /// Color for income amounts and indicators.
  Color get incomeColor => primary;

  /// Color for expense amounts and indicators.
  Color get expenseColor => error;

  /// Color for a positive balance value.
  Color get positiveBalance => primary;

  /// Color for a negative balance value.
  Color get negativeBalance => error;

  /// Returns [incomeColor] or [expenseColor] based on [isExpense].
  Color amountColor({required bool isExpense}) =>
      isExpense ? expenseColor : incomeColor;
}
