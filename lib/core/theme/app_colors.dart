import 'package:flutter/material.dart';

/// Semantic color helpers built on top of the current [ColorScheme].
///
/// Usage: `Theme.of(context).colorScheme.incomeColor`
///
/// Centralises financial color semantics so screens never reference
/// raw palette values directly.
extension AppColors on ColorScheme {
  Color get dashboardHeroColor => brightness == Brightness.light
      ? const Color(0xFF1D2A50)
      : const Color(0xFF30273C);

  Color get dashboardHeroLabel => brightness == Brightness.light
      ? const Color(0xFFBDC9E8)
      : const Color(0xFFEEE7F3);

  Color get dashboardHeroDivider => brightness == Brightness.light
      ? const Color(0xFF465579)
      : const Color(0xFFB8B0C7).withValues(alpha: 0.35);

  List<Color> get categoryChartColors => brightness == Brightness.light
      ? const [
          Color(0xFF4263EB),
          Color(0xFF0D806A),
          Color(0xFF7A92F1),
          Color(0xFF83619B),
          Color(0xFF945C18),
          Color(0xFF415B92),
        ]
      : [primary, secondary, tertiary, incomeColor, warningColor, outline];

  Color get categoryChartOtherColor =>
      brightness == Brightness.light ? const Color(0xFF758096) : outline;

  Color get incomeAccentColor => brightness == Brightness.light
      ? const Color(0xFF0F8B72)
      : const Color(0xFFA5DCC1);

  Color get expenseAccentColor => brightness == Brightness.light
      ? const Color(0xFFC96B63)
      : const Color(0xFFE9A19B);

  /// Color for income amounts and positive-flow indicators.
  Color get incomeColor => brightness == Brightness.light
      ? const Color(0xFF0D806A)
      : const Color(0xFFA5DCC1);

  /// Color for expense amounts and negative-flow indicators.
  Color get expenseColor => brightness == Brightness.light
      ? const Color(0xFFAE534B)
      : const Color(0xFFE9A19B);

  /// Color for a positive balance value (alias of income).
  Color get positiveBalance => incomeColor;

  /// Color for a negative balance value (alias of expense).
  Color get negativeBalance => expenseColor;

  /// Color for warning badges/indicators.
  Color get warningColor => brightness == Brightness.light
      ? const Color(0xFF945C18)
      : const Color(0xFFEBC58B);

  /// Color for success badges/indicators.
  Color get successColor => incomeColor;

  /// Returns [incomeColor] or [expenseColor] based on [isExpense].
  Color amountColor({required bool isExpense}) =>
      isExpense ? expenseColor : incomeColor;
}
