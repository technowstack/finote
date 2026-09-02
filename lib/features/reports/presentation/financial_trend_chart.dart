import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../domain/report_chart_data.dart';
import 'report_chart_formatters.dart';

class FinancialTrendChart extends StatelessWidget {
  const FinancialTrendChart({
    super.key,
    required this.points,
    required this.granularity,
  });

  final List<FinancialTrendPoint> points;
  final ChartGranularity granularity;

  @override
  Widget build(BuildContext context) {
    if (!hasFinancialTrendData(points)) {
      return const AppEmptyState(
        icon: Icons.show_chart,
        message: 'Belum ada data tren pada periode ini.',
      );
    }

    final colors = Theme.of(context).colorScheme;
    final values = [
      for (final point in points) ...[point.income, point.expense, point.net],
    ];
    final lowest = min(0, values.reduce(min)).toDouble();
    final highest = max(0, values.reduce(max)).toDouble();
    final span = highest - lowest;
    final minY = lowest < 0 ? lowest - span * 0.08 : 0.0;
    final maxY = highest + span * 0.08;
    final yInterval = (maxY - minY) / 4;
    final labelEvery = max(1, (points.length / 6).ceil());
    final showDots = points.length <= 31;
    final lineBars = [
      _line(points, (point) => point.income, colors.incomeColor, dash: [8, 4]),
      _line(
        points,
        (point) => point.expense,
        colors.expenseColor,
        dash: [3, 3],
      ),
      _line(
        points,
        (point) => point.net,
        colors.primary,
        width: 3,
        showDots: showDots,
      ),
    ];

    return Semantics(
      container: true,
      label: _semanticLabel(),
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: Column(
            children: [
              Wrap(
                alignment: WrapAlignment.center,
                spacing: AppSpacing.lg,
                runSpacing: AppSpacing.xs,
                children: [
                  _LegendItem(
                    icon: Icons.show_chart,
                    label: 'Net',
                    color: colors.primary,
                  ),
                  _LegendItem(
                    icon: Icons.trending_up,
                    label: 'Pemasukan',
                    color: colors.incomeColor,
                  ),
                  _LegendItem(
                    icon: Icons.trending_down,
                    label: 'Pengeluaran',
                    color: colors.expenseColor,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: LineChart(
                  LineChartData(
                    minX: 0,
                    maxX: max(1, points.length - 1).toDouble(),
                    minY: minY,
                    maxY: maxY,
                    lineBarsData: lineBars,
                    clipData: const FlClipData.all(),
                    extraLinesData: ExtraLinesData(
                      horizontalLines: [
                        HorizontalLine(
                          y: 0,
                          color: colors.onSurfaceVariant.withValues(alpha: 0.7),
                          strokeWidth: 1.5,
                          dashArray: [6, 4],
                        ),
                      ],
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: Border(
                        left: BorderSide(color: colors.outlineVariant),
                        bottom: BorderSide(color: colors.outlineVariant),
                      ),
                    ),
                    gridData: FlGridData(
                      drawVerticalLine: false,
                      horizontalInterval: yInterval,
                      getDrawingHorizontalLine: (_) => FlLine(
                        color: colors.outlineVariant.withValues(alpha: 0.45),
                        strokeWidth: 1,
                      ),
                    ),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 64,
                          interval: yInterval,
                          getTitlesWidget: (value, meta) => SideTitleWidget(
                            meta: meta,
                            space: 6,
                            child: Text(
                              formatCompactIdr(value.round()),
                              maxLines: 1,
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 34,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (value != index ||
                                index < 0 ||
                                index >= points.length ||
                                (index % labelEvery != 0 &&
                                    index != points.length - 1)) {
                              return const SizedBox.shrink();
                            }
                            return SideTitleWidget(
                              meta: meta,
                              space: 6,
                              fitInside: SideTitleFitInsideData.fromTitleMeta(
                                meta,
                              ),
                              child: Text(
                                formatChartAxisPeriod(
                                  points[index].period,
                                  granularity,
                                  pointCount: points.length,
                                ),
                                maxLines: 1,
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        maxContentWidth: 220,
                        fitInsideHorizontally: true,
                        fitInsideVertically: true,
                        getTooltipColor: (_) => colors.inverseSurface,
                        getTooltipItems: (touchedSpots) {
                          final index = touchedSpots.first.x.round().clamp(
                            0,
                            points.length - 1,
                          );
                          final point = points[index];
                          final style = Theme.of(context).textTheme.labelMedium!
                              .copyWith(color: colors.onInverseSurface);
                          return [
                            LineTooltipItem(
                              '${formatChartTooltipPeriod(point.period, granularity)}\n',
                              style.copyWith(fontWeight: FontWeight.w700),
                              children: [
                                TextSpan(
                                  text:
                                      'Pemasukan  ${formatIdr(point.income)}\n',
                                  style: style,
                                ),
                                TextSpan(
                                  text:
                                      'Pengeluaran  ${formatIdr(point.expense)}\n',
                                  style: style,
                                ),
                                TextSpan(
                                  text: 'Net  ${formatIdr(point.net)}',
                                  style: style.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            for (var i = 1; i < touchedSpots.length; i++) null,
                          ];
                        },
                      ),
                    ),
                  ),
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 200),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _semanticLabel() {
    final values = points
        .where((point) => point.income != 0 || point.expense != 0)
        .map(
          (point) =>
              '${formatChartTooltipPeriod(point.period, granularity)}: '
              'Pemasukan ${formatIdr(point.income)}, '
              'Pengeluaran ${formatIdr(point.expense)}, '
              'Net ${formatIdr(point.net)}',
        );
    return 'Tren Keuangan. ${values.join('. ')}';
  }
}

bool hasFinancialTrendData(List<FinancialTrendPoint> points) =>
    points.any((point) => point.income != 0 || point.expense != 0);

LineChartBarData _line(
  List<FinancialTrendPoint> points,
  int Function(FinancialTrendPoint point) value,
  Color color, {
  double width = 1.5,
  List<int>? dash,
  bool showDots = false,
}) {
  return LineChartBarData(
    spots: [
      for (final (index, point) in points.indexed)
        FlSpot(index.toDouble(), value(point).toDouble()),
    ],
    color: color,
    barWidth: width,
    dashArray: dash,
    isStrokeCapRound: true,
    isStrokeJoinRound: true,
    dotData: FlDotData(show: showDots),
  );
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: AppSpacing.xs),
        Text(label, style: Theme.of(context).textTheme.labelLarge),
      ],
    );
  }
}
