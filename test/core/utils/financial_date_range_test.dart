import 'package:finote/core/utils/financial_date_range.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final reference = DateTime(2026, 8, 30); // Sunday

  test('uses inclusive Monday-to-Sunday weeks', () {
    final range = resolveFinancialDateRange(
      FinancialPeriod.week,
      now: reference,
    );
    expect(range.start, DateTime(2026, 8, 24));
    expect(range.end, DateTime(2026, 8, 30));
  });

  test('normalizes custom dates and rejects reversed ranges', () {
    final range = resolveFinancialDateRange(
      FinancialPeriod.custom,
      customStart: DateTime(2026, 8, 1, 23),
      customEnd: DateTime(2026, 8, 31, 23),
    );
    expect(range.start, DateTime(2026, 8, 1));
    expect(range.end, DateTime(2026, 8, 31));

    expect(
      () => resolveFinancialDateRange(
        FinancialPeriod.custom,
        customStart: DateTime(2026, 8, 31),
        customEnd: DateTime(2026, 8, 1),
      ),
      throwsArgumentError,
    );
  });

  test('handles month and year boundaries', () {
    final month = resolveFinancialDateRange(
      FinancialPeriod.month,
      now: DateTime(2026, 12, 15),
    );
    expect(month.start, DateTime(2026, 12, 1));
    expect(month.end, DateTime(2026, 12, 31));
    final next = resolveFinancialDateRange(
      FinancialPeriod.month,
      now: DateTime(2027, 1, 15),
    );
    expect(next.start, DateTime(2027, 1, 1));
    expect(next.end, DateTime(2027, 1, 31));
  });
}
