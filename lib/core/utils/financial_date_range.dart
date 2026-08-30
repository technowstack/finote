enum FinancialPeriod { today, week, month, custom }

class FinancialDateRange {
  const FinancialDateRange({required this.start, required this.end});

  final DateTime start;
  final DateTime end;
}

FinancialDateRange resolveFinancialDateRange(
  FinancialPeriod period, {
  DateTime? now,
  DateTime? customStart,
  DateTime? customEnd,
}) {
  final reference = now ?? DateTime.now();
  final today = DateTime(reference.year, reference.month, reference.day);
  return switch (period) {
    FinancialPeriod.today => FinancialDateRange(start: today, end: today),
    FinancialPeriod.week => FinancialDateRange(
      start: today.subtract(Duration(days: today.weekday - 1)),
      end: today.add(Duration(days: 7 - today.weekday)),
    ),
    FinancialPeriod.month => FinancialDateRange(
      start: DateTime(today.year, today.month),
      end: DateTime(today.year, today.month + 1, 0),
    ),
    FinancialPeriod.custom => _customRange(customStart, customEnd),
  };
}

FinancialDateRange _customRange(DateTime? start, DateTime? end) {
  if (start == null || end == null) {
    throw ArgumentError('Custom date range requires start and end');
  }
  final normalizedStart = DateTime(start.year, start.month, start.day);
  final normalizedEnd = DateTime(end.year, end.month, end.day);
  if (normalizedStart.isAfter(normalizedEnd)) {
    throw ArgumentError('Start date must not be after end date');
  }
  return FinancialDateRange(start: normalizedStart, end: normalizedEnd);
}
