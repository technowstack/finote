import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/finote_colors.dart';
import '../../../../core/widgets/finote_hero.dart';
import '../../../../core/widgets/temporary_badge.dart';
import '../../../market/data/portfolio_market_quotes_provider.dart';
import '../../../market/domain/portfolio_valuation.dart';
import 'asset_formatters.dart';

/// "Total Portofolio" hero, styled like the Beranda net-worth hero. The
/// value is point-in-time and never period-filtered; a partial value always
/// carries a [TemporaryBadge] next to the number.
class PortfolioSummaryCard extends StatelessWidget {
  const PortfolioSummaryCard({
    super.key,
    required this.snapshot,
    required this.market,
  });

  final PortfolioSnapshot snapshot;
  final PortfolioMarketQuoteState market;

  @override
  Widget build(BuildContext context) {
    final f = Theme.of(context).finote;
    final value = snapshot.totalKnownValue;
    final note = AppTypography.captionRegular.copyWith(color: f.onHeroMuted);
    final updatedAt = _latestApiPriceUpdate(snapshot);

    return FinoteHero(
      title: snapshot.isPartial || snapshot.isUnavailable
          ? 'Nilai Portofolio'
          : 'Total Portofolio',
      action: const BalanceVisibilityButton(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (snapshot.isEmpty || value == null)
            Text(
              snapshot.isEmpty ? 'Belum ada posisi aset' : 'Belum tersedia',
              style: AppTypography.amountXl.copyWith(color: f.onHero),
            )
          else
            FinoteHeroAmount(amount: value),
          if (!snapshot.isEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text('${snapshot.holdingAssetCount} aset aktif', style: note),
          ],
          if (snapshot.isPartial) ...[
            const SizedBox(height: AppSpacing.sm),
            TemporaryBadge(
              text:
                  'Nilai sementara • ${snapshot.unvaluedAssetCount} aset belum memiliki harga',
              onHero: true,
            ),
          ],
          if (snapshot.isUnavailable) ...[
            const SizedBox(height: AppSpacing.sm),
            const TemporaryBadge(
              text: 'Belum ada harga untuk aset yang dimiliki.',
              onHero: true,
            ),
          ],
          if (updatedAt != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Harga pasar terakhir diperbarui ${formatPositionDate(context, updatedAt)}',
              style: note,
            ),
          ],
          if (market.isRefreshing) ...[
            const SizedBox(height: AppSpacing.xs),
            Text('Memperbarui harga saham dan crypto...', style: note),
          ],
          if (!market.isRefreshing &&
              (market.failure != null ||
                  market.result.failures.isNotEmpty)) ...[
            const SizedBox(height: AppSpacing.xs),
            Text('Harga terbaru belum dapat diperbarui.', style: note),
          ],
          if (snapshot.integrityIssueCount > 0) ...[
            const SizedBox(height: AppSpacing.xs),
            Text('Ada posisi aset yang tidak valid.', style: note),
          ],
        ],
      ),
    );
  }
}

DateTime? _latestApiPriceUpdate(PortfolioSnapshot snapshot) {
  DateTime? latest;
  for (final valuation in snapshot.valuations) {
    if (valuation.pricingSource != ValuationPriceSource.api ||
        valuation.priceUpdatedAt == null) {
      continue;
    }
    if (latest == null || valuation.priceUpdatedAt!.isAfter(latest)) {
      latest = valuation.priceUpdatedAt;
    }
  }
  return latest;
}
