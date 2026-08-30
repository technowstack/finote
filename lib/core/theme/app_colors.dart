import 'package:flutter/material.dart';

/// Semantic color helpers built on top of the current [ColorScheme].
///
/// Usage: `Theme.of(context).colorScheme.incomeColor`
///
/// Centralises financial color semantics so screens never reference
/// raw palette values directly.
extension AppColors on ColorScheme {
  /// Color for income amounts and positive-flow indicators.
  Color get incomeColor => brightness == Brightness.light
      ? const Color(0xFF2E7D5B) // soft forest green
      : const Color(0xFF6FCF97); // pastel green

  /// Color for expense amounts and negative-flow indicators.
  Color get expenseColor => brightness == Brightness.light
      ? const Color(0xFFC0392B) // soft coral-red
      : const Color(0xFFEF8E7E); // muted peach-red

  /// Color for a positive balance value (alias of income).
  Color get positiveBalance => incomeColor;

  /// Color for a negative balance value (alias of expense).
  Color get negativeBalance => expenseColor;

  /// Color for warning badges/indicators.
  Color get warningColor => brightness == Brightness.light
      ? const Color(0xFFE2A103) // amber
      : const Color(0xFFF5CC5D); // soft gold

  /// Color for success badges/indicators.
  Color get successColor => incomeColor;

  /// Returns [incomeColor] or [expenseColor] based on [isExpense].
  Color amountColor({required bool isExpense}) =>
      isExpense ? expenseColor : incomeColor;
}
