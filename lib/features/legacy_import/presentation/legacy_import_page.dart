import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/app_logger.dart';
import '../../../core/utils/currency_formatter.dart';
import '../data/legacy_detector.dart';
import '../data/legacy_importer.dart';
import '../domain/legacy_detection_error.dart';
import '../domain/legacy_detection_result.dart';
import '../domain/legacy_import_summary.dart';

class LegacyImportPage extends ConsumerStatefulWidget {
  const LegacyImportPage({super.key});

  @override
  ConsumerState<LegacyImportPage> createState() => _LegacyImportPageState();
}

enum _ImportStep {
  idle,
  detecting,
  compatible,
  importing,
  success,
  incompatible,
  failed,
}

class _LegacyImportPageState extends ConsumerState<LegacyImportPage> {
  _ImportStep _step = _ImportStep.idle;
  LegacyDetectionResult? _result;
  LegacyImportSummary? _summary;
  String? _selectedPath;
  String? _errorMessage;
  int _importedCount = 0;
  int _importTotal = 0;

  final _detector = const LegacyDetector();
  final _dateFormat = DateFormat('d MMMM yyyy', 'id_ID');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import dari aplikasi lama')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: _buildBody(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (_step) {
      case _ImportStep.idle:
        return _buildIdle(context);
      case _ImportStep.detecting:
        return _buildDetecting();
      case _ImportStep.compatible:
        return _buildCompatible(context);
      case _ImportStep.importing:
        return _buildImporting(context);
      case _ImportStep.success:
        return _buildSuccess(context);
      case _ImportStep.incompatible:
        return _buildIncompatible(context);
      case _ImportStep.failed:
        return _buildFailed(context);
    }
  }

  // ---------------------------------------------------------------------------
  // Idle
  // ---------------------------------------------------------------------------

  Widget _buildIdle(BuildContext context) {
    return Column(
      children: [
        Icon(
          Icons.storage_outlined,
          size: 56,
          color: Theme.of(context).colorScheme.secondary,
        ),
        const SizedBox(height: 16),
        Text(
          'Import dari aplikasi lama',
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          'Pilih file database (.db / .sqlite) dari aplikasi '
          'Catatan Keuangan versi lama untuk memeriksa kompatibilitasnya.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _pickAndDetect,
            icon: const Icon(Icons.folder_open),
            label: const Text('Pilih file database'),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Detecting
  // ---------------------------------------------------------------------------

  Widget _buildDetecting() {
    return const Column(
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 20),
        Text('Memeriksa database...', textAlign: TextAlign.center),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Compatible
  // ---------------------------------------------------------------------------

  Widget _buildCompatible(BuildContext context) {
    final result = _result!;
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Icon(Icons.check_circle_outline, color: cs.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Preview data legacy',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(color: cs.primary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Metadata rows
        _InfoRow(
          label: 'Jumlah transaksi',
          value: result.transactionCount.toString(),
        ),
        _InfoRow(
          label: 'Jumlah kategori',
          value: result.categoryCount.toString(),
        ),
        _InfoRow(
          label: 'Transaksi pertama',
          value: result.oldestTransactionAt == null
              ? '-'
              : _dateFormat.format(result.oldestTransactionAt!.toLocal()),
        ),
        _InfoRow(
          label: 'Transaksi terakhir',
          value: result.newestTransactionAt == null
              ? '-'
              : _dateFormat.format(result.newestTransactionAt!.toLocal()),
        ),
        _InfoRow(
          label: 'Total pemasukan',
          value: formatIdr(result.totalIncome),
        ),
        _InfoRow(
          label: 'Total pengeluaran',
          value: formatIdr(result.totalExpense),
        ),
        _InfoRow(
          label: 'Tabel ditemukan',
          value: result.tablesRecognised.join(', '),
        ),

        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 16),

        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _startImport,
            icon: const Icon(Icons.upload_outlined),
            label: const Text('Mulai import'),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _resetToIdle,
            child: const Text('Pilih file lain'),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Incompatible
  // ---------------------------------------------------------------------------

  Widget _buildIncompatible(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Icon(Icons.error_outline, size: 56, color: cs.error),
        const SizedBox(height: 16),
        Text(
          'Database tidak kompatibel',
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          _errorMessage ?? 'Database ini tidak dapat diimpor.',
          textAlign: TextAlign.center,
          style: TextStyle(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _resetToIdle,
            child: const Text('Pilih file lain'),
          ),
        ),
      ],
    );
  }

  Widget _buildImporting(BuildContext context) {
    final progress = _importTotal == 0 ? null : _importedCount / _importTotal;
    return Column(
      children: [
        CircularProgressIndicator(value: progress),
        const SizedBox(height: 20),
        Text(
          _importTotal == 0
              ? 'Menyiapkan import...'
              : 'Mengimpor $_importedCount dari $_importTotal transaksi...',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Jangan tutup aplikasi sampai proses selesai.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSuccess(BuildContext context) {
    final summary = _summary!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.check_circle_outline,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'Import selesai',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _InfoRow(label: 'Transaksi baru', value: summary.newCount.toString()),
        _InfoRow(
          label: 'Duplikat dilewati',
          value: summary.duplicateCount.toString(),
        ),
        _InfoRow(label: 'Gagal', value: summary.failedCount.toString()),
        _InfoRow(
          label: 'Kategori baru',
          value: summary.categoriesCreated.toString(),
        ),
        _InfoRow(
          label: 'Total pemasukan',
          value: formatIdr(summary.totalIncome),
        ),
        _InfoRow(
          label: 'Total pengeluaran',
          value: formatIdr(summary.totalExpense),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _resetToIdle,
            child: const Text('Selesai'),
          ),
        ),
      ],
    );
  }

  Widget _buildFailed(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Icon(Icons.error_outline, size: 56, color: cs.error),
        const SizedBox(height: 16),
        Text('Import gagal', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          _errorMessage ?? 'Tidak ada data yang diimpor. Silakan coba lagi.',
          textAlign: TextAlign.center,
          style: TextStyle(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _startImport,
            child: const Text('Coba lagi'),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _resetToIdle,
            child: const Text('Pilih file lain'),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Logic
  // ---------------------------------------------------------------------------

  Future<void> _pickAndDetect() async {
    final file = await FilePicker.pickFile(
      dialogTitle: 'Pilih database legacy',
      type: FileType.any,
    );
    if (file == null) return;

    final path = file.path;
    if (path == null) return;

    setState(() {
      _step = _ImportStep.detecting;
      _result = null;
      _summary = null;
      _selectedPath = path;
      _errorMessage = null;
    });

    try {
      final detected = await _detector.detect(path);
      if (!mounted) return;
      setState(() {
        _result = detected;
        _step = _ImportStep.compatible;
      });
    } on LegacyDetectionError catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toUserMessage();
        _step = _ImportStep.incompatible;
      });
    } catch (error, stackTrace) {
      AppLogger.error(
        'Unexpected error during legacy detection',
        error,
        stackTrace,
      );
      if (!mounted) return;
      setState(() {
        _errorMessage = const LegacyDetectionError.unknown('').toUserMessage();
        _step = _ImportStep.incompatible;
      });
    }
  }

  Future<void> _startImport() async {
    final path = _selectedPath;
    if (path == null) return;

    setState(() {
      _step = _ImportStep.importing;
      _importedCount = 0;
      _importTotal = _result?.transactionCount ?? 0;
      _errorMessage = null;
    });

    try {
      final summary = await LegacyImporter(ref.read(databaseProvider)).import(
        path,
        onProgress: (completed, total) {
          if (!mounted) return;
          setState(() {
            _importedCount = completed;
            _importTotal = total;
          });
        },
      );
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _step = _ImportStep.success;
      });
    } catch (error, stackTrace) {
      AppLogger.error('Legacy import failed', error, stackTrace);
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Import dibatalkan. Tidak ada data yang disimpan.';
        _step = _ImportStep.failed;
      });
    }
  }

  void _resetToIdle() {
    setState(() {
      _step = _ImportStep.idle;
      _result = null;
      _summary = null;
      _selectedPath = null;
      _errorMessage = null;
      _importedCount = 0;
      _importTotal = 0;
    });
  }
}

// ---------------------------------------------------------------------------
// Helper widget
// ---------------------------------------------------------------------------

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
