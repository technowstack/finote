import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../app/main_scaffold.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/finote_colors.dart';
import '../../../core/widgets/app_snackbars.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../data/asset_repository.dart';
import '../data/asset_transaction_repository.dart';
import '../domain/asset_type.dart';
import '../../market/data/portfolio_market_quotes_provider.dart';
import '../../market/data/asset_price_repository.dart';
import '../../market/data/portfolio_valuation_service.dart';
import '../../market/domain/portfolio_valuation.dart';
import 'widgets/asset_composition_card.dart';
import 'widgets/asset_detail_view.dart';
import 'widgets/asset_form_dialog.dart';
import 'widgets/asset_formatters.dart';
import 'widgets/asset_list_item.dart';
import 'widgets/portfolio_summary_card.dart';

class AssetsPage extends ConsumerStatefulWidget {
  const AssetsPage({super.key, this.routePrefix = '/portfolio/assets'});

  final String routePrefix;

  @override
  ConsumerState<AssetsPage> createState() => _AssetsPageState();
}

class _AssetsPageState extends ConsumerState<AssetsPage> {
  Future<void> _openForm([AssetRecord? asset]) async {
    final data = await showDialog<AssetFormData>(
      context: context,
      builder: (context) => AssetFormDialog(asset: asset),
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
      if (mounted) _showError(assetErrorMessage(error, editing: asset != null));
    }
  }

  Future<void> _archive(AssetRecord asset) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Arsipkan aset?'),
        content: const Text(
          'Aset tidak aktif akan disembunyikan dari daftar aset aktif. '
          'Nilainya tidak dihitung dalam Portofolio dan Kekayaan Bersih '
          'hingga diaktifkan kembali. Data aktivitasnya tetap aman.',
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

  void _showError(String message) => showAppErrorSnackBar(context, message);

  @override
  Widget build(BuildContext context) {
    final assets = ref.watch(assetHoldingsProvider);
    final allAssets = ref.watch(allAssetHoldingsProvider);
    final market = ref.watch(portfolioMarketQuotesProvider);
    final prices = ref.watch(activeAssetPricesProvider).valueOrNull ?? {};
    final portfolio = ref.watch(portfolioValuationProvider).valueOrNull;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('Portofolio', style: theme.textTheme.headlineLarge),
        actions: [
          IconButton(
            tooltip: 'Refresh Harga',
            onPressed: market.isRefreshing || !assets.hasValue
                ? null
                : () async {
                    await ref
                        .read(portfolioMarketQuotesProvider.notifier)
                        .refresh();
                    if (!context.mounted) return;
                    final state = ref.read(portfolioMarketQuotesProvider);
                    final message = state.failure != null
                        ? 'Harga terbaru belum dapat diperbarui. Harga terakhir tetap digunakan.'
                        : state.result.failures.isNotEmpty
                        ? 'Sebagian harga tidak dapat diperbarui. Harga terakhir tetap digunakan.'
                        : state.result.quotes.isEmpty
                        ? 'Tidak ada harga pasar yang perlu diperbarui.'
                        : 'Harga berhasil diperbarui.';
                    showAppSnackBar(context, message);
                  },
            style: IconButton.styleFrom(
              backgroundColor: colors.primaryContainer,
              foregroundColor: colors.onPrimaryContainer,
              fixedSize: const Size(40, 40),
            ),
            icon: market.isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: assets.when(
        loading: () => const AppLoadingState(),
        error: (_, _) => AppErrorState(
          message: 'Aset belum dapat dimuat.',
          onRetry: () => ref.invalidate(assetHoldingsProvider),
        ),
        data: (active) {
          final all = allAssets.valueOrNull ?? active;
          final archived = all
              .where((holding) => !holding.asset.isActive)
              .toList();
          if (active.isEmpty && archived.isEmpty) {
            return AppEmptyState(
              icon: Icons.pie_chart_outline_rounded,
              message: 'Belum ada aset investasi',
              subtitle: 'Tambahkan saham, crypto, reksadana, emas, atau aset lainnya yang ingin Anda pantau.',
              actionLabel: 'Tambah Aset',
              onAction: _openForm,
            );
          }
          final valuations =
              portfolio?.byAssetId ?? const <int, AssetValuation>{};
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              AppSpacing.sm,
              AppSpacing.screenH,
              kFabClearance,
            ),
            children: [
              if (portfolio != null) ...[
                PortfolioSummaryCard(snapshot: portfolio, market: market),
                const SizedBox(height: AppSpacing.md),
                if (portfolio.groups.values.any((g) => g.knownValue > 0)) ...[
                  AssetCompositionCard(snapshot: portfolio),
                  const SizedBox(height: AppSpacing.md),
                ],
              ],
              if (active.isNotEmpty) ...[
                _SectionTitle(title: 'Aset aktif', count: active.length),
                ..._surfaceRows([
                  for (final holding in _sortedByType(active))
                    AssetListItem(
                      asset: holding.asset,
                      quantity: holding.quantity,
                      hasActivity: holding.hasActivity,
                      price: prices[holding.asset.id],
                      valuation: valuations[holding.asset.id],
                      onTap: () => context.push(
                        '${widget.routePrefix}/${holding.asset.id}',
                      ),
                      onEdit: () => _openForm(holding.asset),
                      onArchive: () => _archive(holding.asset),
                      onDelete: () => _delete(holding.asset),
                    ),
                ]),
              ],
              if (archived.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                _SectionTitle(title: 'Aset Diarsipkan'),
                ..._surfaceRows([
                  for (final holding in archived)
                    AssetListItem(
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
                ]),
              ],
            ],
          );
        },
      ),
      floatingActionButton: allAssets.valueOrNull?.isNotEmpty == true
          ? DecoratedBox(
              // Only the hero and the FAB carry a shadow (tokens: shadow.fab).
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: theme.finote.fabShadow,
              ),
              child: FloatingActionButton(
                heroTag: null,
                onPressed: _openForm,
                tooltip: 'Tambah aset',
                child: const Icon(Icons.add),
              ),
            )
          : null,
    );
  }

  /// One rounded surface made of separate rows, so a long list still builds
  /// lazily instead of as a single tall column.
  List<Widget> _surfaceRows(List<Widget> rows) {
    const radius = Radius.circular(AppRadius.lg);
    final colors = Theme.of(context).colorScheme;
    return [
      for (final (index, row) in rows.indexed)
        Material(
          color: colors.surface,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              top: index == 0 ? radius : Radius.zero,
              bottom: index == rows.length - 1 ? radius : Radius.zero,
            ),
          ),
          child: row,
        ),
    ];
  }

  /// Same order as before: by asset type, then by symbol (or name).
  List<AssetHolding> _sortedByType(List<AssetHolding> holdings) {
    final sorted = <AssetHolding>[];
    for (final type in AssetType.values) {
      final group =
          holdings.where((holding) => holding.asset.assetType == type).toList()
            ..sort((a, b) {
              final aKey = (a.asset.symbol ?? a.asset.name).toUpperCase();
              final bKey = (b.asset.symbol ?? b.asset.name).toUpperCase();
              return aKey.compareTo(bKey);
            });
      sorted.addAll(group);
    }
    return sorted;
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.count});

  final String title;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xs,
        0,
        AppSpacing.xs,
        AppSpacing.sm,
      ),
      child: SectionHeader(
        title: title,
        trailing: count == null
            ? null
            : Text('$count aset', style: Theme.of(context).textTheme.bodySmall),
      ),
    );
  }
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
        error: (_, _) => AppErrorState(
          message: 'Detail aset belum dapat dimuat.',
          onRetry: () => ref.invalidate(assetByIdProvider(assetId)),
        ),
        data: (item) => item == null
            ? const AppEmptyState(
                icon: Icons.inventory_2_outlined,
                message: 'Aset tidak ditemukan.',
              )
            : AssetDetailView(asset: item),
      ),
    );
  }
}
