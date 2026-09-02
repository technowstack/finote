import 'package:flutter/material.dart';

import '../../../core/utils/financial_date_range.dart';
import '../data/report_repository.dart';

enum ReportPeriod { all, today, week, month, year, custom }

ReportRange resolveReportRange(
  ReportPeriod period, {
  DateTimeRange? customRange,
  DateTime? now,
}) {
  final reference = now ?? DateTime.now();
  final periodRange = switch (period) {
    ReportPeriod.all || ReportPeriod.year => null,
    ReportPeriod.today => resolveFinancialDateRange(
      FinancialPeriod.today,
      now: reference,
    ),
    ReportPeriod.week => resolveFinancialDateRange(
      FinancialPeriod.week,
      now: reference,
    ),
    ReportPeriod.month => resolveFinancialDateRange(
      FinancialPeriod.month,
      now: reference,
    ),
    ReportPeriod.custom => resolveFinancialDateRange(
      FinancialPeriod.custom,
      now: reference,
      customStart: customRange?.start,
      customEnd: customRange?.end,
    ),
  };
  return switch (period) {
    ReportPeriod.all => ReportRange(
      start: DateTime(2000),
      end: DateTime(2100, 12, 31),
    ),
    ReportPeriod.year => ReportRange(
      start: DateTime(reference.year),
      end: DateTime(reference.year, 12, 31),
    ),
    _ => ReportRange(start: periodRange!.start, end: periodRange.end),
  };
}

ReportPeriod reportPeriodForRange(ReportRange range, {DateTime? now}) {
  for (final period in [
    ReportPeriod.all,
    ReportPeriod.today,
    ReportPeriod.week,
    ReportPeriod.month,
    ReportPeriod.year,
  ]) {
    if (resolveReportRange(period, now: now) == range) return period;
  }
  return ReportPeriod.custom;
}
