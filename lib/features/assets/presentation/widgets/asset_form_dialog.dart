import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/asset_type.dart';

class AssetFormData {
  const AssetFormData({
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

class AssetFormDialog extends StatefulWidget {
  const AssetFormDialog({super.key, this.asset});

  final AssetRecord? asset;

  @override
  State<AssetFormDialog> createState() => _AssetFormDialogState();
}

class _AssetFormDialogState extends State<AssetFormDialog> {
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
      AssetFormData(
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
                      'Simbol / kode${requiresSymbol ? '' : ' (opsional)'}',
                  hintText: requiresSymbol ? 'Contoh: BBCA' : null,
                ),
                validator: (value) =>
                    requiresSymbol && (value == null || value.trim().isEmpty)
                    ? 'Simbol wajib diisi.'
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
                      ? 'Harga otomatis dari sumber pasar.'
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
