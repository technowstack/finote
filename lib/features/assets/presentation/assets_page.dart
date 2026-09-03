import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../data/asset_repository.dart';
import '../domain/asset_type.dart';

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
    final assets = ref.watch(allAssetsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Portofolio')),
      body: assets.when(
        loading: () => const AppLoadingState(),
        error: (_, _) => AppErrorState(
          message: 'Aset belum dapat dimuat.',
          onRetry: () => ref.invalidate(allAssetsProvider),
        ),
        data: (items) {
          final active = items.where((asset) => asset.isActive).toList();
          final archived = items.where((asset) => !asset.isActive).toList();
          if (items.isEmpty) {
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
              ..._groupedAssets(active),
              if (archived.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Aset Diarsipkan',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                for (final asset in archived) ...[
                  _AssetCard(
                    asset: asset,
                    onTap: () =>
                        context.push('${widget.routePrefix}/${asset.id}'),
                    onEdit: () => _openForm(asset),
                    onArchive: () => _reactivate(asset),
                    onDelete: () => _delete(asset),
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

  List<Widget> _groupedAssets(List<AssetRecord> assets) {
    final widgets = <Widget>[];
    for (final type in AssetType.values) {
      final group = assets.where((asset) => asset.assetType == type).toList();
      if (group.isEmpty) continue;
      widgets.add(
        Text(type.label, style: Theme.of(context).textTheme.titleMedium),
      );
      widgets.add(const SizedBox(height: AppSpacing.sm));
      for (final asset in group) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _AssetCard(
              asset: asset,
              onTap: () => context.push('${widget.routePrefix}/${asset.id}'),
              onEdit: () => _openForm(asset),
              onArchive: () => _archive(asset),
              onDelete: () => _delete(asset),
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

class _AssetDetail extends StatelessWidget {
  const _AssetDetail({required this.asset});

  final AssetRecord asset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
        const Text(
          'Posisi aset akan tersedia setelah Opening Position ditambahkan.',
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

class _AssetCard extends StatelessWidget {
  const _AssetCard({
    required this.asset,
    required this.onTap,
    required this.onEdit,
    required this.onArchive,
    required this.onDelete,
  });

  final AssetRecord asset;
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
          asset.symbol == null
              ? '${asset.name} • ${asset.pricingMode == AssetPricingMode.api ? 'Otomatis' : 'Manual'}'
              : '${asset.name} • ${asset.pricingMode == AssetPricingMode.api ? 'Otomatis' : 'Manual'}',
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
