import 'package:flutter/material.dart';

/// Semantic color helpers built on top of the current [ColorScheme].
///
/// Usage: `Theme.of(context).colorScheme.incomeColor`
///
/// Centralises financial color semantics so screens never reference
/// raw palette values directly.
extension AppColors on ColorScheme {
  Color get incomeAccentColor => brightness == Brightness.light
      ? const Color(0xFF00896C)
      : const Color(0xFFA5DCC1);

  Color get expenseAccentColor => brightness == Brightness.light
      ? const Color(0xFFC5685A)
      : const Color(0xFFE9A19B);

  /// Color for income amounts and positive-flow indicators.
  Color get incomeColor => brightness == Brightness.light
      ? const Color(0xFF007A60)
      : const Color(0xFFA5DCC1);

  /// Color for expense amounts and negative-flow indicators.
  Color get expenseColor => brightness == Brightness.light
      ? const Color(0xFFA84F43)
      : const Color(0xFFE9A19B);

  /// Color for a positive balance value (alias of income).
  Color get positiveBalance => incomeColor;

  /// Color for a negative balance value (alias of expense).
  Color get negativeBalance => expenseColor;

  /// Color for warning badges/indicators.
  Color get warningColor => brightness == Brightness.light
      ? const Color(0xFF8E612E)
      : const Color(0xFFEBC58B);

  /// Color for success badges/indicators.
  Color get successColor => incomeColor;

  /// Returns [incomeColor] or [expenseColor] based on [isExpense].
  Color amountColor({required bool isExpense}) =>
      isExpense ? expenseColor : incomeColor;
}
