import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/services/app_logger.dart';
import '../../../core/utils/currency_formatter.dart';
import '../data/legacy_detector.dart';
import '../domain/legacy_detection_error.dart';
import '../domain/legacy_detection_result.dart';

/// Halaman deteksi database legacy Catatan Keuangan.
///
/// Alur:
/// 1. Pilih file database (.db / .sqlite / .sqlite3)
/// 2. Detector membaca metadata secara read-only
/// 3. Tampilkan hasil: kompatibel / tidak kompatibel
///
/// Import belum diimplementasikan di fase ini.
class LegacyImportPage extends StatefulWidget {
  const LegacyImportPage({super.key});

  @override
  State<LegacyImportPage> createState() => _LegacyImportPageState();
}

enum _DetectionStep { idle, detecting, compatible, incompatible }

class _LegacyImportPageState extends State<LegacyImportPage> {
  _DetectionStep _step = _DetectionStep.idle;
  LegacyDetectionResult? _result;
  String? _errorMessage;

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
          if (_step == _DetectionStep.compatible) ...[
            const SizedBox(height: 16),
            _buildImportNotice(context),
          ],
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (_step) {
      case _DetectionStep.idle:
        return _buildIdle(context);
      case _DetectionStep.detecting:
        return _buildDetecting();
      case _DetectionStep.compatible:
        return _buildCompatible(context);
      case _DetectionStep.incompatible:
        return _buildIncompatible(context);
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

        // Import button — disabled (belum diimplementasi di fase ini)
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            // Import belum diimplementasi — Phase 2D
            onPressed: null,
            icon: const Icon(Icons.upload_outlined),
            label: const Text('Mulai import (segera hadir)'),
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

  // ---------------------------------------------------------------------------
  // Import notice (phase placeholder)
  // ---------------------------------------------------------------------------

  Widget _buildImportNotice(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Icon(
        Icons.info_outline,
        color: Theme.of(context).colorScheme.secondary,
      ),
      title: const Text('Import belum tersedia'),
      subtitle: const Text(
        'Fitur import data dari aplikasi lama akan tersedia pada update berikutnya.',
      ),
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
      _step = _DetectionStep.detecting;
      _result = null;
      _errorMessage = null;
    });

    try {
      final detected = await _detector.detect(path);
      if (!mounted) return;
      setState(() {
        _result = detected;
        _step = _DetectionStep.compatible;
      });
    } on LegacyDetectionError catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toUserMessage();
        _step = _DetectionStep.incompatible;
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
        _step = _DetectionStep.incompatible;
      });
    }
  }

  void _resetToIdle() {
    setState(() {
      _step = _DetectionStep.idle;
      _result = null;
      _errorMessage = null;
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
