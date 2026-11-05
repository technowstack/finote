import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../export/data/export_service.dart';
import '../../../export/domain/export_document.dart';
import '../../../transactions/domain/transaction_type.dart';

class ReportExportDialog extends ConsumerStatefulWidget {
  const ReportExportDialog({super.key, required this.document});

  final ExportDocument document;

  @override
  ConsumerState<ReportExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends ConsumerState<ReportExportDialog> {
  ExportFormat _format = ExportFormat.excel;
  TransactionType? _type;
  bool _busy = false;

  ExportDocument get _document => _type == null
      ? widget.document
      : ExportDocument(
          filter: ExportFilter(
            startDate: widget.document.filter.startDate,
            endDate: widget.document.filter.endDate,
            type: _type,
            categoryId: widget.document.filter.categoryId,
          ),
          generatedAt: widget.document.generatedAt,
          transactions: widget.document.transactions
              .where((row) => row.type == _type)
              .toList(growable: false),
          accounts: widget.document.accounts,
          transfers: const [],
        );

  @override
  Widget build(BuildContext context) {
    final document = _document;
    return AlertDialog(
      title: const Text('Export Laporan'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Periode: ${_periodLabel(document)}'),
            Text('${document.transactions.length} transaksi'),
            const SizedBox(height: AppSpacing.sm),
            Text('Pemasukan: ${formatIdr(document.totalIncome)}'),
            Text('Pengeluaran: ${formatIdr(document.totalExpense)}'),
            Text('Saldo periode: ${formatIdr(document.balance)}'),
            Text('Kas & dompet saat ini: ${formatIdr(document.totalAssets)}'),
            Text(
              '${document.transfers.length} transfer: '
              '${formatIdr(document.transferVolume)}',
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<ExportFormat>(
              isExpanded: true,
              initialValue: _format,
              decoration: const InputDecoration(labelText: 'Format'),
              items: [
                for (final format in ExportFormat.values)
                  DropdownMenuItem(value: format, child: Text(format.label)),
              ],
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _format = value!),
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<TransactionType?>(
              isExpanded: true,
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Jenis transaksi'),
              items: const [
                DropdownMenuItem(value: null, child: Text('Semua jenis')),
                DropdownMenuItem(
                  value: TransactionType.income,
                  child: Text('Pemasukan'),
                ),
                DropdownMenuItem(
                  value: TransactionType.expense,
                  child: Text('Pengeluaran'),
                ),
              ],
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _type = value),
            ),
            if (document.transactions.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: AppSpacing.sm),
                child: Text('Tidak ada transaksi pada periode ini.'),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        OutlinedButton(
          onPressed: _busy ? null : _share,
          child: const Text('Bagikan'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: const Text('Simpan'),
        ),
      ],
    );
  }

  Future<void> _save() => _run(
    (service, document) => service.save(document, _format),
    'File berhasil dibuat.',
  );

  Future<void> _share() => _run((service, document) async {
    await service.share(document, _format);
    return true;
  }, 'File siap dibagikan.');

  Future<void> _run(
    Future<bool> Function(ExportService, ExportDocument) action,
    String success,
  ) async {
    setState(() => _busy = true);
    try {
      final result = await action(ref.read(exportServiceProvider), _document);
      if (!mounted) return;
      if (result) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(success)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Gagal menyimpan file.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

String _periodLabel(ExportDocument document) {
  final start = document.filter.startDate;
  final end = document.filter.endDate;
  if (start == null && end == null) return 'Semua transaksi';
  return '${DateFormat('d MMM y', 'id_ID').format(start!)} - ${DateFormat('d MMM y', 'id_ID').format(end!)}';
}
