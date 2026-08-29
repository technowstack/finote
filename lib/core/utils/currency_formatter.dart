import 'package:intl/intl.dart';

final _idrFormatter = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp',
  decimalDigits: 0,
);

String formatIdr(int amount) => _idrFormatter.format(amount);
