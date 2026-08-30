import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../transactions/domain/transaction_source.dart';
import '../../transactions/domain/transaction_type.dart';
import '../../transactions/presentation/transaction_form_page.dart';
import '../data/device_receipt_image_picker.dart';
import '../data/rule_based_receipt_interpreter.dart';
import '../data/ml_kit_receipt_ocr_service.dart';
import '../domain/receipt_image.dart';
import '../domain/receipt_interpreter.dart';
import '../domain/receipt_ocr.dart';

class ReceiptScannerPage extends ConsumerStatefulWidget {
  const ReceiptScannerPage({super.key});

  @override
  ConsumerState<ReceiptScannerPage> createState() => _ReceiptScannerPageState();
}

class _ReceiptScannerPageState extends ConsumerState<ReceiptScannerPage> {
  late final ReceiptImagePicker _picker;
  late final ReceiptOcrService _ocrService;
  late final ReceiptInterpreter _interpreter;
  ReceiptImage? _image;
  ReceiptOcrResult? _ocrResult;
  String? _error;
  bool _loading = false;
  bool _recognizing = false;
  bool _ocrFailed = false;
  bool _imageReadable = true;
  bool _canOpenSettings = false;

  @override
  void initState() {
    super.initState();
    _picker = ref.read(receiptImagePickerProvider);
    _ocrService = ref.read(receiptOcrServiceProvider);
    _interpreter = ref.read(receiptInterpreterProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) => _showSourceSheet());
  }

  @override
  void dispose() {
    final image = _image;
    if (image != null) {
      unawaited(_picker.discard(image));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan struk')),
      body: SafeArea(
        child: _loading
            ? _buildLoading()
            : _ocrFailed
            ? _buildOcrFailure()
            : _ocrResult != null
            ? _buildOcrResult(context)
            : _image == null
            ? _buildSourceSelection(context)
            : _buildPreview(context),
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (_recognizing) ...[
            const SizedBox(height: AppSpacing.md),
            const Text('Membaca struk...'),
          ],
        ],
      ),
    );
  }

  Widget _buildSourceSelection(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenH),
      children: [
        const AppEmptyState(
          icon: Icons.document_scanner_outlined,
          message: 'Pilih foto struk',
          subtitle: 'Foto diproses secara lokal dan tidak disimpan permanen atau diunggah.',
        ),
        if (_error != null) ...[
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: colors.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  _error!,
                  style: TextStyle(color: colors.onErrorContainer),
                  textAlign: TextAlign.center,
                ),
                if (_canOpenSettings)
                  TextButton(
                    onPressed: _picker.openSettings,
                    child: const Text('Buka pengaturan'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        FilledButton.icon(
          onPressed: () => _pick(ReceiptImageOrigin.camera),
          icon: const Icon(Icons.camera_alt_outlined),
          label: const Text('Ambil foto'),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: () => _pick(ReceiptImageOrigin.gallery),
          icon: const Icon(Icons.photo_library_outlined),
          label: const Text('Pilih dari galeri'),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton(
          onPressed: _openManualTransaction,
          child: const Text('Isi transaksi manual'),
        ),
      ],
    );
  }

  Widget _buildPreview(BuildContext context) {
    final image = _image!;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenH),
      children: [
        Text('Pratinjau foto', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          'Pastikan seluruh struk terlihat, tidak blur, dan pencahayaan cukup.',
        ),
        const SizedBox(height: AppSpacing.lg),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 480),
            child: _imageReadable
                ? Image.file(
                    File(image.path),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted && _imageReadable) {
                          setState(() {
                            _imageReadable = false;
                            _error = 'Gambar tidak dapat dibaca.';
                          });
                        }
                      });
                      return const SizedBox.shrink();
                    },
                  )
                : const AppEmptyState(
                    icon: Icons.broken_image_outlined,
                    message: 'Gambar tidak dapat dibaca.',
                  ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          onPressed: _imageReadable ? _recognize : null,
          child: const Text('Gunakan foto'),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton(
          onPressed: () => _replace(image.origin),
          child: Text(
            image.origin == ReceiptImageOrigin.camera
                ? 'Ambil ulang'
                : 'Ganti foto',
          ),
        ),
        TextButton(onPressed: _cancel, child: const Text('Batal')),
      ],
    );
  }

  Widget _buildOcrResult(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenH),
      children: [
        Text('Hasil OCR', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          'Teks ini hanya untuk ditinjau. Belum ada transaksi yang dibuat.',
        ),
        const SizedBox(height: AppSpacing.lg),
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: colors.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: SelectableText(_ocrResult!.rawText),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (kDebugMode) ...[
          OutlinedButton.icon(
            onPressed: _showDiagnostics,
            icon: const Icon(Icons.bug_report_outlined),
            label: const Text('Lihat detail teknis'),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        FilledButton(
          onPressed: _openReceiptDraft,
          child: const Text('Tinjau draft pengeluaran'),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton(
          onPressed: _changePhoto,
          child: const Text('Ganti foto'),
        ),
        TextButton(onPressed: _cancel, child: const Text('Selesai')),
      ],
    );
  }

  Widget _buildOcrFailure() {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenH),
      children: [
        const AppEmptyState(
          icon: Icons.document_scanner_outlined,
          message: 'Struk belum berhasil dibaca.',
          subtitle: 'Coba gunakan foto yang lebih terang dan tidak blur.',
        ),
        FilledButton(onPressed: _recognize, child: const Text('Coba lagi')),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton(
          onPressed: _changePhoto,
          child: const Text('Ganti foto'),
        ),
        TextButton(
          onPressed: _openManualTransaction,
          child: const Text('Isi manual'),
        ),
      ],
    );
  }

  Future<void> _showSourceSheet() async {
    if (!mounted || _image != null || _loading) return;
    final origin = await showModalBottomSheet<ReceiptImageOrigin>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Ambil foto'),
                subtitle: const Text('Gunakan kamera perangkat'),
                onTap: () => Navigator.pop(context, ReceiptImageOrigin.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Pilih dari galeri'),
                subtitle: const Text('Gunakan pemilih foto sistem'),
                onTap: () => Navigator.pop(context, ReceiptImageOrigin.gallery),
              ),
            ],
          ),
        ),
      ),
    );
    if (origin != null && mounted) await _pick(origin);
  }

  Future<void> _pick(ReceiptImageOrigin origin) async {
    setState(() {
      _loading = true;
      _error = null;
      _canOpenSettings = false;
      _imageReadable = true;
    });
    try {
      final image = await _picker.pick(origin);
      if (!mounted) {
        if (image != null) {
          await _picker.discard(image);
        }
        return;
      }
      setState(() {
        _image = image;
        _loading = false;
      });
    } on ReceiptImageFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _messageFor(failure.reason);
        _canOpenSettings =
            failure.reason ==
            ReceiptImageFailureReason.permissionPermanentlyDenied;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = origin == ReceiptImageOrigin.camera
            ? 'Tidak dapat membuka kamera.'
            : 'Gambar tidak dapat dibaca.';
      });
    }
  }

  Future<void> _replace(ReceiptImageOrigin origin) async {
    await _discardCurrent();
    if (mounted) await _pick(origin);
  }

  Future<void> _changePhoto() async {
    await _discardCurrent();
    if (mounted) await _showSourceSheet();
  }

  Future<void> _recognize() async {
    final image = _image;
    if (image == null) return;
    setState(() {
      _loading = true;
      _recognizing = true;
      _ocrFailed = false;
    });
    try {
      final result = await _ocrService.recognize(image);
      if (!mounted) return;
      setState(() {
        _ocrResult = result.rawText.trim().isEmpty ? null : result;
        _ocrFailed = result.rawText.trim().isEmpty;
        _loading = false;
        _recognizing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _ocrFailed = true;
        _loading = false;
        _recognizing = false;
      });
    }
  }

  Future<void> _discardCurrent() async {
    final image = _image;
    _image = null;
    _ocrResult = null;
    _ocrFailed = false;
    if (image != null) {
      await _picker.discard(image);
    }
  }

  Future<void> _cancel() async {
    await _discardCurrent();
    if (mounted && context.canPop()) context.pop();
  }

  Future<void> _openManualTransaction() async {
    await _discardCurrent();
    if (mounted) context.pushReplacement('/transactions/new');
  }

  Future<void> _openReceiptDraft() async {
    final result = _ocrResult;
    if (result == null) return;
    final receipt = await _interpreter.interpret(result);
    final review = receipt.toReviewData();
    final draft = TransactionFormDraft(
      type: TransactionType.expense,
      source: TransactionSource.receiptScan,
      amount: review.total,
      title: review.merchant ?? '',
      date: review.transactionDate,
      receiptReview: review,
    );
    await _discardCurrent();
    if (mounted) {
      context.pushReplacement('/transactions/new', extra: draft);
    }
  }

  Future<void> _showDiagnostics() async {
    final result = _ocrResult;
    if (result == null || !mounted) return;
    final receipt = await _interpreter.interpret(result);
    if (!mounted) return;
    final items = receipt.items
        .map(
          (item) =>
              '${item.name}: qty=${item.quantity ?? '-'}, unit=${item.unitPrice ?? '-'}, total=${item.lineTotal ?? '-'}',
        )
        .join('\n');
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Detail parser'),
        content: SingleChildScrollView(
          child: SelectableText('''
merchant: ${receipt.merchant ?? '-'}
date: ${receipt.transactionDate?.toIso8601String() ?? '-'}
subtotal: ${receipt.subtotal ?? '-'}
tax: ${receipt.tax ?? '-'}
discount: ${receipt.discount ?? '-'}
total: ${receipt.total ?? '-'}
receipt number: ${receipt.receiptNumber ?? '-'}
items: ${receipt.items.length}
$items
'''),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  String _messageFor(ReceiptImageFailureReason reason) => switch (reason) {
    ReceiptImageFailureReason.permissionDenied =>
      'Izin kamera diperlukan untuk memindai struk.',
    ReceiptImageFailureReason.permissionPermanentlyDenied => 'Izin kamera ditolak permanen. Aktifkan izin kamera melalui pengaturan aplikasi.',
    ReceiptImageFailureReason.cameraUnavailable =>
      'Tidak dapat membuka kamera.',
    ReceiptImageFailureReason.unreadableImage => 'Gambar tidak dapat dibaca.',
  };
}
