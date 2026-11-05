import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/shared_widgets.dart';
import '../../../transactions/domain/transaction_type.dart';
import '../../data/report_repository.dart';

class ReportHistoryTab extends StatelessWidget {
  const ReportHistoryTab({super.key, required this.data});

  final ReportData data;

  @override
  Widget build(BuildContext context) {
    if (data.monthlyHistory.isEmpty) {
      return const AppEmptyState(
        icon: Icons.calendar_month_outlined,
        message: 'Belum ada riwayat bulanan.',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.sm,
        AppSpacing.screenH,
        AppSpacing.xxl,
      ),
      children: [
        Card(
          child: Column(
            children: [
              for (var i = 0; i < data.monthlyHistory.length; i++) ...[
                _MonthlyRow(
                  month: data.monthlyHistory[i],
                  onTap: () => context.push(
                    '/reports/history/${data.monthlyHistory[i].month}',
                  ),
                ),
                if (i < data.monthlyHistory.length - 1)
                  const Divider(indent: 16, endIndent: 16),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MonthlyRow extends StatelessWidget {
  const _MonthlyRow({required this.month, required this.onTap});

  final MonthlyTotal month;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isPositive = month.netBalance >= 0;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_formatMonth(month.month), style: textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Income and expense wrap onto a second line instead of
                      // overflowing on narrow screens or large text.
                      Expanded(
                        child: Wrap(
                          spacing: AppSpacing.lg,
                          runSpacing: AppSpacing.xs,
                          children: [
                            CurrencyText(
                              amount: month.income,
                              type: TransactionType.income,
                              maskable: true,
                              alignment: Alignment.centerLeft,
                              style: AppTypography.amountSm,
                            ),
                            CurrencyText(
                              amount: month.expense,
                              type: TransactionType.expense,
                              maskable: true,
                              alignment: Alignment.centerLeft,
                              style: AppTypography.amountSm,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 140),
                        child: CurrencyText(
                          amount: month.netBalance,
                          maskable: true,
                          style: AppTypography.amountMd.copyWith(
                            color: isPositive
                                ? colors.positiveBalance
                                : colors.negativeBalance,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

String _formatMonth(String month) =>
    DateFormat('MMMM y', 'id_ID').format(DateTime.parse('$month-01'));
