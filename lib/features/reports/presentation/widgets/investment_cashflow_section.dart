import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../data/report_repository.dart';

class InvestmentCashflowSection extends StatelessWidget {
  const InvestmentCashflowSection({super.key, required this.summary});

  final AsyncValue<InvestmentCashflowSummary> summary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Arus Kas Investasi',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          Card(
            child: summary.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: LinearProgressIndicator(),
              ),
              error: (_, _) => const ListTile(
                title: Text('Riwayat arus kas investasi belum dapat dimuat.'),
              ),
              data: (data) => Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Column(
                  children: [
                    _InvestmentAmount(
                      label: 'Total Pembelian Aset',
                      amount: data.totalPurchases,
                    ),
                    _InvestmentAmount(
                      label: 'Total Penjualan Aset',
                      amount: data.totalSales,
                    ),
                    const Divider(indent: 16, endIndent: 16),
                    _InvestmentAmount(
                      label: 'Dana Bersih Diinvestasikan',
                      amount: data.netCashInvested,
                      emphasized: true,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: Text(
                        'Berdasarkan riwayat transaksi, bukan nilai portofolio atau keuntungan investasi.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InvestmentAmount extends StatelessWidget {
  const _InvestmentAmount({
    required this.label,
    required this.amount,
    this.emphasized = false,
  });

  final String label;
  final int amount;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleMedium;
    return ListTile(
      title: Text(label),
      trailing: Text(
        formatIdr(amount),
        style: emphasized
            ? style?.copyWith(fontWeight: FontWeight.w700)
            : style,
      ),
    );
  }
}
