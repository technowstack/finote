import 'package:flutter/material.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/finote_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/finance_tiles.dart';
import '../../../../core/widgets/finote_controls.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../domain/transaction_type.dart';

class TransactionTypeToggle extends StatelessWidget {
  const TransactionTypeToggle({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final TransactionType value;
  final ValueChanged<TransactionType> onChanged;

  @override
  Widget build(BuildContext context) {
    return FinoteSegmented<TransactionType>(
      segments: const [
        FinoteSegment(TransactionType.expense, 'Pengeluaran'),
        FinoteSegment(TransactionType.income, 'Pemasukan'),
      ],
      selected: value,
      onChanged: onChanged,
    );
  }
}

// ---------------------------------------------------------------------------
// Category picker
// ---------------------------------------------------------------------------

class TransactionCategoryGrid extends StatelessWidget {
  const TransactionCategoryGrid({
    super.key,
    required this.categories,
    required this.selectedId,
    required this.isExpense,
    required this.onSelected,
  });

  final List<CategoryRecord> categories;
  final int? selectedId;
  final bool isExpense;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Text('Belum ada kategori.'),
      );
    }
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final category in categories)
          Semantics(
            button: true,
            selected: category.id == selectedId,
            child: InkWell(
              borderRadius: AppRadius.mdAll,
              onTap: () => onSelected(category.id),
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: category.id == selectedId
                      ? colors.primaryContainer
                      : Colors.transparent,
                  borderRadius: AppRadius.mdAll,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CategoryIconTile(
                      style: theme.finote.categoryStyle(category.name),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(
                      child: Text(
                        category.name,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.labelMd.copyWith(
                          color: category.id == selectedId
                              ? colors.onPrimaryContainer
                              : colors.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class TransactionDateChip extends StatelessWidget {
  const TransactionDateChip({
    super.key,
    required this.date,
    required this.onTap,
  });

  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;

    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        icon: const Icon(Icons.calendar_today_outlined, size: 16),
        label: Text(isToday ? 'Hari ini' : formatDate(date)),
        onPressed: onTap,
      ),
    );
  }
}

class OptionalFieldsSection extends StatelessWidget {
  const OptionalFieldsSection({
    super.key,
    required this.titleController,
    required this.noteController,
    required this.initiallyExpanded,
  });

  final TextEditingController titleController;
  final TextEditingController noteController;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      initiallyExpanded: initiallyExpanded,
      shape: const Border(),
      collapsedShape: const Border(),
      title: Text(
        'Judul dan catatan',
        style: Theme.of(context).textTheme.titleSmall,
      ),
      subtitle: const Text('Opsional'),
      childrenPadding: const EdgeInsets.only(bottom: AppSpacing.sm),
      children: [
        const SizedBox(height: AppSpacing.md),
        TextFormField(
          controller: titleController,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Judul'),
        ),
        const SizedBox(height: AppSpacing.md),
        TextFormField(
          controller: noteController,
          textCapitalization: TextCapitalization.sentences,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Catatan'),
        ),
      ],
    );
  }
}
