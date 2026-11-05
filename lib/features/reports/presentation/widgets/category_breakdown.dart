import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../data/report_repository.dart';

class CategoryBreakdown extends StatelessWidget {
  const CategoryBreakdown({
    super.key,
    required this.title,
    required this.items,
    required this.total,
    required this.isExpense,
  });

  final String title;
  final List<CategoryTotal> items;
  final int total;
  final bool isExpense;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final barColor = isExpense ? colors.expenseColor : colors.incomeColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        Card(
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                _CategoryRow(
                  item: items[i],
                  fraction: total > 0 ? items[i].amount / total : 0,
                  barColor: barColor,
                  isExpense: isExpense,
                ),
                if (i < items.length - 1)
                  const Divider(indent: 16, endIndent: 16),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.item,
    required this.fraction,
    required this.barColor,
    required this.isExpense,
  });

  final CategoryTotal item;
  final double fraction;
  final Color barColor;
  final bool isExpense;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(item.categoryName, style: textTheme.bodyLarge),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '${(fraction * 100).round()}%',
                style: textTheme.labelMedium,
              ),
              const SizedBox(width: AppSpacing.sm),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 120),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    formatIdr(item.amount),
                    style: textTheme.titleMedium?.copyWith(
                      color: colors.amountColor(isExpense: isExpense),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: fraction.clamp(0, 1).toDouble(),
              backgroundColor: barColor.withValues(alpha: 0.12),
              color: barColor,
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
}
