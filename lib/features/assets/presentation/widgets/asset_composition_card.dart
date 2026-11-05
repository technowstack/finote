import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/category_style.dart';
import '../../../../core/theme/finote_colors.dart';
import '../../../../core/widgets/shared_widgets.dart';
import '../../domain/asset_type.dart';
import '../../../market/domain/portfolio_valuation.dart';

/// Reuses the category palette so asset-type colors stay in one token set.
FinoteCategory _paletteFor(AssetType type) => switch (type) {
  AssetType.stock => FinoteCategory.transport,
  AssetType.crypto => FinoteCategory.bills,
  AssetType.mutualFund => FinoteCategory.shopping,
  AssetType.gold => FinoteCategory.food,
  AssetType.other => FinoteCategory.other,
};

Color assetTypeColor(BuildContext context, AssetType type) =>
    Theme.of(context).finote.categories[_paletteFor(type)]!.foreground;

class _Slice {
  const _Slice(this.type, this.group);

  final AssetType type;
  final PortfolioGroupSummary group;
}

/// "Komposisi aset": share of each asset type in the *known* portfolio value.
/// Types whose price is unknown have no value yet and are therefore not
/// shown as a share, which is why the summary badge flags a partial value.
class AssetCompositionCard extends StatelessWidget {
  const AssetCompositionCard({super.key, required this.snapshot});

  final PortfolioSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final slices = [
      for (final type in AssetType.values)
        if (snapshot.groups[type] case final group? when group.knownValue > 0)
          _Slice(type, group),
    ];
    final total = slices.fold<int>(0, (sum, s) => sum + s.group.knownValue);
    if (slices.isEmpty || total <= 0) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final stacked =
        MediaQuery.textScalerOf(context).scale(14) > 18 ||
        MediaQuery.sizeOf(context).width < 340;

    final donut = SizedBox.square(
      dimension: 120,
      child: ExcludeSemantics(
        child: PieChart(
          PieChartData(
            sectionsSpace: 2,
            centerSpaceRadius: 38,
            borderData: FlBorderData(show: false),
            pieTouchData: PieTouchData(enabled: false),
            sections: [
              for (final slice in slices)
                PieChartSectionData(
                  value: slice.group.knownValue.toDouble(),
                  color: assetTypeColor(context, slice.type),
                  radius: 22,
                  showTitle: false,
                ),
            ],
          ),
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 200),
        ),
      ),
    );

    final legend = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final slice in slices)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: _LegendRow(slice: slice, total: total),
          ),
      ],
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Komposisi aset',
              style: AppTypography.titleSection.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (stacked) ...[
              Center(child: donut),
              const SizedBox(height: AppSpacing.md),
              legend,
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  donut,
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(child: legend),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.slice, required this.total});

  final _Slice slice;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final percent = (slice.group.knownValue / total * 100).round();
    final group = slice.group;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: assetTypeColor(context, slice.type),
                shape: BoxShape.circle,
              ),
              child: const SizedBox(width: 10, height: 10),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                slice.type.label,
                style: AppTypography.bodyMd.copyWith(color: colors.onSurface),
              ),
            ),
            Text(
              '$percent%',
              style: AppTypography.amountSm.copyWith(color: colors.onSurface),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 18),
          child: Wrap(
            spacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              CurrencyText(
                amount: group.knownValue,
                maskable: true,
                alignment: Alignment.centerLeft,
                style: AppTypography.bodySm.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              if (!group.isComplete)
                Text(
                  '• ${group.unvaluedAssetCount} harga belum tersedia',
                  style: theme.textTheme.bodySmall,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
