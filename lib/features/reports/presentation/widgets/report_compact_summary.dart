import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../data/report_repository.dart';

class CompactSummary extends StatelessWidget {
  const CompactSummary({super.key, required this.data});

  final ReportData data;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Saldo periode',
            style: textTheme.labelLarge?.copyWith(
              color: colors.onSecondaryContainer.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatIdr(data.netBalance),
              style: textTheme.displayMedium?.copyWith(
                color: colors.onSecondaryContainer,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Icon(Icons.south_west, size: 14, color: colors.incomeColor),
              const SizedBox(width: AppSpacing.xs),
              Text(
                formatIdr(data.totalIncome),
                style: textTheme.titleMedium?.copyWith(
                  color: colors.incomeColor,
                ),
              ),
              const SizedBox(width: AppSpacing.xl),
              Icon(Icons.north_east, size: 14, color: colors.expenseColor),
              const SizedBox(width: AppSpacing.xs),
              Text(
                formatIdr(data.totalExpense),
                style: textTheme.titleMedium?.copyWith(
                  color: colors.expenseColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
