import 'package:flutter/services.dart';

import '../../../../core/utils/currency_formatter.dart';

class IdrInputFormatter extends TextInputFormatter {
  const IdrInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return const TextEditingValue();
    final amount = int.tryParse(digits);
    if (amount == null) return oldValue;
    final text = formatIdrAmountInput(amount);
    final cursor = newValue.selection.baseOffset.clamp(0, newValue.text.length);
    final digitsBeforeCursor = newValue.text
        .substring(0, cursor)
        .replaceAll(RegExp(r'\D'), '')
        .length;
    var formattedCursor = 0;
    var seenDigits = 0;
    while (formattedCursor < text.length && seenDigits < digitsBeforeCursor) {
      if (RegExp(r'\d').hasMatch(text[formattedCursor])) seenDigits++;
      formattedCursor++;
    }
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: formattedCursor),
    );
  }
}

int parseIdrAmount(String value) =>
    int.tryParse(value.replaceAll(RegExp(r'\D'), '')) ?? 0;

String formatIdrAmountInput(int amount) =>
    formatIdr(amount).replaceFirst('Rp', '');
