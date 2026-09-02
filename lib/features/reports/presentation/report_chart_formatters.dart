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
