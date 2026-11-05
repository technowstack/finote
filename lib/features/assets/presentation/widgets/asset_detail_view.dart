import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/shared_widgets.dart';
import '../../data/asset_transaction_repository.dart';
import '../../domain/asset_quantity.dart';
import '../../domain/asset_transaction_action.dart';
import '../../domain/asset_type.dart';
import '../../../market/data/asset_price_repository.dart';
import '../../../market/data/portfolio_valuation_service.dart';
import 'asset_activity_section.dart';
import 'asset_formatters.dart';
import 'opening_position_dialog.dart';
import 'asset_price_section.dart';

class AssetDetailView extends ConsumerWidget {
  const AssetDetailView({super.key, required this.asset});

  final AssetRecord asset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final activities = ref.watch(assetActivitiesProvider(asset.id));
    final holdingState = ref.watch(holdingProvider(asset.id));
    final currentPrice = ref.watch(currentAssetPriceProvider(asset.id));
    final currentValuation = ref.watch(assetValuationProvider(asset.id));
    if (activities.hasError ||
        holdingState.hasError ||
        currentPrice.hasError ||
        currentValuation.hasError) {
      return AppErrorState(
        message: 'Detail aset belum dapat dimuat.',
        onRetry: () {
          ref.invalidate(assetActivitiesProvider(asset.id));
          ref.invalidate(allAssetHoldingsProvider);
          ref.invalidate(currentAssetPriceProvider(asset.id));
        },
      );
    }
    if (!activities.hasValue ||
        !holdingState.hasValue ||
        !currentPrice.hasValue ||
        !currentValuation.hasValue) {
      return const AppLoadingState();
    }
    final holding = holdingState.requireValue;
    final opening = activities.requireValue
        .where(
          (activity) =>
              activity.action == AssetTransactionAction.openingPosition,
        )
        .firstOrNull;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenH),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(asset.name, style: theme.textTheme.headlineSmall),
                if (asset.symbol != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(asset.symbol!, style: theme.textTheme.titleMedium),
                ],
                const Divider(height: AppSpacing.xl),
                AssetDetailRow(label: 'Jenis', value: asset.assetType.label),
                AssetDetailRow(
                  label: 'Posisi',
                  value: formatAssetQuantity(
                    asset,
                    holding?.quantity ?? AssetQuantity.fromScaled(0),
                    hasActivity: holding?.hasActivity ?? false,
                  ),
                ),
                if (asset.assetType == AssetType.stock &&
                    holding?.hasActivity == true)
                  AssetDetailRow(
                    label: 'Jumlah Lembar',
                    value: formatStockShares(holding!.quantity),
                  ),
                if (asset.pricingMode == AssetPricingMode.api)
                  const AssetDetailRow(label: 'Harga', value: 'Otomatis'),
                if (holding?.hasActivity == true) ...[
                  AssetDetailRow(
                    label: asset.pricingMode == AssetPricingMode.manual
                        ? manualPriceLabel(asset)
                        : 'Harga Saat Ini',
                    value: currentValuation.valueOrNull?.unitPrice == null
                        ? asset.pricingMode == AssetPricingMode.manual
                              ? 'Harga belum diatur'
                              : 'Belum tersedia'
                        : '${currentValuation.valueOrNull!.isBackendStale ? 'Harga terakhir ' : ''}${formatIdr(currentValuation.valueOrNull!.unitPrice!)} / ${assetPriceUnit(asset)}',
                  ),
                  AssetDetailRow(
                    label: 'Nilai Saat Ini',
                    value: currentValuation.valueOrNull?.currentValue == null
                        ? 'Belum tersedia'
                        : formatIdr(
                            currentValuation.valueOrNull!.currentValue!,
                          ),
                  ),
                  if (currentValuation.valueOrNull?.priceUpdatedAt != null)
                    AssetDetailRow(
                      label: 'Diperbarui',
                      value: formatPositionDate(
                        context,
                        currentValuation.valueOrNull!.priceUpdatedAt!,
                      ),
                    ),
                ],
                AssetDetailRow(
                  label: 'Status',
                  value: asset.isActive ? 'Aktif' : 'Diarsipkan',
                ),
                if (asset.unitLabel != null)
                  AssetDetailRow(label: 'Satuan', value: asset.unitLabel!),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (asset.pricingMode == AssetPricingMode.manual)
          ManualPriceCard(
            asset: asset,
            price: currentPrice.valueOrNull,
            onSetPrice: () => showManualPriceForm(
              context,
              ref,
              asset,
              currentPrice.valueOrNull,
            ),
            onClearPrice: currentPrice.valueOrNull == null
                ? null
                : () => clearAssetManualPrice(context, ref, asset),
            onUseAutomatic: isMarketAsset(asset)
                ? () => useAutomaticPrice(context, ref, asset)
                : null,
          ),
        if (asset.pricingMode == AssetPricingMode.api)
          ApiPriceFallbackCard(
            asset: asset,
            price: currentPrice.valueOrNull,
            onSetManual: () => showManualFallbackForm(context, ref, asset),
          ),
        if (asset.pricingMode == AssetPricingMode.manual)
          const SizedBox(height: AppSpacing.md),
        if (!(holding?.hasActivity ?? false)) ...[
          const Text('Belum ada posisi'),
          const SizedBox(height: AppSpacing.sm),
          FilledButton.icon(
            onPressed: () => showOpeningPositionForm(context, ref, asset, null),
            icon: const Icon(Icons.add),
            label: const Text('Tambah Posisi Awal'),
          ),
        ] else if (opening != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Posisi', style: theme.textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  AssetDetailRow(
                    label: 'Posisi saat ini',
                    value: formatAssetQuantity(
                      asset,
                      holding!.quantity,
                      hasActivity: true,
                    ),
                  ),
                  AssetDetailRow(
                    label: 'Posisi awal',
                    value: formatAssetQuantity(
                      asset,
                      AssetQuantity.fromScaled(opening.quantityScaled),
                    ),
                  ),
                  AssetDetailRow(
                    label: 'Tanggal mulai',
                    value: formatPositionDate(context, opening.transactionDate),
                  ),
                  AssetDetailRow(
                    label: 'Modal awal',
                    value: opening.totalAmount == null
                        ? 'Tidak diketahui'
                        : formatIdr(opening.totalAmount!),
                  ),
                  if (opening.note?.isNotEmpty == true)
                    AssetDetailRow(label: 'Catatan', value: opening.note!),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => showOpeningPositionForm(
                            context,
                            ref,
                            asset,
                            opening,
                          ),
                          child: const Text('Edit Posisi Awal'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      IconButton(
                        tooltip: 'Hapus Posisi Awal',
                        onPressed: () => removeAssetOpeningPosition(
                          context,
                          ref,
                          opening.id,
                        ),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: AssetDetailRow(
                label: 'Posisi saat ini',
                value: formatAssetQuantity(
                  asset,
                  holding!.quantity,
                  hasActivity: true,
                ),
              ),
            ),
          ),
        if (activities.valueOrNull case final activityItems?)
          if (activityItems.any(
            (activity) =>
                activity.action != AssetTransactionAction.openingPosition,
          )) ...[
            const SizedBox(height: AppSpacing.lg),
            Text('Aktivitas', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            for (final activity in activityItems)
              if (activity.action != AssetTransactionAction.openingPosition)
                AssetActivityTile(
                  asset: asset,
                  activity: activity,
                  onEdit: () => showActivityForm(context, ref, asset, activity),
                  onDelete: () => deleteActivity(context, ref, activity),
                ),
          ],
        const SizedBox(height: AppSpacing.lg),
        if (asset.isActive)
          FilledButton.icon(
            onPressed: () => showActivityMenu(context, ref, asset),
            icon: const Icon(Icons.add),
            label: const Text('Tambah Aktivitas'),
          )
        else
          const Text(
            'Aktifkan kembali aset untuk menambah aktivitas.',
            textAlign: TextAlign.center,
          ),
      ],
    );
  }
}

class AssetDetailRow extends StatelessWidget {
  const AssetDetailRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTypography.bodyMd.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              // Tabular figures keep amounts and quantities aligned.
              style: AppTypography.amountSm.copyWith(color: colors.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}
