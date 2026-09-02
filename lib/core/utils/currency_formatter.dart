import 'package:intl/intl.dart';

final _idrFormatter = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp',
  decimalDigits: 0,
);

String formatIdr(int amount) => _idrFormatter.format(amount);

String formatCompactIdr(int amount) {
  final absolute = amount.abs();
  final (divisor, suffix) = switch (absolute) {
    >= 1000000000 => (1000000000, 'M'),
    >= 1000000 => (1000000, 'jt'),
    >= 1000 => (1000, 'rb'),
    _ => (1, ''),
  };
  if (divisor == 1) return formatIdr(amount);
  final compact = NumberFormat('0.#', 'id_ID').format(amount / divisor);
  return 'Rp$compact $suffix';
}
