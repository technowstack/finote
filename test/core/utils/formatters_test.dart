import 'package:flutter_test/flutter_test.dart';
import 'package:finote/core/errors/error_mapper.dart';
import 'package:finote/core/utils/currency_formatter.dart';
import 'package:finote/core/utils/date_formatter.dart';
import 'package:finote/core/utils/uuid_generator.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  test('core utilities produce application-safe values', () {
    expect(formatIdr(1250000), 'Rp1.250.000');
    expect(formatDate(DateTime(2026, 8, 29)), '29 Agustus 2026');
    expect(generateUuid(), matches(RegExp(r'^[0-9a-f-]{36}$')));
    expect(
      mapErrorToMessage(const FormatException()),
      'Data yang dimasukkan tidak valid.',
    );
    expect(mapErrorToMessage(Exception()), contains('Silakan coba lagi'));
  });
}
