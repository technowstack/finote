import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:finote/features/app_lock/data/biometric_lock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/services/app_logger.dart';
import '../../../core/database/app_database.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../market/data/portfolio_market_quotes_provider.dart';
import '../data/backup_service.dart';
import '../domain/restore_error.dart';
import '../domain/restore_preview.dart';

class BackupPage extends ConsumerStatefulWidget {
  const BackupPage({super.key});

  @override
  ConsumerState<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends ConsumerState<BackupPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup dan restore'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.save_alt), text: 'Backup'),
            Tab(icon: Icon(Icons.restore), text: 'Restore'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [_BackupTab(), _RestoreTab()],
      ),
    );
  }
}

// =============================================================================
// TAB BACKUP
// =============================================================================

class _BackupTab extends ConsumerStatefulWidget {
  const _BackupTab();

  @override
  ConsumerState<_BackupTab> createState() => _BackupTabState();
}

class _BackupTabState extends ConsumerState<_BackupTab> {
  bool _creating = false;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 56,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Simpan salinan data Anda',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Backup berisi database dan informasi versi aplikasi dalam satu file ZIP.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _creating ? null : _createBackup,
                    icon: _creating
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_alt),
                    label: Text(
                      _creating ? 'Membuat backup...' : 'Buat backup',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const ListTile(
          contentPadding: EdgeInsets.symmetric(horizontal: 4),
          leading: Icon(Icons.folder_outlined),
          title: Text('Pilih lokasi penyimpanan'),
          subtitle: Text(
            'Android akan membuka pemilih file sistem. Aplikasi tidak meminta akses ke seluruh penyimpanan.',
          ),
        ),
      ],
    );
  }

  Future<void> _createBackup() async {
    setState(() => _creating = true);
    try {
      final saved = await ref.read(backupServiceProvider).createAndSave();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            saved ? 'Backup berhasil disimpan.' : 'Penyimpanan dibatalkan.',
          ),
        ),
      );
    } catch (error, stackTrace) {
      AppLogger.error('Failed to create local backup', error, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Backup gagal dibuat. Silakan coba lagi.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }
}

// =============================================================================
// TAB RESTORE
// =============================================================================

/// State restore mengikuti alur linear:
/// idle → selecting → validating → preview → safetyBackup → confirming
/// → restoring → success / error
enum _RestoreStep {
  idle,
  validating,
  preview,
  creatingsSafetyBackup,
  confirming,
  restoring,
  success,
  error,
}

class _RestoreTab extends ConsumerStatefulWidget {
  const _RestoreTab();

  @override
  ConsumerState<_RestoreTab> createState() => _RestoreTabState();
}

class _RestoreTabState extends ConsumerState<_RestoreTab> {
  _RestoreStep _step = _RestoreStep.idle;
  RestorePreview? _preview;
  BackupArchive? _safetyBackup;
  String? _errorMessage;

  // Format tanggal untuk preview
  final _dateFormat = DateFormat('d MMMM yyyy, HH:mm', 'id_ID');

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _buildBody(context),
          ),
        ),
        if (_step == _RestoreStep.success) ...[
          const SizedBox(height: 16),
          _buildSuccessInfo(context),
        ],
        if (_step == _RestoreStep.error) ...[
          const SizedBox(height: 16),
          _buildErrorCard(context),
        ],
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (_step) {
      // ----- IDLE -----
      case _RestoreStep.idle:
        return _buildIdleContent(context);

      // ----- LOADING STATES -----
      case _RestoreStep.validating:
        return _buildProgress('Memvalidasi file backup...');
      case _RestoreStep.creatingsSafetyBackup:
        return _buildProgress('Membuat safety backup data saat ini...');
      case _RestoreStep.restoring:
        return _buildProgress('Memulihkan data...');

      // ----- PREVIEW -----
      case _RestoreStep.preview:
        return _buildPreviewContent(context);

      // ----- CONFIRMING -----
      case _RestoreStep.confirming:
        return _buildProgress('Menunggu konfirmasi...');

      // ----- SUCCESS -----
      case _RestoreStep.success:
        return _buildSuccessContent(context);

      // ----- ERROR -----
      case _RestoreStep.error:
        return _buildErrorContent(context);
    }
  }

  // ---------------------------------------------------------------------------
  // Idle
  // ---------------------------------------------------------------------------

  Widget _buildIdleContent(BuildContext context) {
    return Column(
      children: [
        Icon(
          Icons.restore,
          size: 56,
          color: Theme.of(context).colorScheme.secondary,
        ),
        const SizedBox(height: 16),
        Text(
          'Pulihkan dari backup',
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          'Pilih file .zip yang sebelumnya Anda ekspor. '
          'Data saat ini akan diganti dengan isi backup.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _selectAndValidate,
            icon: const Icon(Icons.folder_open),
            label: const Text('Pilih file backup'),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Progress indicator
  // ---------------------------------------------------------------------------

  Widget _buildProgress(String label) {
    return Column(
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 20),
        Text(label, textAlign: TextAlign.center),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Preview
  // ---------------------------------------------------------------------------

  Widget _buildPreviewContent(BuildContext context) {
    final preview = _preview!;
    final manifest = preview.manifest;
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.info_outline, color: cs.primary),
            const SizedBox(width: 8),
            Text(
              'Informasi Backup',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _PreviewRow(
          label: 'Tanggal backup',
          value: _dateFormat.format(manifest.createdAt.toLocal()),
        ),
        _PreviewRow(label: 'Versi aplikasi', value: manifest.appVersion),
        _PreviewRow(
          label: 'Versi database',
          value: 'v${manifest.databaseVersion}',
        ),
        _PreviewRow(
          label: 'Format backup',
          value: 'v${manifest.backupVersion}',
        ),
        _PreviewRow(
          label: 'Jumlah transaksi',
          value: preview.transactionCount.toString(),
        ),
        _PreviewRow(
          label: 'Jumlah kategori',
          value: preview.categoryCount.toString(),
        ),
        _PreviewRow(
          label: 'Jumlah akun',
          value: preview.accountCount.toString(),
        ),
        _PreviewRow(
          label: 'Jumlah transfer',
          value: preview.transferCount.toString(),
        ),
        _PreviewRow(
          label: 'Volume transfer',
          value: formatIdr(preview.transferVolume),
        ),
        _PreviewRow(label: 'Jumlah aset', value: preview.assetCount.toString()),
        _PreviewRow(
          label: 'Aktivitas aset aktif',
          value: preview.assetActivityCount.toString(),
        ),
        _PreviewRow(
          label: 'Total pemasukan',
          value: formatIdr(preview.totalIncome),
        ),
        _PreviewRow(
          label: 'Total pengeluaran',
          value: formatIdr(preview.totalExpense),
        ),
        _PreviewRow(
          label: 'Rentang tanggal',
          value: preview.oldestTransactionAt == null
              ? '-'
              : '${DateFormat('d MMM yyyy').format(preview.oldestTransactionAt!)}'
                    ' - ${DateFormat('d MMM yyyy').format(preview.newestTransactionAt!)}',
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cs.errorContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: cs.error, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Semua data saat ini akan diganti dengan data dari backup ini.',
                  style: TextStyle(color: cs.onErrorContainer, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _resetToIdle,
                child: const Text('Batal'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: _proceedWithSafetyBackup,
                child: const Text('Lanjutkan'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Success
  // ---------------------------------------------------------------------------

  Widget _buildSuccessContent(BuildContext context) {
    return Column(
      children: [
        Icon(
          Icons.check_circle_outline,
          size: 56,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          'Restore berhasil',
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          'Data telah dipulihkan dan siap digunakan.',
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSuccessInfo(BuildContext context) {
    final safety = _safetyBackup;
    if (safety == null) return const SizedBox.shrink();

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: const Icon(Icons.shield_outlined),
      title: const Text('Safety backup tersimpan'),
      subtitle: Text(
        safety.fileName,
        style: Theme.of(context).textTheme.bodySmall,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Error
  // ---------------------------------------------------------------------------

  Widget _buildErrorContent(BuildContext context) {
    return Column(
      children: [
        Icon(
          Icons.error_outline,
          size: 56,
          color: Theme.of(context).colorScheme.error,
        ),
        const SizedBox(height: 16),
        Text(
          'Restore gagal',
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          _errorMessage ?? 'Terjadi kesalahan tak terduga.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _resetToIdle,
            child: const Text('Coba lagi'),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorCard(BuildContext context) {
    final safety = _safetyBackup;
    if (safety == null) return const SizedBox.shrink();

    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: ListTile(
        leading: Icon(
          Icons.shield_outlined,
          color: Theme.of(context).colorScheme.onErrorContainer,
        ),
        title: Text(
          'Safety backup aman',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onErrorContainer,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          'Data Anda sebelumnya tersimpan di:\n${safety.fileName}',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onErrorContainer,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Logic
  // ---------------------------------------------------------------------------

  /// STEP 1 + 2: pilih file → validasi
  Future<void> _selectAndValidate() async {
    final appLock = ref.read(appLockControllerProvider.notifier);

    appLock.beginExternalActivity();

    PlatformFile? file;
    try {
      file = await FilePicker.pickFile(
        dialogTitle: 'Pilih file backup',
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );
    } finally {
      appLock.endExternalActivity();
    }
    if (file == null) return;

    final path = file.path;
    if (path != null && await File(path).length() > 100 * 1024 * 1024) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'File backup terlalu besar.';
        _step = _RestoreStep.error;
      });
      return;
    }
    if (!mounted) return;

    setState(() => _step = _RestoreStep.validating);

    try {
      final zipBytes = await file.readAsBytes();
      final preview = await ref
          .read(backupServiceProvider)
          .parseRestoreFile(zipBytes);

      if (!mounted) return;
      setState(() {
        _preview = preview;
        _step = _RestoreStep.preview;
      });
    } on RestoreError catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toUserMessage();
        _step = _RestoreStep.error;
      });
    } catch (error, stackTrace) {
      AppLogger.error(
        'Unexpected error during restore validation',
        error,
        stackTrace,
      );
      if (!mounted) return;
      setState(() {
        _errorMessage = const RestoreError.unknown('').toUserMessage();
        _step = _RestoreStep.error;
      });
    }
  }

  /// STEP 3: buat safety backup → tampilkan dialog konfirmasi
  Future<void> _proceedWithSafetyBackup() async {
    setState(() => _step = _RestoreStep.creatingsSafetyBackup);

    BackupArchive safetyBackup;
    try {
      safetyBackup = await ref.read(backupServiceProvider).createSafetyBackup();
    } catch (error, stackTrace) {
      AppLogger.error('Failed to create safety backup', error, stackTrace);
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Safety backup gagal dibuat. Restore dibatalkan agar data tetap aman.';
        _step = _RestoreStep.error;
      });
      return;
    }

    if (!mounted) return;
    _safetyBackup = safetyBackup;

    // STEP 4: tampilkan dialog konfirmasi
    final confirmed = await _showConfirmDialog(safetyBackup);
    if (!mounted) return;
    if (!confirmed) {
      setState(() => _step = _RestoreStep.preview);
      return;
    }

    await _executeRestore();
  }

  /// STEP 5: eksekusi restore
  Future<void> _executeRestore() async {
    if (!mounted) return;
    setState(() => _step = _RestoreStep.restoring);

    try {
      ref.invalidate(portfolioMarketQuotesProvider);
      try {
        await ref
            .read(backupServiceProvider)
            .restoreFromArchive(_preview!.archiveBytes);
      } finally {
        ref.invalidate(databaseProvider);
        ref.invalidate(portfolioMarketQuotesProvider);
      }

      if (!mounted) return;
      setState(() => _step = _RestoreStep.success);
    } on RestoreError catch (e) {
      AppLogger.warning('Restore failed with RestoreError: ${e.runtimeType}');
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toUserMessage();
        _step = _RestoreStep.error;
      });
    } catch (error, stackTrace) {
      AppLogger.error('Unexpected error during restore', error, stackTrace);
      if (!mounted) return;
      setState(() {
        _errorMessage = const RestoreError.unknown('').toUserMessage();
        _step = _RestoreStep.error;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Dialogs
  // ---------------------------------------------------------------------------

  Future<bool> _showConfirmDialog(BackupArchive safety) async {
    final manifest = _preview!.manifest;
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Konfirmasi Restore'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Backup dari: ${_dateFormat.format(manifest.createdAt.toLocal())}',
                ),
                const SizedBox(height: 8),
                const Text(
                  'Data Anda saat ini akan ditimpa sepenuhnya oleh data dari backup ini.',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  'Safety backup tersimpan di:\n${safety.fileName}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Batal'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Ya, pulihkan'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _resetToIdle() {
    setState(() {
      _step = _RestoreStep.idle;
      _preview = null;
      _safetyBackup = null;
      _errorMessage = null;
    });
  }
}

// =============================================================================
// Helper widgets
// =============================================================================

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 140,
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
