import 'package:flutter_test/flutter_test.dart';
import 'package:finote/core/errors/error_mapper.dart';
import 'package:finote/core/utils/currency_formatter.dart';
import 'package:finote/core/utils/date_formatter.dart';
import 'package:finote/core/utils/uuid_generator.dart';
import 'package:finote/features/reports/domain/report_chart_data.dart';
import 'package:finote/features/reports/presentation/report_chart_formatters.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  test('core utilities produce application-safe values', () {
    expect(formatIdr(1250000), 'Rp1.250.000');
    expect(formatCompactIdr(500000), 'Rp500 rb');
    expect(formatCompactIdr(1500000), 'Rp1,5 jt');
    expect(formatCompactIdr(1000000000), 'Rp1 M');
    expect(formatCompactIdr(-10000000), '-Rp10 jt');
    expect(
      formatChartPeriod(DateTime(2026, 8, 12), ChartGranularity.day),
      '12 Agu',
    );
    expect(formatChartTooltipDate(DateTime(2026, 8, 12)), '12 Agustus 2026');
    expect(formatDate(DateTime(2026, 8, 29)), '29 Agustus 2026');
    expect(generateUuid(), matches(RegExp(r'^[0-9a-f-]{36}$')));
    expect(
      mapErrorToMessage(const FormatException()),
      'Data yang dimasukkan tidak valid.',
    );
    expect(mapErrorToMessage(Exception()), contains('Silakan coba lagi'));
  });
}
