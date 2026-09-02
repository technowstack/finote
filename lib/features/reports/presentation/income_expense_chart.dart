import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../data/report_repository.dart';
import '../domain/report_chart_data.dart';
import 'report_chart_formatters.dart';

class IncomeExpenseChart extends StatelessWidget {
  const IncomeExpenseChart({
    super.key,
    required this.points,
    required this.granularity,
    this.range,
  });

  final List<FinancialTrendPoint> points;
  final ChartGranularity granularity;
  final ReportRange? range;

  @override
  Widget build(BuildContext context) {
    if (!hasIncomeExpenseData(points)) {
      return const AppEmptyState(
        icon: Icons.bar_chart_outlined,
        message: 'Belum ada transaksi pada periode ini.',
      );
    }

    final colors = Theme.of(context).colorScheme;
    final maxAmount = points.fold<int>(
      0,
      (current, point) => max(current, max(point.income, point.expense)),
    );
    final maxY = maxAmount.toDouble() * 1.15;
    final yInterval = maxY / 4;
    final labelEvery = max(1, (points.length / 6).ceil());

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
                    icon: Icons.south_west,
                    label: 'Pemasukan',
                    color: colors.incomeColor,
                  ),
                  _LegendItem(
                    icon: Icons.north_east,
                    label: 'Pengeluaran',
                    color: colors.expenseColor,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final plotWidth = max(1.0, constraints.maxWidth - 58);
                    final rodWidth = (plotWidth / points.length / 3.5).clamp(
                      0.05,
                      12.0,
                    );
                    return BarChart(
                      BarChartData(
                        minY: 0,
                        maxY: maxY,
                        alignment: BarChartAlignment.spaceAround,
                        groupsSpace: 0,
                        barGroups: [
                          for (final (index, point) in points.indexed)
                            BarChartGroupData(
                              x: index,
                              barsSpace: rodWidth * 0.25,
                              barRods: [
                                _rod(
                                  point.income,
                                  colors.incomeColor,
                                  rodWidth,
                                ),
                                _rod(
                                  point.expense,
                                  colors.expenseColor,
                                  rodWidth,
                                ),
                              ],
                            ),
                        ],
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
                            color: colors.outlineVariant.withValues(alpha: 0.5),
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
                              reservedSize: 58,
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
                                if (index < 0 || index >= points.length) {
                                  return const SizedBox.shrink();
                                }
                                if (index % labelEvery != 0 &&
                                    index != points.length - 1) {
                                  return const SizedBox.shrink();
                                }
                                return SideTitleWidget(
                                  meta: meta,
                                  space: 6,
                                  fitInside:
                                      SideTitleFitInsideData.fromTitleMeta(
                                        meta,
                                      ),
                                  child: Text(
                                    formatChartAxisPeriod(
                                      points[index].period,
                                      granularity,
                                      pointCount: points.length,
                                    ),
                                    maxLines: 1,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        barTouchData: BarTouchData(
                          enabled: true,
                          touchTooltipData: BarTouchTooltipData(
                            maxContentWidth: 180,
                            fitInsideHorizontally: true,
                            fitInsideVertically: true,
                            getTooltipColor: (_) => colors.inverseSurface,
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              final point = points[group.x];
                              final baseStyle = Theme.of(context)
                                  .textTheme
                                  .labelMedium!
                                  .copyWith(color: colors.onInverseSurface);
                              return BarTooltipItem(
                                '${formatChartTooltipPeriod(point.period, granularity, range: range)}\n',
                                baseStyle.copyWith(fontWeight: FontWeight.w700),
                                children: [
                                  TextSpan(
                                    text: '+ Pemasukan  ',
                                    style: baseStyle,
                                  ),
                                  TextSpan(
                                    text: '${formatIdr(point.income)}\n',
                                    style: baseStyle,
                                  ),
                                  TextSpan(
                                    text: '- Pengeluaran  ',
                                    style: baseStyle,
                                  ),
                                  TextSpan(
                                    text: formatIdr(point.expense),
                                    style: baseStyle,
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 200),
                    );
                  },
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
              '${formatChartTooltipPeriod(point.period, granularity, range: range)}: '
              'Pemasukan ${formatIdr(point.income)}, '
              'Pengeluaran ${formatIdr(point.expense)}',
        );
    return 'Pemasukan versus Pengeluaran. ${values.join('. ')}';
  }
}

bool hasIncomeExpenseData(List<FinancialTrendPoint> points) =>
    points.any((point) => point.income != 0 || point.expense != 0);

BarChartRodData _rod(int amount, Color color, double width) {
  return BarChartRodData(
    toY: amount.toDouble(),
    color: color,
    width: width,
    borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
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
