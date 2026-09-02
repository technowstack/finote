import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../domain/report_chart_data.dart';

const maxVisibleExpenseCategories = 6;

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

class ExpenseCategoryChart extends StatelessWidget {
  const ExpenseCategoryChart({super.key, required this.points});

  final List<CategoryChartPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const AppEmptyState(
        icon: Icons.bar_chart_outlined,
        message: 'Belum ada pengeluaran pada periode ini.',
      );
    }

    final maxAmount = points.fold<int>(
      0,
      (value, point) => max(value, point.amount),
    );
    if (maxAmount <= 0) {
      return const AppEmptyState(
        icon: Icons.bar_chart_outlined,
        message: 'Belum ada pengeluaran pada periode ini.',
      );
    }
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final point in points)
            _CategoryBar(point: point, maxAmount: maxAmount),
        ],
      ),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({required this.point, required this.maxAmount});

  final CategoryChartPoint point;
  final int maxAmount;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      label: '${point.categoryName}, ${formatIdr(point.amount)}',
      child: Tooltip(
        message: '${point.categoryName}\n${formatIdr(point.amount)}',
        child: ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        point.categoryName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Text(
                      formatCompactIdr(point.amount),
                      maxLines: 1,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: colors.expenseColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    height: 8,
                    child: LayoutBuilder(
                      builder: (context, constraints) => Stack(
                        children: [
                          ColoredBox(
                            color: colors.expenseColor.withValues(alpha: 0.12),
                            child: const SizedBox.expand(),
                          ),
                          SizedBox(
                            width:
                                constraints.maxWidth * point.amount / maxAmount,
                            child: ColoredBox(color: colors.expenseColor),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
