import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../data/asset_repository.dart';
import '../data/asset_activity_service.dart';
import '../data/asset_transaction_repository.dart';
import '../domain/asset_quantity.dart';
import '../domain/asset_transaction_action.dart';
import '../domain/asset_type.dart';
import '../../accounts/data/account_repository.dart';
import '../../market/data/portfolio_market_quotes_provider.dart';
import '../../market/data/asset_price_repository.dart';
import '../../market/data/portfolio_valuation_service.dart';
import '../../market/domain/market_quote.dart';
import '../../market/domain/portfolio_valuation.dart';

class AssetsPage extends ConsumerStatefulWidget {
  const AssetsPage({super.key, this.routePrefix = '/portfolio/assets'});

  final String routePrefix;

  @override
  ConsumerState<AssetsPage> createState() => _AssetsPageState();
}

class _AssetsPageState extends ConsumerState<AssetsPage> {
  Future<void> _openForm([AssetRecord? asset]) async {
    final data = await showDialog<_AssetFormData>(
      context: context,
      builder: (context) => _AssetFormDialog(asset: asset),
    );
    if (data == null || !mounted) return;

    try {
      final repository = ref.read(assetRepositoryProvider);
      if (asset == null) {
        await repository.create(
          symbol: data.symbol,
          name: data.name,
          assetType: data.assetType,
          pricingMode: data.pricingMode,
          unitLabel: data.unitLabel,
        );
      } else {
        final updated = await repository.update(
          id: asset.id,
          symbol: data.symbol,
          name: data.name,
          assetType: data.assetType,
          pricingMode: data.pricingMode,
          unitLabel: data.unitLabel,
        );
        if (!updated) throw StateError('Asset is no longer available');
      }
    } catch (error) {
      if (mounted) _showError(_assetError(error, editing: asset != null));
    }
  }

  Future<void> _archive(AssetRecord asset) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Arsipkan aset?'),
        content: const Text(
          'Aset tidak aktif akan disembunyikan dari daftar aset aktif. '
          'Data aktivitasnya tetap aman.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Arsipkan'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(assetRepositoryProvider).archive(asset.id);
    } catch (_) {
      if (mounted) _showError('Aset gagal diarsipkan. Coba lagi.');
    }
  }

  Future<void> _reactivate(AssetRecord asset) async {
    try {
      await ref.read(assetRepositoryProvider).reactivate(asset.id);
    } catch (_) {
      if (mounted) _showError('Aset gagal diaktifkan kembali. Coba lagi.');
    }
  }

  Future<void> _delete(AssetRecord asset) async {
    final usage = await ref.read(assetRepositoryProvider).getUsage(asset.id);
    if (!mounted || usage == null) return;
    if (!usage.canDelete) {
      _showError('Aset memiliki riwayat aktivitas dan hanya dapat diarsipkan.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus aset?'),
        content: const Text(
          'Aset ini belum memiliki aktivitas dan dapat dihapus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final deleted = await ref
          .read(assetRepositoryProvider)
          .deleteUnused(asset.id);
      if (!deleted && mounted) {
        _showError('Aset tidak dapat dihapus karena sudah memiliki aktivitas.');
      }
    } catch (_) {
      if (mounted) _showError('Aset gagal dihapus. Coba lagi.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final assets = ref.watch(assetHoldingsProvider);
    final allAssets = ref.watch(allAssetHoldingsProvider);
    final market = ref.watch(portfolioMarketQuotesProvider);
    final prices = ref.watch(activeAssetPricesProvider).valueOrNull ?? {};
    final portfolio = ref.watch(portfolioValuationProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Portofolio'),
        actions: [
          IconButton(
            tooltip: 'Refresh Harga',
            onPressed: market.isRefreshing
                ? null
                : () async {
                    await ref
                        .read(portfolioMarketQuotesProvider.notifier)
                        .refresh(force: true);
                    if (!context.mounted) return;
                    final state = ref.read(portfolioMarketQuotesProvider);
                    final message = state.failure != null
                        ? 'Harga terbaru belum dapat diperbarui. Harga terakhir tetap digunakan.'
                        : state.result.failures.isNotEmpty
                        ? 'Sebagian harga tidak dapat diperbarui. Harga terakhir tetap digunakan.'
                        : state.result.quotes.isEmpty
                        ? 'Tidak ada harga pasar yang perlu diperbarui.'
                        : 'Harga berhasil diperbarui.';
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(message)));
                  },
            icon: market.isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: assets.when(
        loading: () => const AppLoadingState(),
        error: (_, _) => AppErrorState(
          message: 'Aset belum dapat dimuat.',
          onRetry: () => ref.invalidate(allAssetsProvider),
        ),
        data: (active) {
          final all = allAssets.valueOrNull ?? active;
          final archived = all
              .where((holding) => !holding.asset.isActive)
              .toList();
          if (active.isEmpty && archived.isEmpty) {
            return _EmptyAssets(onAdd: _openForm);
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              AppSpacing.sm,
              AppSpacing.screenH,
              96,
            ),
            children: [
              if (portfolio != null)
                _PortfolioSummary(snapshot: portfolio, market: market),
              if (portfolio != null) const SizedBox(height: AppSpacing.md),
              if (market.isRefreshing)
                const Padding(
                  padding: EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Text('Memperbarui harga...'),
                ),
              if (market.failure != null || market.result.failures.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Text(
                    'Harga terbaru belum dapat diperbarui. Harga terakhir tetap digunakan.',
                  ),
                ),
              if (active.isNotEmpty)
                ..._groupedAssets(active, market, prices, portfolio),
              if (archived.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Aset Diarsipkan',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                for (final holding in archived) ...[
                  _AssetCard(
                    asset: holding.asset,
                    quantity: holding.quantity,
                    hasActivity: holding.hasActivity,
                    onTap: () => context.push(
                      '${widget.routePrefix}/${holding.asset.id}',
                    ),
                    onEdit: () => _openForm(holding.asset),
                    onArchive: () => _reactivate(holding.asset),
                    onDelete: () => _delete(holding.asset),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            ],
          );
        },
      ),
      floatingActionButton: assets.valueOrNull?.isNotEmpty == true
          ? FloatingActionButton(
              onPressed: _openForm,
              tooltip: 'Tambah aset',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  List<Widget> _groupedAssets(
    List<AssetHolding> holdings,
    PortfolioMarketQuoteState market,
    Map<int, LocalAssetPrice> prices,
    PortfolioSnapshot? portfolio,
  ) {
    final widgets = <Widget>[];
    for (final type in AssetType.values) {
      final group =
          holdings.where((holding) => holding.asset.assetType == type).toList()
            ..sort((a, b) {
              final aKey = (a.asset.symbol ?? a.asset.name).toUpperCase();
              final bKey = (b.asset.symbol ?? b.asset.name).toUpperCase();
              return aKey.compareTo(bKey);
            });
      if (group.isEmpty) continue;
      widgets.add(
        Text(type.label, style: Theme.of(context).textTheme.titleMedium),
      );
      widgets.add(const SizedBox(height: AppSpacing.sm));
      for (final holding in group) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _AssetCard(
              asset: holding.asset,
              quantity: holding.quantity,
              hasActivity: holding.hasActivity,
              price: prices[holding.asset.id],
              valuation: portfolio?.byAssetId[holding.asset.id],
              quoteUnavailable: _quoteUnavailable(holding, market, prices),
              onTap: () =>
                  context.push('${widget.routePrefix}/${holding.asset.id}'),
              onEdit: () => _openForm(holding.asset),
              onArchive: () => _archive(holding.asset),
              onDelete: () => _delete(holding.asset),
            ),
          ),
        );
      }
    }
    return widgets;
  }
}

bool _quoteUnavailable(
  AssetHolding holding,
  PortfolioMarketQuoteState market,
  Map<int, LocalAssetPrice> prices,
) {
  if (!holding.hasActivity ||
      holding.quantity.isNegative ||
      holding.quantity.isZero ||
      holding.asset.pricingMode != AssetPricingMode.api ||
      (holding.asset.assetType != AssetType.stock &&
          holding.asset.assetType != AssetType.crypto) ||
      holding.asset.symbol == null) {
    return false;
  }
  final key = AssetMarketKey(
    holding.asset.symbol!.trim().toUpperCase(),
    holding.asset.assetType,
  );
  return !prices.containsKey(holding.asset.id) &&
      (market.failure != null || market.result.failures.containsKey(key));
}

class AssetDetailPage extends ConsumerWidget {
  const AssetDetailPage({required this.assetId, super.key});

  final int assetId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asset = ref.watch(assetByIdProvider(assetId));
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Aset')),
      body: asset.when(
        loading: () => const AppLoadingState(),
        error: (_, _) => const AppErrorState(
          message: 'Detail aset belum dapat dimuat.',
          onRetry: _noop,
        ),
        data: (item) => item == null
            ? const AppEmptyState(
                icon: Icons.inventory_2_outlined,
                message: 'Aset tidak ditemukan.',
              )
            : _AssetDetail(asset: item),
      ),
    );
  }
}

void _noop() {}

class _AssetDetail extends ConsumerWidget {
  const _AssetDetail({required this.asset});

  final AssetRecord asset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final activities = ref.watch(assetActivitiesProvider(asset.id));
    final holding = ref.watch(holdingProvider(asset.id)).valueOrNull;
    final currentPrice = ref.watch(currentAssetPriceProvider(asset.id));
    final currentValuation = ref.watch(assetValuationProvider(asset.id));
    final opening = activities.valueOrNull
        ?.where(
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
                _DetailRow(label: 'Jenis', value: asset.assetType.label),
                _DetailRow(
                  label: 'Posisi',
                  value: _formatAssetQuantity(
                    asset,
                    holding?.quantity ?? AssetQuantity.fromScaled(0),
                    hasActivity: holding?.hasActivity ?? false,
                  ),
                ),
                if (asset.assetType == AssetType.stock &&
                    holding?.hasActivity == true)
                  _DetailRow(
                    label: 'Jumlah Lembar',
                    value: _formatStockShares(holding!.quantity),
                  ),
                if (asset.pricingMode == AssetPricingMode.api)
                  const _DetailRow(label: 'Harga', value: 'Otomatis'),
                if (holding?.hasActivity == true) ...[
                  _DetailRow(
                    label: asset.pricingMode == AssetPricingMode.manual
                        ? _manualPriceLabel(asset)
                        : 'Harga Saat Ini',
                    value: currentValuation.valueOrNull?.unitPrice == null
                        ? asset.pricingMode == AssetPricingMode.manual
                              ? 'Harga belum diatur'
                              : 'Belum tersedia'
                        : '${currentValuation.valueOrNull!.isBackendStale ? 'Harga terakhir ' : ''}${formatIdr(currentValuation.valueOrNull!.unitPrice!)} / ${_priceUnit(asset)}',
                  ),
                  _DetailRow(
                    label: 'Nilai Saat Ini',
                    value: currentValuation.valueOrNull?.currentValue == null
                        ? 'Belum tersedia'
                        : formatIdr(
                            currentValuation.valueOrNull!.currentValue!,
                          ),
                  ),
                  if (currentValuation.valueOrNull?.priceUpdatedAt != null)
                    _DetailRow(
                      label: 'Diperbarui',
                      value: _formatPositionDate(
                        context,
                        currentValuation.valueOrNull!.priceUpdatedAt!,
                      ),
                    ),
                ],
                _DetailRow(
                  label: 'Status',
                  value: asset.isActive ? 'Aktif' : 'Diarsipkan',
                ),
                if (asset.unitLabel != null)
                  _DetailRow(label: 'Satuan', value: asset.unitLabel!),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (asset.pricingMode == AssetPricingMode.manual)
          _ManualPriceCard(
            asset: asset,
            price: currentPrice.valueOrNull,
            onSetPrice: () => _showManualPriceForm(
              context,
              ref,
              asset,
              currentPrice.valueOrNull,
            ),
            onClearPrice: currentPrice.valueOrNull == null
                ? null
                : () => _clearManualPrice(context, ref, asset),
            onUseAutomatic: _isMarketAsset(asset)
                ? () => _useAutomaticPrice(context, ref, asset)
                : null,
          ),
        if (asset.pricingMode == AssetPricingMode.api)
          _ApiPriceFallbackCard(
            asset: asset,
            price: currentPrice.valueOrNull,
            onSetManual: () => _showManualFallbackForm(context, ref, asset),
          ),
        if (asset.pricingMode == AssetPricingMode.manual)
          const SizedBox(height: AppSpacing.md),
        if (!(holding?.hasActivity ?? false)) ...[
          const Text('Belum ada posisi'),
          const SizedBox(height: AppSpacing.sm),
          FilledButton.icon(
            onPressed: () =>
                _showOpeningPositionForm(context, ref, asset, null),
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
                  Text(
                    _formatAssetQuantity(
                      asset,
                      AssetQuantity.fromScaled(opening.quantityScaled),
                    ),
                  ),
                  _DetailRow(
                    label: 'Posisi awal',
                    value: _formatAssetQuantity(
                      asset,
                      AssetQuantity.fromScaled(opening.quantityScaled),
                    ),
                  ),
                  _DetailRow(
                    label: 'Tanggal mulai',
                    value: _formatPositionDate(
                      context,
                      opening.transactionDate,
                    ),
                  ),
                  _DetailRow(
                    label: 'Modal awal',
                    value: opening.totalAmount == null
                        ? 'Tidak diketahui'
                        : formatIdr(opening.totalAmount!),
                  ),
                  if (opening.note?.isNotEmpty == true)
                    _DetailRow(label: 'Catatan', value: opening.note!),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _showOpeningPositionForm(
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
                        onPressed: () =>
                            _removeOpeningPosition(context, ref, opening.id),
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
              child: _DetailRow(
                label: 'Posisi saat ini',
                value: _formatAssetQuantity(
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
                _ActivityTile(
                  asset: asset,
                  activity: activity,
                  onEdit: () =>
                      _showActivityForm(context, ref, asset, activity),
                  onDelete: () => _deleteActivity(context, ref, activity.id),
                ),
          ],
        const SizedBox(height: AppSpacing.lg),
        FilledButton.icon(
          onPressed: () => _showActivityMenu(context, ref, asset),
          icon: const Icon(Icons.add),
          label: const Text('Tambah Aktivitas'),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

class _ManualPriceCard extends StatelessWidget {
  const _ManualPriceCard({
    required this.asset,
    required this.price,
    required this.onSetPrice,
    required this.onClearPrice,
    this.onUseAutomatic,
  });

  final AssetRecord asset;
  final LocalAssetPrice? price;
  final VoidCallback onSetPrice;
  final VoidCallback? onClearPrice;
  final VoidCallback? onUseAutomatic;

  @override
  Widget build(BuildContext context) {
    final hasPrice = price != null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _manualPriceLabel(asset),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              hasPrice
                  ? '${formatIdr(price!.price)} / ${_priceUnit(asset)}'
                  : 'Belum diatur',
            ),
            if (hasPrice) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Diperbarui ${_formatPositionDate(context, price!.updatedAt)}',
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: onSetPrice,
                    child: Text(hasPrice ? 'Ubah Harga' : 'Atur Harga'),
                  ),
                ),
                if (onClearPrice != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  IconButton(
                    tooltip: 'Hapus Harga',
                    onPressed: onClearPrice,
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ],
            ),
            if (onUseAutomatic != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: onUseAutomatic,
                  child: const Text('Gunakan Harga Otomatis'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

bool _isMarketAsset(AssetRecord asset) =>
    asset.assetType == AssetType.stock || asset.assetType == AssetType.crypto;

Future<void> _useAutomaticPrice(
  BuildContext context,
  WidgetRef ref,
  AssetRecord asset,
) async {
  try {
    final updated = await ref
        .read(assetRepositoryProvider)
        .update(
          id: asset.id,
          symbol: asset.symbol,
          name: asset.name,
          assetType: asset.assetType,
          pricingMode: AssetPricingMode.api,
          currency: asset.currency,
          unitLabel: asset.unitLabel,
        );
    if (!updated) throw StateError('Asset is no longer available');
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Harga otomatis gagal diaktifkan. Coba lagi.'),
        ),
      );
    }
  }
}

class _ApiPriceFallbackCard extends StatelessWidget {
  const _ApiPriceFallbackCard({
    required this.asset,
    required this.price,
    required this.onSetManual,
  });

  final AssetRecord asset;
  final LocalAssetPrice? price;
  final VoidCallback onSetManual;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Harga pasar', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            price == null
                ? 'Harga belum tersedia'
                : '${price!.isBackendStale ? 'Harga terakhir ' : ''}${formatIdr(price!.price)} / ${_priceUnit(asset)}',
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            onPressed: onSetManual,
            child: const Text('Atur Harga Manual'),
          ),
        ],
      ),
    ),
  );
}

String _priceUnit(AssetRecord asset) => switch (asset.assetType) {
  AssetType.gold => 'gram',
  AssetType.mutualFund => 'unit',
  AssetType.other => asset.unitLabel ?? 'unit',
  AssetType.stock => 'saham',
  AssetType.crypto => 'coin/token',
};

String _assetTitle(AssetRecord asset) => switch (asset.assetType) {
  AssetType.stock || AssetType.crypto => asset.symbol ?? asset.name,
  _ => asset.name,
};

String _manualPriceLabel(AssetRecord asset) => switch (asset.assetType) {
  AssetType.gold => 'Harga per Gram',
  AssetType.mutualFund => 'Nilai per Unit',
  AssetType.other => 'Harga per ${_priceUnit(asset)}',
  _ => 'Harga per Unit',
};

String _activityPriceLabel(AssetRecord asset) => switch (asset.assetType) {
  AssetType.gold => 'Harga per Gram (IDR)',
  AssetType.stock => 'Harga per Saham (IDR)',
  _ => 'Harga per Unit (IDR)',
};

Future<void> _showManualPriceForm(
  BuildContext context,
  WidgetRef ref,
  AssetRecord asset,
  LocalAssetPrice? currentPrice,
) async {
  final price = await showDialog<int>(
    context: context,
    builder: (_) =>
        _ManualPriceDialog(asset: asset, currentPrice: currentPrice),
  );
  if (price == null || !context.mounted) return;
  try {
    await ref
        .read(assetPriceRepositoryProvider)
        .setManualPrice(
          assetId: asset.id,
          price: price,
          currency: asset.currency,
        );
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harga gagal disimpan. Coba lagi.')),
      );
    }
  }
}

Future<void> _showManualFallbackForm(
  BuildContext context,
  WidgetRef ref,
  AssetRecord asset,
) async {
  final price = await showDialog<int>(
    context: context,
    builder: (_) => _ManualPriceDialog(asset: asset, currentPrice: null),
  );
  if (price == null || !context.mounted) return;
  try {
    final updated = await ref
        .read(assetRepositoryProvider)
        .update(
          id: asset.id,
          symbol: asset.symbol,
          name: asset.name,
          assetType: asset.assetType,
          pricingMode: AssetPricingMode.manual,
          currency: asset.currency,
          unitLabel: asset.unitLabel,
        );
    if (!updated) throw StateError('Asset is no longer available');
    await ref
        .read(assetPriceRepositoryProvider)
        .setManualPrice(
          assetId: asset.id,
          price: price,
          currency: asset.currency,
        );
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Harga manual gagal disimpan. Coba lagi.'),
        ),
      );
    }
  }
}

Future<void> _clearManualPrice(
  BuildContext context,
  WidgetRef ref,
  AssetRecord asset,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Hapus harga saat ini?'),
      content: const Text(
        'Jumlah aset tetap tersimpan. Hanya harga saat ini yang akan dihapus.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Hapus'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  try {
    await ref.read(assetPriceRepositoryProvider).clearManualPrice(asset.id);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harga gagal dihapus. Coba lagi.')),
      );
    }
  }
}

class _ManualPriceDialog extends StatefulWidget {
  const _ManualPriceDialog({required this.asset, required this.currentPrice});

  final AssetRecord asset;
  final LocalAssetPrice? currentPrice;

  @override
  State<_ManualPriceDialog> createState() => _ManualPriceDialogState();
}

class _ManualPriceDialogState extends State<_ManualPriceDialog> {
  late final TextEditingController _price;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _price = TextEditingController(
      text: widget.currentPrice == null
          ? ''
          : formatIdr(widget.currentPrice!.price).replaceFirst('Rp', ''),
    );
  }

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Harga Manual'),
    content: Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: TextFormField(
          controller: _price,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          decoration: InputDecoration(
            labelText: _manualPriceLabel(widget.asset),
            helperText: widget.asset.assetType == AssetType.mutualFund
                ? 'Masukkan NAB/unit terbaru.'
                : null,
            prefixText: 'Rp ',
          ),
          validator: (value) {
            final amount = _parseMoney(value ?? '');
            if (amount <= 0) return 'Masukkan harga lebih dari 0.';
            return null;
          },
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Batal'),
      ),
      FilledButton(
        onPressed: () {
          if (_formKey.currentState!.validate()) {
            Navigator.pop(context, _parseMoney(_price.text));
          }
        },
        child: const Text('Simpan'),
      ),
    ],
  );
}

Future<void> _showOpeningPositionForm(
  BuildContext context,
  WidgetRef ref,
  AssetRecord asset,
  AssetTransactionRecord? opening,
) async {
  final data = await showDialog<_OpeningPositionData>(
    context: context,
    builder: (_) => _OpeningPositionDialog(asset: asset, opening: opening),
  );
  if (data == null || !context.mounted) return;
  try {
    final repository = ref.read(assetTransactionRepositoryProvider);
    if (opening == null) {
      await repository.createOpeningPosition(
        assetId: asset.id,
        quantity: data.quantity,
        transactionDate: data.date,
        totalAmount: data.totalAmount,
        note: data.note,
      );
    } else {
      final updated = await repository.updateOpeningPosition(
        id: opening.id,
        quantity: data.quantity,
        transactionDate: data.date,
        totalAmount: data.totalAmount,
        note: data.note,
      );
      if (!updated) throw StateError('Opening position is no longer available');
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is StateError &&
                    error.message == 'Opening position already exists'
                ? 'Posisi awal sudah tersedia. Edit posisi yang ada.'
                : 'Posisi awal gagal disimpan. Coba lagi.',
          ),
        ),
      );
    }
  }
}

Future<void> _removeOpeningPosition(
  BuildContext context,
  WidgetRef ref,
  int id,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Hapus Posisi Awal?'),
      content: const Text('Aset akan kembali ke status Belum ada posisi.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Hapus'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  try {
    await ref
        .read(assetTransactionRepositoryProvider)
        .removeOpeningPosition(id);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Posisi awal tidak dapat dihapus.')),
      );
    }
  }
}

String _formatAssetQuantity(
  AssetRecord asset,
  AssetQuantity quantity, {
  bool hasActivity = true,
}) {
  if (quantity.isZero && !hasActivity) return 'Belum ada posisi';
  if (asset.assetType == AssetType.stock) {
    return _formatStockQuantity(quantity);
  }
  final unit = switch (asset.assetType) {
    AssetType.crypto => 'coin/token',
    AssetType.mutualFund => 'unit',
    AssetType.gold => 'gram',
    AssetType.other => asset.unitLabel ?? 'unit',
    AssetType.stock => 'saham',
  };
  return '$quantity $unit';
}

String _formatStockQuantity(AssetQuantity quantity) {
  if (quantity.scaled % AssetQuantity.scale != 0) {
    return '$quantity lembar';
  }
  final shares = quantity.scaled ~/ AssetQuantity.scale;
  final sign = shares < 0 ? '-' : '';
  final absoluteShares = shares.abs();
  final lots = absoluteShares ~/ 100;
  final remainder = absoluteShares % 100;
  if (remainder == 0) return '$sign$lots lot';
  if (lots == 0) return '$sign$remainder lembar';
  return '$sign$lots lot + $remainder lembar';
}

String _formatStockShares(AssetQuantity quantity) {
  if (quantity.scaled % AssetQuantity.scale != 0) {
    return '$quantity lembar';
  }
  return '${formatIdr(quantity.scaled ~/ AssetQuantity.scale).replaceFirst('Rp', '')} lembar';
}

class _OpeningPositionData {
  const _OpeningPositionData({
    required this.quantity,
    required this.date,
    required this.totalAmount,
    required this.note,
  });

  final AssetQuantity quantity;
  final DateTime date;
  final int? totalAmount;
  final String? note;
}

class _OpeningPositionDialog extends StatefulWidget {
  const _OpeningPositionDialog({required this.asset, this.opening});

  final AssetRecord asset;
  final AssetTransactionRecord? opening;

  @override
  State<_OpeningPositionDialog> createState() => _OpeningPositionDialogState();
}

class _OpeningPositionDialogState extends State<_OpeningPositionDialog> {
  late final TextEditingController _quantity;
  late final TextEditingController _cost;
  late final TextEditingController _note;
  late DateTime _date;
  late bool _hasCost;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final opening = widget.opening;
    final quantity = opening == null
        ? ''
        : _inputQuantity(
            widget.asset,
            AssetQuantity.fromScaled(opening.quantityScaled),
          );
    _quantity = TextEditingController(text: quantity);
    _cost = TextEditingController(
      text: opening?.totalAmount == null
          ? ''
          : formatIdr(opening!.totalAmount!),
    );
    _note = TextEditingController(text: opening?.note ?? '');
    _date = opening?.transactionDate ?? DateTime.now();
    _hasCost = opening?.totalAmount != null;
  }

  @override
  void dispose() {
    _quantity.dispose();
    _cost.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isStock = widget.asset.assetType == AssetType.stock;
    return AlertDialog(
      title: const Text('Posisi Awal'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${widget.asset.symbol ?? widget.asset.name}\n${widget.asset.name}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _quantity,
                autofocus: true,
                keyboardType: TextInputType.numberWithOptions(
                  decimal: !isStock,
                ),
                decoration: InputDecoration(
                  labelText: isStock
                      ? 'Jumlah Lot'
                      : 'Jumlah ${_unitLabel(widget.asset)}',
                ),
                onChanged: (_) => setState(() {}),
                validator: (value) {
                  try {
                    final quantity = _parseOpeningQuantity(
                      widget.asset,
                      value ?? '',
                    );
                    return quantity.isNegative || quantity.isZero
                        ? 'Jumlah harus lebih dari 0'
                        : null;
                  } catch (_) {
                    return isStock
                        ? 'Masukkan jumlah lot bulat yang valid'
                        : 'Masukkan jumlah dengan maksimal 8 angka desimal';
                  }
                },
              ),
              if (isStock)
                if (_stockSharesPreview(_quantity.text) case final shares?)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Jumlah Lembar: ${_formatInteger(shares)}'),
                  ),
              const SizedBox(height: AppSpacing.sm),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Tanggal Posisi'),
                subtitle: Text(_formatPositionDate(context, _date)),
                trailing: const Icon(Icons.calendar_today_outlined),
                onTap: () async {
                  final selected = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (selected != null) setState(() => _date = selected);
                },
              ),
              if (widget.opening == null)
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Tanggal ini menandai awal pencatatan aset di Finote, bukan tanggal pembelian asli.',
                  ),
                ),
              const SizedBox(height: AppSpacing.sm),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Saya tahu modal awal'),
                subtitle: Text(
                  _hasCost ? 'Modal akan disimpan' : 'Tidak diketahui',
                ),
                value: _hasCost,
                onChanged: (value) => setState(() => _hasCost = value),
              ),
              if (_hasCost)
                TextFormField(
                  controller: _cost,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Modal Awal (IDR)',
                  ),
                  validator: (value) =>
                      _hasCost && _parseMoney(value ?? '') <= 0
                      ? 'Modal harus lebih dari 0'
                      : null,
                ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _note,
                decoration: const InputDecoration(
                  labelText: 'Catatan (opsional)',
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(onPressed: _save, child: const Text('Simpan Posisi')),
      ],
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _OpeningPositionData(
        quantity: _parseOpeningQuantity(widget.asset, _quantity.text),
        date: _date,
        totalAmount: _hasCost ? _parseMoney(_cost.text) : null,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      ),
    );
  }
}

String _unitLabel(AssetRecord asset) => switch (asset.assetType) {
  AssetType.crypto => 'Coin/Token',
  AssetType.mutualFund => 'Unit',
  AssetType.gold => 'Gram',
  AssetType.other => asset.unitLabel ?? 'Unit',
  AssetType.stock => 'Lot',
};

String _inputQuantity(AssetRecord asset, AssetQuantity quantity) {
  if (asset.assetType != AssetType.stock) return quantity.toString();
  return (quantity.scaled ~/ AssetQuantity.scale ~/ 100).toString();
}

AssetQuantity _parseOpeningQuantity(AssetRecord asset, String value) {
  if (asset.assetType != AssetType.stock) {
    return AssetQuantity.parse(value.replaceAll(',', '.'));
  }
  if (!RegExp(r'^\d+$').hasMatch(value.trim())) {
    throw const FormatException('Stock lot must be a whole number');
  }
  final scaled =
      BigInt.parse(value.trim()) * BigInt.from(AssetQuantity.scale * 100);
  if (scaled > BigInt.from(9223372036854775807)) {
    throw const FormatException('Quantity is out of range');
  }
  return AssetQuantity.fromScaled(scaled.toInt());
}

int _parseMoney(String value) =>
    int.tryParse(value.replaceAll(RegExp(r'\D'), '')) ?? 0;

int? _stockSharesPreview(String value) {
  final input = value.trim();
  if (!RegExp(r'^\d+$').hasMatch(input)) return null;
  final shares = BigInt.parse(input) * BigInt.from(100);
  if (shares > BigInt.from(9223372036854775807 ~/ AssetQuantity.scale)) {
    return null;
  }
  return shares.toInt();
}

int? _stockTotalPreview(String quantity, String price) {
  final shares = _stockSharesPreview(quantity);
  final amount = _parseMoney(price);
  if (shares == null || amount <= 0) return null;
  final total = BigInt.from(shares) * BigInt.from(amount);
  if (total > BigInt.from(9223372036854775807)) return null;
  return total.toInt();
}

int? _activityTotalPreview(AssetRecord asset, String quantity, String price) {
  if (asset.assetType == AssetType.stock) {
    return _stockTotalPreview(quantity, price);
  }
  final parsedQuantity = _parseDecimalQuantityPreview(quantity);
  final parsedPrice = _parseMoney(price);
  if (parsedQuantity == null || parsedPrice <= 0) return null;
  final total =
      BigInt.from(parsedQuantity) *
      BigInt.from(parsedPrice) ~/
      BigInt.from(AssetQuantity.scale);
  if (total > BigInt.from(9223372036854775807)) return null;
  return total.toInt();
}

int? _parseDecimalQuantityPreview(String value) {
  try {
    final quantity = AssetQuantity.parse(value.trim().replaceAll(',', '.'));
    return quantity.isNegative || quantity.isZero ? null : quantity.scaled;
  } catch (_) {
    return null;
  }
}

String _formatInteger(int value) => formatIdr(value).replaceFirst('Rp', '');

String _formatPositionDate(BuildContext context, DateTime date) =>
    MaterialLocalizations.of(context).formatMediumDate(date);

Future<void> _showActivityMenu(
  BuildContext context,
  WidgetRef ref,
  AssetRecord asset,
) async {
  final action = await showModalBottomSheet<AssetTransactionAction>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.add_shopping_cart),
            title: const Text('Beli'),
            onTap: () => Navigator.pop(context, AssetTransactionAction.buy),
          ),
          ListTile(
            leading: const Icon(Icons.sell_outlined),
            title: const Text('Jual'),
            onTap: () => Navigator.pop(context, AssetTransactionAction.sell),
          ),
          ListTile(
            leading: const Icon(Icons.tune),
            title: const Text('Penyesuaian'),
            onTap: () =>
                Navigator.pop(context, AssetTransactionAction.adjustment),
          ),
        ],
      ),
    ),
  );
  if (action != null && context.mounted) {
    await _showActivityForm(context, ref, asset, null, action: action);
  }
}

Future<void> _showActivityForm(
  BuildContext context,
  WidgetRef ref,
  AssetRecord asset,
  AssetTransactionRecord? activity, {
  AssetTransactionAction? action,
}) async {
  final selectedAction = action ?? activity?.action;
  if (selectedAction == null) return;
  final data = await showDialog<_ActivityFormData>(
    context: context,
    builder: (_) => _ActivityFormDialog(
      asset: asset,
      action: selectedAction,
      activity: activity,
    ),
  );
  if (data == null || !context.mounted) return;
  try {
    final service = ref.read(assetActivityServiceProvider);
    final id = activity?.id;
    if (id == null) {
      switch (selectedAction) {
        case AssetTransactionAction.buy:
          await service.createBuy(
            assetId: asset.id,
            quantity: data.quantity,
            priceAmount: data.priceAmount!,
            accountId: data.accountId!,
            date: data.date,
            note: data.note,
          );
        case AssetTransactionAction.sell:
          await service.createSell(
            assetId: asset.id,
            quantity: data.quantity,
            priceAmount: data.priceAmount!,
            accountId: data.accountId!,
            date: data.date,
            note: data.note,
          );
        case AssetTransactionAction.adjustment:
          await service.createAdjustment(
            assetId: asset.id,
            quantity: data.quantity,
            date: data.date,
            note: data.note,
          );
        case AssetTransactionAction.openingPosition:
          return;
      }
    } else {
      switch (selectedAction) {
        case AssetTransactionAction.buy:
          await service.updateBuy(
            activityId: id,
            quantity: data.quantity,
            priceAmount: data.priceAmount!,
            accountId: data.accountId!,
            date: data.date,
            note: data.note,
          );
        case AssetTransactionAction.sell:
          await service.updateSell(
            activityId: id,
            quantity: data.quantity,
            priceAmount: data.priceAmount!,
            accountId: data.accountId!,
            date: data.date,
            note: data.note,
          );
        case AssetTransactionAction.adjustment:
          await service.updateAdjustment(
            activityId: id,
            quantity: data.quantity,
            date: data.date,
            note: data.note,
          );
        case AssetTransactionAction.openingPosition:
          return;
      }
    }
  } catch (error) {
    if (context.mounted) {
      final message =
          error is StateError &&
              error.message == 'Sell quantity exceeds holdings'
          ? 'Jumlah yang dijual melebihi aset yang dimiliki.'
          : 'Aktivitas gagal disimpan. Coba lagi.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }
}

Future<void> _deleteActivity(
  BuildContext context,
  WidgetRef ref,
  int id,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Hapus aktivitas?'),
      content: const Text('Transaksi kas yang terhubung juga akan dihapus.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Hapus'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  try {
    await ref.read(assetActivityServiceProvider).delete(id);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Aktivitas gagal dihapus.')));
    }
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({
    required this.asset,
    required this.activity,
    required this.onEdit,
    required this.onDelete,
  });

  final AssetRecord asset;
  final AssetTransactionRecord activity;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final quantity = AssetQuantity.fromScaled(activity.quantityScaled);
    final label = switch (activity.action) {
      AssetTransactionAction.buy => 'Beli',
      AssetTransactionAction.sell => 'Jual',
      AssetTransactionAction.adjustment => 'Penyesuaian',
      AssetTransactionAction.openingPosition => 'Posisi Awal',
    };
    final prefix = activity.action == AssetTransactionAction.sell
        ? ''
        : activity.action == AssetTransactionAction.adjustment &&
              quantity.isNegative
        ? ''
        : '+';
    final historicalPrice = activity.priceAmount == null
        ? null
        : '${formatIdr(activity.priceAmount!)} / ${_priceUnit(asset)}';
    return Card(
      child: ListTile(
        title: Text(label),
        subtitle: Text(
          '${_formatPositionDate(context, activity.transactionDate)}\n'
          '$prefix${_formatAssetQuantity(asset, quantity)}'
          '${historicalPrice == null ? '' : ' @ $historicalPrice'}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (activity.totalAmount != null)
              Text(formatIdr(activity.totalAmount!)),
            PopupMenuButton<String>(
              tooltip: 'Tindakan aktivitas',
              onSelected: (value) => value == 'edit' ? onEdit() : onDelete(),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Ubah')),
                PopupMenuItem(value: 'delete', child: Text('Hapus')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityFormData {
  const _ActivityFormData({
    required this.quantity,
    required this.priceAmount,
    required this.accountId,
    required this.date,
    required this.note,
  });

  final AssetQuantity quantity;
  final int? priceAmount;
  final int? accountId;
  final DateTime date;
  final String? note;
}

class _ActivityFormDialog extends ConsumerStatefulWidget {
  const _ActivityFormDialog({
    required this.asset,
    required this.action,
    this.activity,
  });

  final AssetRecord asset;
  final AssetTransactionAction action;
  final AssetTransactionRecord? activity;

  @override
  ConsumerState<_ActivityFormDialog> createState() =>
      _ActivityFormDialogState();
}

class _ActivityFormDialogState extends ConsumerState<_ActivityFormDialog> {
  late final TextEditingController _quantity;
  late final TextEditingController _price;
  late final TextEditingController _note;
  late DateTime _date;
  late bool _increase;
  late bool _exactStockShares;
  int? _accountId;
  final _formKey = GlobalKey<FormState>();

  bool get isAdjustment => widget.action == AssetTransactionAction.adjustment;
  bool get isStock => widget.asset.assetType == AssetType.stock;

  @override
  void initState() {
    super.initState();
    final activity = widget.activity;
    final activityQuantity = activity == null
        ? null
        : AssetQuantity.fromScaled(activity.quantityScaled);
    _exactStockShares =
        isStock &&
        widget.action == AssetTransactionAction.adjustment &&
        activityQuantity != null &&
        activityQuantity.scaled % (AssetQuantity.scale * 100) != 0;
    final quantity = activity == null
        ? ''
        : _exactStockShares
        ? _formatStockSharesInput(activityQuantity!)
        : _inputActivityQuantity(widget.asset, activityQuantity!);
    _quantity = TextEditingController(text: quantity);
    _price = TextEditingController(
      text: activity?.priceAmount?.toString() ?? '',
    );
    _note = TextEditingController(text: activity?.note ?? '');
    _date = activity?.transactionDate ?? DateTime.now();
    _increase = activity?.quantityScaled.isNegative != true;
  }

  @override
  void dispose() {
    _quantity.dispose();
    _price.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider);
    final holding = ref.watch(holdingProvider(widget.asset.id)).valueOrNull;
    final previewShares = _exactStockShares
        ? int.tryParse(_quantity.text.trim())
        : _stockSharesPreview(_quantity.text);
    final title = switch (widget.action) {
      AssetTransactionAction.buy =>
        'Beli ${widget.asset.symbol ?? widget.asset.name}',
      AssetTransactionAction.sell =>
        'Jual ${widget.asset.symbol ?? widget.asset.name}',
      AssetTransactionAction.adjustment =>
        'Penyesuaian ${widget.asset.symbol ?? widget.asset.name}',
      AssetTransactionAction.openingPosition => 'Posisi Awal',
    };
    return AlertDialog(
      title: Text(title),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _quantity,
                keyboardType: TextInputType.numberWithOptions(
                  decimal: !isStock,
                ),
                decoration: InputDecoration(
                  labelText: _exactStockShares
                      ? 'Jumlah Lembar'
                      : isStock
                      ? 'Jumlah Lot'
                      : 'Jumlah ${_unitLabel(widget.asset)}',
                ),
                onChanged: (_) => setState(() {}),
                validator: (value) {
                  try {
                    final quantity = _parseActivityQuantity(
                      widget.asset,
                      value ?? '',
                      _increase,
                      exactStockShares: _exactStockShares,
                    );
                    return quantity.isZero ? 'Jumlah harus lebih dari 0' : null;
                  } catch (_) {
                    return _exactStockShares
                        ? 'Masukkan jumlah lembar bulat yang valid'
                        : isStock
                        ? 'Masukkan jumlah lot bulat yang valid'
                        : 'Jumlah maksimal 8 angka desimal';
                  }
                },
              ),
              if (isStock) ...[
                if (widget.action == AssetTransactionAction.sell &&
                    holding?.hasActivity == true)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Tersedia ${_formatStockQuantity(holding!.quantity)}',
                    ),
                  ),
                if (previewShares != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Jumlah Lembar: ${_formatInteger(previewShares)}',
                    ),
                  ),
              ],
              const SizedBox(height: AppSpacing.md),
              if (isAdjustment)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_increase ? 'Tambah jumlah' : 'Kurangi jumlah'),
                  value: _increase,
                  onChanged: (value) => setState(() => _increase = value),
                ),
              if (!isAdjustment) ...[
                TextFormField(
                  controller: _price,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: _activityPriceLabel(widget.asset),
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (value) => _parseMoney(value ?? '') <= 0
                      ? 'Harga harus lebih dari 0'
                      : null,
                ),
                if (_activityTotalPreview(
                      widget.asset,
                      _quantity.text,
                      _price.text,
                    )
                    case final total?)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Total: ${formatIdr(total)}'),
                  ),
                const SizedBox(height: AppSpacing.md),
                accounts.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: CircularProgressIndicator(),
                  ),
                  error: (_, _) => const Text('Akun belum dapat dimuat.'),
                  data: (items) {
                    final active = items
                        .where((item) => item.isActive)
                        .toList();
                    _accountId ??= active.firstOrNull?.id;
                    return DropdownButtonFormField<int>(
                      initialValue: active.any((item) => item.id == _accountId)
                          ? _accountId
                          : null,
                      decoration: const InputDecoration(labelText: 'Akun'),
                      items: [
                        for (final account in active)
                          DropdownMenuItem(
                            value: account.id,
                            child: Text(account.name),
                          ),
                      ],
                      onChanged: (value) => setState(() => _accountId = value),
                      validator: (value) =>
                          value == null ? 'Akun wajib dipilih' : null,
                    );
                  },
                ),
              ] else
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Penyesuaian mengubah jumlah aset tanpa membuat transaksi pemasukan atau pengeluaran.',
                  ),
                ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Tanggal'),
                subtitle: Text(_formatPositionDate(context, _date)),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (date != null) setState(() => _date = date);
                },
              ),
              TextFormField(
                controller: _note,
                decoration: const InputDecoration(
                  labelText: 'Catatan (opsional)',
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: accounts.isLoading && !isAdjustment ? null : _save,
          child: const Text('Simpan'),
        ),
      ],
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _ActivityFormData(
        quantity: _parseActivityQuantity(
          widget.asset,
          _quantity.text,
          _increase,
          exactStockShares: _exactStockShares,
        ),
        priceAmount: isAdjustment ? null : _parseMoney(_price.text),
        accountId: isAdjustment ? null : _accountId,
        date: _date,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      ),
    );
  }
}

String _inputActivityQuantity(AssetRecord asset, AssetQuantity quantity) {
  final magnitude = quantity.isNegative
      ? AssetQuantity.fromScaled(-quantity.scaled)
      : quantity;
  return _inputQuantity(asset, magnitude);
}

AssetQuantity _parseActivityQuantity(
  AssetRecord asset,
  String value,
  bool increase, {
  bool exactStockShares = false,
}) {
  final parsed = exactStockShares
      ? _parseExactStockShares(value)
      : _parseOpeningQuantity(asset, value);
  if (parsed.isZero) return parsed;
  return increase ? parsed : AssetQuantity.fromScaled(-parsed.scaled);
}

AssetQuantity _parseExactStockShares(String value) {
  final input = value.trim();
  if (!RegExp(r'^\d+$').hasMatch(input)) {
    throw const FormatException('Stock shares must be a whole number');
  }
  return AssetQuantity.fromScaled(int.parse(input) * AssetQuantity.scale);
}

String _formatStockSharesInput(AssetQuantity quantity) =>
    (quantity.scaled.abs() ~/ AssetQuantity.scale).toString();

class _PortfolioSummary extends StatelessWidget {
  const _PortfolioSummary({required this.snapshot, required this.market});

  final PortfolioSnapshot snapshot;
  final PortfolioMarketQuoteState market;

  @override
  Widget build(BuildContext context) {
    final value = snapshot.totalKnownValue;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              snapshot.isPartial || snapshot.isUnavailable
                  ? 'Nilai Portofolio'
                  : 'Total Portofolio',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              snapshot.isEmpty
                  ? 'Belum ada posisi aset'
                  : snapshot.isUnavailable
                  ? 'Belum tersedia'
                  : formatIdr(value!),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (!snapshot.isEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text('${snapshot.holdingAssetCount} aset aktif'),
            ],
            if (snapshot.isPartial)
              Text(
                'Nilai sementara • ${snapshot.unvaluedAssetCount} aset belum memiliki harga',
              ),
            if (snapshot.isUnavailable)
              const Text('Belum ada harga untuk aset yang dimiliki.'),
            if (_latestApiPriceUpdate(snapshot) case final updatedAt?)
              Text(
                'Harga pasar terakhir diperbarui ${_formatPositionDate(context, updatedAt)}',
              ),
            if (market.isRefreshing)
              const Text('Memperbarui harga saham dan crypto...'),
            if (!market.isRefreshing &&
                (market.failure != null || market.result.failures.isNotEmpty))
              const Text('Harga terbaru belum dapat diperbarui.'),
            if (snapshot.integrityIssueCount > 0)
              const Text('Ada posisi aset yang tidak valid.'),
            if (snapshot.groups.isNotEmpty) ...[
              const Divider(height: AppSpacing.lg),
              for (final type in AssetType.values)
                if (snapshot.groups[type] case final group?)
                  _DetailRow(
                    label: '${type.label} total',
                    value: group.isComplete
                        ? formatIdr(group.knownValue)
                        : '${formatIdr(group.knownValue)} • ${group.unvaluedAssetCount} harga belum tersedia',
                  ),
            ],
          ],
        ),
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

class _AssetCard extends StatelessWidget {
  const _AssetCard({
    required this.asset,
    required this.quantity,
    required this.hasActivity,
    this.price,
    this.valuation,
    this.quoteUnavailable = false,
    required this.onTap,
    required this.onEdit,
    required this.onArchive,
    required this.onDelete,
  });

  final AssetRecord asset;
  final AssetQuantity quantity;
  final bool hasActivity;
  final LocalAssetPrice? price;
  final AssetValuation? valuation;
  final bool quoteUnavailable;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onArchive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: asset.isActive
              ? colors.primaryContainer
              : colors.surfaceContainerHighest,
          child: Icon(_assetIcon(asset.assetType)),
        ),
        title: Text(_assetTitle(asset)),
        subtitle: Text(
          [
            asset.name,
            _formatAssetQuantity(asset, quantity, hasActivity: hasActivity),
            if (price != null)
              '${price!.isBackendStale
                  ? 'Harga terakhir'
                  : asset.pricingMode == AssetPricingMode.manual
                  ? _manualPriceLabel(asset)
                  : 'Harga'} ${formatIdr(price!.price)} / ${_priceUnit(asset)}',
            if (price == null && asset.pricingMode == AssetPricingMode.manual)
              'Harga belum diatur',
            if (price == null && asset.pricingMode == AssetPricingMode.api)
              'Harga belum tersedia',
            if (valuation?.currentValue != null)
              'Nilai ${formatIdr(valuation!.currentValue!)}',
            if (valuation != null && !valuation!.isValued)
              'Nilai belum tersedia',
            if (price == null && quoteUnavailable) 'Harga belum tersedia',
            if (asset.pricingMode == AssetPricingMode.api) 'Otomatis',
          ].join(' • '),
        ),
        trailing: PopupMenuButton<_AssetAction>(
          tooltip: 'Tindakan aset',
          onSelected: (action) => switch (action) {
            _AssetAction.edit => onEdit(),
            _AssetAction.archive => onArchive(),
            _AssetAction.delete => onDelete(),
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: _AssetAction.edit, child: Text('Ubah')),
            PopupMenuItem(
              value: _AssetAction.archive,
              child: Text(asset.isActive ? 'Arsipkan' : 'Aktifkan kembali'),
            ),
            const PopupMenuItem(
              value: _AssetAction.delete,
              child: Text('Hapus'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyAssets extends StatelessWidget {
  const _EmptyAssets({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inventory_2_outlined, size: 48),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Belum ada aset investasi',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'Tambahkan saham, crypto, reksadana, emas, atau aset lainnya yang ingin Anda pantau.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Tambah Aset'),
          ),
        ],
      ),
    ),
  );
}

class _AssetFormData {
  const _AssetFormData({
    required this.symbol,
    required this.name,
    required this.assetType,
    required this.pricingMode,
    required this.unitLabel,
  });

  final String? symbol;
  final String name;
  final AssetType assetType;
  final AssetPricingMode pricingMode;
  final String? unitLabel;
}

class _AssetFormDialog extends StatefulWidget {
  const _AssetFormDialog({this.asset});

  final AssetRecord? asset;

  @override
  State<_AssetFormDialog> createState() => _AssetFormDialogState();
}

class _AssetFormDialogState extends State<_AssetFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _symbol;
  late final TextEditingController _name;
  late AssetType _type;

  @override
  void initState() {
    super.initState();
    final asset = widget.asset;
    _symbol = TextEditingController(text: asset?.symbol);
    _name = TextEditingController(text: asset?.name);
    _type = asset?.assetType ?? AssetType.stock;
  }

  @override
  void dispose() {
    _symbol.dispose();
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _AssetFormData(
        symbol: _symbol.text.trim().isEmpty
            ? null
            : _symbol.text.trim().toUpperCase(),
        name: _name.text.trim(),
        assetType: _type,
        pricingMode: widget.asset?.pricingMode ?? _type.defaultPricingMode,
        unitLabel: _type.defaultUnitLabel,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.asset != null;
    final requiresSymbol =
        _type == AssetType.stock || _type == AssetType.crypto;
    return AlertDialog(
      title: Text(editing ? 'Ubah aset' : 'Tambah aset'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<AssetType>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Jenis aset'),
                items: [
                  for (final type in AssetType.values)
                    DropdownMenuItem(value: type, child: Text(type.label)),
                ],
                onChanged: editing
                    ? null
                    : (value) => setState(() => _type = value!),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _symbol,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText:
                      'Symbol / kode${requiresSymbol ? '' : ' (opsional)'}',
                  hintText: requiresSymbol ? 'Contoh: BBCA' : null,
                ),
                validator: (value) =>
                    requiresSymbol && (value == null || value.trim().isEmpty)
                    ? 'Symbol wajib diisi.'
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _name,
                autofocus: !requiresSymbol,
                textCapitalization: TextCapitalization.words,
                maxLength: 150,
                decoration: const InputDecoration(labelText: 'Nama aset'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Nama aset wajib diisi.'
                    : null,
              ),
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _type.defaultPricingMode == AssetPricingMode.api
                      ? 'Harga otomatis dari sumber market.'
                      : 'Harga dapat diatur dari detail aset.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(editing ? 'Simpan' : 'Tambah'),
        ),
      ],
    );
  }
}

enum _AssetAction { edit, archive, delete }

IconData _assetIcon(AssetType type) => switch (type) {
  AssetType.stock => Icons.show_chart,
  AssetType.crypto => Icons.currency_bitcoin,
  AssetType.mutualFund => Icons.account_balance,
  AssetType.gold => Icons.savings,
  AssetType.other => Icons.inventory_2,
};

String _assetError(Object error, {required bool editing}) {
  if (error is StateError && error.message == 'Asset symbol already exists') {
    return 'Aset dengan symbol tersebut sudah tersedia.';
  }
  return editing
      ? 'Aset gagal diperbarui. Coba lagi.'
      : 'Aset gagal disimpan. Coba lagi.';
}
