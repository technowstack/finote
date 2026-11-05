import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/finote_colors.dart';
import '../../../../core/widgets/finote_hero.dart';
import '../../data/report_repository.dart';

/// "Saldo periode": period cashflow in the same hero style as the Beranda
/// net-worth card. It is explicitly *not* total wealth, which is why the
/// caption says so; Posisi saat ini below is the point-in-time number.
class CompactSummary extends StatelessWidget {
  const CompactSummary({super.key, required this.data});

  final ReportData data;

  @override
  Widget build(BuildContext context) {
    final f = Theme.of(context).finote;
    return FinoteHero(
      title: 'Saldo periode',
      action: const BalanceVisibilityButton(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FinoteHeroAmount(amount: data.netBalance),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Arus kas periode ini, bukan total kekayaan',
            style: AppTypography.captionRegular.copyWith(color: f.onHeroMuted),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: FinoteHeroTile(
                  label: 'Pemasukan',
                  amount: data.totalIncome,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FinoteHeroTile(
                  label: 'Pengeluaran',
                  amount: data.totalExpense,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
