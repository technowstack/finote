import 'package:intl/intl.dart';

import '../domain/report_chart_data.dart';

String formatChartPeriod(DateTime period, ChartGranularity granularity) {
  return switch (granularity) {
    ChartGranularity.day => DateFormat('d MMM', 'id_ID').format(period),
    ChartGranularity.week =>
      '${DateFormat('d MMM', 'id_ID').format(period)} - '
          '${DateFormat('d MMM', 'id_ID').format(period.add(const Duration(days: 6)))}',
    ChartGranularity.month => DateFormat('MMM y', 'id_ID').format(period),
  };
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

String formatChartTooltipPeriod(DateTime period, ChartGranularity granularity) {
  return switch (granularity) {
    ChartGranularity.day => formatChartTooltipDate(period),
    ChartGranularity.week => formatChartPeriod(period, granularity),
    ChartGranularity.month => DateFormat('MMMM y', 'id_ID').format(period),
  };
}
