import 'package:flutter/material.dart';

import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/currency_formatter.dart';

const _weekdayLabels = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

/// components.md `Kartu/Pengeluaran 7 Hari`. [days] is oldest-first and the
/// last entry is highlighted as today. Totals come from the caller's query,
/// so they reconcile with Reports; this widget never computes finance.
class Expense7DayCard extends StatelessWidget {
  const Expense7DayCard({super.key, required this.days});

  final List<({DateTime day, int expense})> days;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final total = days.fold<int>(0, (sum, d) => sum + d.expense);
    final peak = days.fold<int>(0, (m, d) => d.expense > m ? d.expense : m);
    final semantics = [
      for (final d in days)
        '${_weekdayLabels[d.day.weekday - 1]} ${formatIdr(d.expense)}',
    ].join(', ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pengeluaran 7 hari', style: theme.textTheme.bodySmall),
            const SizedBox(height: AppSpacing.xs),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                formatIdr(total),
                style: AppTypography.amountLg.copyWith(color: colors.onSurface),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Semantics(
              label: 'Pengeluaran harian: $semantics',
              child: ExcludeSemantics(
                child: Row(
                  children: [
                    for (var i = 0; i < days.length; i++)
                      Expanded(
                        child: _DayBar(
                          label: _weekdayLabels[days[i].day.weekday - 1],
                          ratio: peak == 0 ? 0 : days[i].expense / peak,
                          isToday: i == days.length - 1,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (total == 0) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Belum ada pengeluaran 7 hari terakhir.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DayBar extends StatelessWidget {
  const _DayBar({
    required this.label,
    required this.ratio,
    required this.isToday,
  });

  final String label;
  final double ratio;
  final bool isToday;

  static const _barArea = 56.0;
  static const _minBar = 6.0;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        SizedBox(
          height: _barArea,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: 24,
              height: _minBar + (_barArea - _minBar) * ratio,
              decoration: BoxDecoration(
                color: isToday ? colors.primary : colors.primaryContainer,
                borderRadius: AppRadius.smAll,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style:
                (isToday
                        ? AppTypography.captionSemibold
                        : AppTypography.captionRegular)
                    .copyWith(
                      color: isToday
                          ? colors.onSurface
                          : colors.onSurfaceVariant,
                    ),
          ),
        ),
      ],
    );
  }
}
