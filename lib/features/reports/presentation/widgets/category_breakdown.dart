import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/finance_tiles.dart';
import '../../data/report_repository.dart';

/// "Pengeluaran/Pemasukan per kategori": one [CategoryBar] per category. Bars
/// use the category color; red/green appears only on the amount.
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTypography.titleSection.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: CategoryBar(
                  name: item.categoryName,
                  fraction: total > 0 ? item.amount / total : 0,
                  amount: item.amount,
                  isExpense: isExpense,
                  maskable: true,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
