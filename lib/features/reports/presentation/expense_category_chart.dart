import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../domain/report_chart_data.dart';

const maxVisibleExpenseCategories = 5;

List<CategoryChartPoint> visibleExpenseCategories(
  List<CategoryChartPoint> points,
) {
  if (points.length <= maxVisibleExpenseCategories) return points;
  final otherAmount = points
      .skip(maxVisibleExpenseCategories)
      .fold<int>(0, (sum, point) => sum + point.amount);
  return [
    ...points.take(maxVisibleExpenseCategories),
    CategoryChartPoint(
      categoryId: -1,
      categoryName: 'Lainnya',
      amount: otherAmount,
    ),
  ];
}

class ExpenseCategoryChart extends StatefulWidget {
  const ExpenseCategoryChart({super.key, required this.points});

  final List<CategoryChartPoint> points;

  @override
  State<ExpenseCategoryChart> createState() => _ExpenseCategoryChartState();
}

class _ExpenseCategoryChartState extends State<ExpenseCategoryChart> {
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    final points = visibleExpenseCategories(widget.points);
    final total = widget.points.fold<int>(
      0,
      (sum, point) => sum + point.amount,
    );
    if (points.isEmpty || total <= 0) {
      return const AppEmptyState(
        icon: Icons.donut_large,
        message: 'Belum ada pengeluaran pada periode ini.',
      );
    }

    final colors = Theme.of(context).colorScheme;
    final palette = [
      colors.primary,
      colors.secondary,
      colors.tertiary,
      colors.incomeColor,
      colors.warningColor,
      colors.outline,
    ];
    final selected = _touchedIndex != null && _touchedIndex! < points.length
        ? points[_touchedIndex!]
        : null;
    final selectedPercent = selected == null
        ? 0
        : (selected.amount * 100 / total).round();

    return Semantics(
      container: true,
      label: _semanticLabel(points, total),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            SizedBox(
              height: 230,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      sectionsSpace: 3,
                      centerSpaceRadius: 58,
                      centerSpaceColor: colors.surface,
                      sections: [
                        for (final (index, point) in points.indexed)
                          PieChartSectionData(
                            value: point.amount.toDouble(),
                            color:
                                index == points.length - 1 &&
                                    point.categoryId == -1
                                ? colors.outline
                                : palette[index % palette.length],
                            radius: index == _touchedIndex ? 70 : 62,
                            showTitle: false,
                          ),
                      ],
                      pieTouchData: PieTouchData(
                        touchCallback: (event, response) {
                          final index =
                              response?.touchedSection?.touchedSectionIndex;
                          if (index == null || index < 0) {
                            if (_touchedIndex != null) {
                              setState(() => _touchedIndex = null);
                            }
                            return;
                          }
                          if (_touchedIndex != index) {
                            setState(() => _touchedIndex = index);
                          }
                        },
                      ),
                    ),
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 200),
                  ),
                  IgnorePointer(
                    child: _CenterSummary(
                      name: selected?.categoryName,
                      amount: selected?.amount ?? total,
                      percent: selected == null ? null : selectedPercent,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final (index, point) in points.indexed)
              _CategoryRow(
                point: point,
                total: total,
                color: index == points.length - 1 && point.categoryId == -1
                    ? colors.outline
                    : palette[index % palette.length],
                selected: index == _touchedIndex,
                onTap: () => setState(() {
                  _touchedIndex = _touchedIndex == index ? null : index;
                }),
              ),
          ],
        ),
      ),
    );
  }

  String _semanticLabel(List<CategoryChartPoint> points, int total) {
    return 'Pengeluaran per Kategori. Total ${formatIdr(total)}. '
        '${points.map((point) => '${point.categoryName}, ${formatIdr(point.amount)}, ${(point.amount * 100 / total).round()} persen').join('. ')}';
  }
}

class _CenterSummary extends StatelessWidget {
  const _CenterSummary({this.name, required this.amount, this.percent});

  final String? name;
  final int amount;
  final int? percent;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          formatCompactIdr(amount),
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        Text(name ?? 'Pengeluaran', style: textTheme.labelSmall),
        if (percent != null) Text('$percent%', style: textTheme.labelSmall),
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.point,
    required this.total,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final CategoryChartPoint point;
  final int total;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final percent = (point.amount * 100 / total).round();
    return Semantics(
      button: true,
      label:
          '${point.categoryName}, $percent persen, ${formatIdr(point.amount)}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  point.categoryName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(fontWeight: selected ? FontWeight.w700 : null),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text('$percent%', style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(width: AppSpacing.md),
              Flexible(
                child: Text(
                  formatIdr(point.amount),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.expenseColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
