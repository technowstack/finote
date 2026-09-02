import 'package:intl/intl.dart';

import '../data/report_repository.dart';
import '../domain/report_chart_data.dart';

String formatChartPeriod(DateTime period, ChartGranularity granularity) {
  return switch (granularity) {
    ChartGranularity.day => DateFormat('d MMM', 'id_ID').format(period),
    ChartGranularity.week => _formatWeek(period),
    ChartGranularity.month => DateFormat('MMM y', 'id_ID').format(period),
  };
}

String _formatWeek(DateTime period) {
  final end = period.add(const Duration(days: 6));
  final pattern = period.year == end.year ? 'd MMM' : 'd MMM y';
  final format = DateFormat(pattern, 'id_ID');
  return '${format.format(period)} - ${format.format(end)}';
}

String formatChartTooltipDate(DateTime date) =>
    DateFormat('d MMMM y', 'id_ID').format(date);

String formatChartAxisPeriod(
  DateTime period,
  ChartGranularity granularity, {
  required int pointCount,
}) {
  return switch (granularity) {
    ChartGranularity.day when pointCount == 7 => DateFormat(
      'E',
      'id_ID',
    ).format(period),
    ChartGranularity.day ||
    ChartGranularity.week => DateFormat('d MMM', 'id_ID').format(period),
    ChartGranularity.month => DateFormat('MMM', 'id_ID').format(period),
  };
}

String formatChartTooltipPeriod(
  DateTime period,
  ChartGranularity granularity, {
  ReportRange? range,
}) {
  if (range != null && granularity != ChartGranularity.day) {
    final bucketEnd = granularity == ChartGranularity.week
        ? period.add(const Duration(days: 6))
        : DateTime(
            period.year,
            period.month + 1,
          ).subtract(const Duration(days: 1));
    final start = period.isBefore(range.start) ? range.start : period;
    final end = bucketEnd.isAfter(range.end) ? range.end : bucketEnd;
    if (start != period || end != bucketEnd) {
      final format = DateFormat('d MMM y', 'id_ID');
      return '${format.format(start)} - ${format.format(end)}';
    }
  }
  return switch (granularity) {
    ChartGranularity.day => formatChartTooltipDate(period),
    ChartGranularity.week => formatChartPeriod(period, granularity),
    ChartGranularity.month => DateFormat('MMMM y', 'id_ID').format(period),
  };
}
