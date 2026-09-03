import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    return Scaffold(
      appBar: AppBar(title: const Text('Portofolio')),
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
              Text('Aset Saya', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              if (active.isNotEmpty) ..._groupedAssets(active),
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

  List<Widget> _groupedAssets(List<AssetHolding> holdings) {
    final widgets = <Widget>[];
    for (final type in AssetType.values) {
      final group = holdings
          .where((holding) => holding.asset.assetType == type)
          .toList();
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
                _DetailRow(
                  label: 'Harga',
                  value: asset.pricingMode == AssetPricingMode.api
                      ? 'Otomatis'
                      : 'Manual',
                ),
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
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    ),
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
    final shares = quantity.scaled ~/ AssetQuantity.scale;
    if (shares % 100 == 0) return '${shares ~/ 100} lot';
    return '$quantity saham';
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
    return Card(
      child: ListTile(
        title: Text(label),
        subtitle: Text(
          '${_formatPositionDate(context, activity.transactionDate)}\n'
          '$prefix${_formatAssetQuantity(asset, quantity)}',
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
  int? _accountId;
  final _formKey = GlobalKey<FormState>();

  bool get isAdjustment => widget.action == AssetTransactionAction.adjustment;
  bool get isStock => widget.asset.assetType == AssetType.stock;

  @override
  void initState() {
    super.initState();
    final activity = widget.activity;
    final quantity = activity == null
        ? ''
        : _inputActivityQuantity(
            widget.asset,
            AssetQuantity.fromScaled(activity.quantityScaled),
          );
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
                  labelText: 'Jumlah ${_unitLabel(widget.asset)}',
                ),
                validator: (value) {
                  try {
                    final quantity = _parseActivityQuantity(
                      widget.asset,
                      value ?? '',
                      _increase,
                    );
                    return quantity.isZero ? 'Jumlah harus lebih dari 0' : null;
                  } catch (_) {
                    return isStock
                        ? 'Masukkan jumlah lot bulat yang valid'
                        : 'Jumlah maksimal 8 angka desimal';
                  }
                },
              ),
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
                  decoration: const InputDecoration(
                    labelText: 'Harga per unit (IDR)',
                  ),
                  validator: (value) => _parseMoney(value ?? '') <= 0
                      ? 'Harga harus lebih dari 0'
                      : null,
                ),
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
  bool increase,
) {
  final parsed = _parseOpeningQuantity(asset, value);
  if (parsed.isZero) return parsed;
  return increase ? parsed : AssetQuantity.fromScaled(-parsed.scaled);
}

class _AssetCard extends StatelessWidget {
  const _AssetCard({
    required this.asset,
    required this.quantity,
    required this.hasActivity,
    required this.onTap,
    required this.onEdit,
    required this.onArchive,
    required this.onDelete,
  });

  final AssetRecord asset;
  final AssetQuantity quantity;
  final bool hasActivity;
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
        title: Text(asset.symbol ?? asset.name),
        subtitle: Text(
          '${asset.name} • ${_formatAssetQuantity(asset, quantity, hasActivity: hasActivity)} • '
          '${asset.pricingMode == AssetPricingMode.api ? 'Otomatis' : 'Manual'}',
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
                      ? 'Harga otomatis. Pembaruan harga tersedia pada fase berikutnya.'
                      : 'Harga manual. Pengisian harga tersedia pada fase berikutnya.',
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
