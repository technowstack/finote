import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../transactions/domain/transaction_source.dart';
import '../../transactions/domain/transaction_type.dart';
import '../../transactions/presentation/transaction_form_page.dart';
import '../data/device_receipt_image_picker.dart';
import '../data/rule_based_receipt_interpreter.dart';
import '../data/ml_kit_receipt_ocr_service.dart';
import '../domain/receipt_image.dart';
import '../domain/receipt_interpreter.dart';
import '../domain/receipt_ocr.dart';
import 'widgets/receipt_scan_view.dart';

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
    // Same precedence as before: processing, failed, result, idle, preview.
    final phase = _loading
        ? ReceiptScanPhase.processing
        : _ocrFailed
        ? ReceiptScanPhase.failed
        : _ocrResult != null
        ? ReceiptScanPhase.result
        : _image == null
        ? ReceiptScanPhase.idle
        : ReceiptScanPhase.preview;
    final image = _image;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Scan struk',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
      ),
      body: SafeArea(
        child: ReceiptScanView(
          phase: phase,
          error: _error,
          canOpenSettings: _canOpenSettings,
          recognizing: _recognizing,
          imageOrigin: image?.origin,
          imageReadable: _imageReadable,
          imageBuilder: image == null
              ? null
              : (context) => _previewImage(image),
          rawText: _ocrResult?.rawText ?? '',
          showDiagnostics: kDebugMode,
          onCamera: () => _pick(ReceiptImageOrigin.camera),
          onGallery: () => _pick(ReceiptImageOrigin.gallery),
          onManual: _openManualTransaction,
          onOpenSettings: _picker.openSettings,
          onRecognize: _recognize,
          onChangePhoto: _changePhoto,
          onReplace: image == null ? null : () => _replace(image.origin),
          onCancel: _cancel,
          onOpenReceiptDraft: _openReceiptDraft,
          onDiagnostics: _showDiagnostics,
        ),
      ),
    );
  }

  /// The photo itself. A decode failure flips the page into the
  /// unreadable-image state; that stays here, next to the file access.
  Widget _previewImage(ReceiptImage image) {
    return Image.file(
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
