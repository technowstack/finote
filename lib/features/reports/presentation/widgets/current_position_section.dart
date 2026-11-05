import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/finance/net_worth.dart';

class CurrentPositionSection extends StatelessWidget {
  const CurrentPositionSection({super.key, required this.netWorth});

  final AsyncValue<NetWorthSnapshot> netWorth;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Posisi Keuangan Saat Ini',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text('Nilai saat ini', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: AppSpacing.sm),
          Card(
            child: netWorth.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: LinearProgressIndicator(),
              ),
              error: (_, _) => const ListTile(
                title: Text('Posisi keuangan belum dapat dimuat.'),
              ),
              data: (snapshot) => Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Column(
                  children: [
                    _PositionAmount(
                      label: 'Kas & Dompet',
                      amount: snapshot.cashValue,
                    ),
                    _PositionAmount(
                      label: 'Portofolio',
                      amount: snapshot.portfolioKnownValue,
                    ),
                    const Divider(indent: 16, endIndent: 16),
                    _PositionAmount(
                      label: 'Kekayaan Bersih',
                      amount: snapshot.totalKnownValue,
                      emphasized: true,
                    ),
                    if (snapshot.isPartial)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                        child: Text(
                          snapshot.unvaluedAssetCount > 0
                              ? 'Nilai sementara • ${snapshot.unvaluedAssetCount} aset belum memiliki harga'
                              : 'Nilai sementara • terdapat posisi aset yang tidak valid',
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

class _PositionAmount extends StatelessWidget {
  const _PositionAmount({
    required this.label,
    required this.amount,
    this.emphasized = false,
  });

  final String label;
  final int? amount;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleMedium;
    return ListTile(
      title: Text(label),
      trailing: Text(
        amount == null ? 'Belum tersedia' : formatIdr(amount!),
        style: emphasized
            ? style?.copyWith(fontWeight: FontWeight.w700)
            : style,
      ),
    );
  }
}
