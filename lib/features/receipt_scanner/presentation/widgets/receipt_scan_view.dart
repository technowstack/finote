import 'package:flutter/material.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/shared_widgets.dart';
import '../../domain/receipt_image.dart';

/// The scan flow's screens, one per phase. Presentation only: it receives the
/// state and callbacks, so it never touches the image picker, OCR or any
/// platform channel, and can be tested with plain values.
enum ReceiptScanPhase { idle, preview, processing, result, failed }

class ReceiptScanView extends StatelessWidget {
  const ReceiptScanView({
    super.key,
    required this.phase,
    this.error,
    this.canOpenSettings = false,
    this.recognizing = false,
    this.imageOrigin,
    this.imageReadable = true,
    this.imageBuilder,
    this.rawText = '',
    this.showDiagnostics = false,
    this.onCamera,
    this.onGallery,
    this.onManual,
    this.onOpenSettings,
    this.onRecognize,
    this.onChangePhoto,
    this.onReplace,
    this.onCancel,
    this.onOpenReceiptDraft,
    this.onDiagnostics,
  });

  final ReceiptScanPhase phase;
  final String? error;
  final bool canOpenSettings;

  /// Shown under the spinner while the text is being read.
  final bool recognizing;

  final ReceiptImageOrigin? imageOrigin;
  final bool imageReadable;

  /// Builds the photo. The page supplies it, so file and picker logic stay
  /// with the page.
  final WidgetBuilder? imageBuilder;

  final String rawText;

  /// Debug-only diagnostics entry, passed in instead of read from kDebugMode.
  final bool showDiagnostics;

  final VoidCallback? onCamera;
  final VoidCallback? onGallery;
  final VoidCallback? onManual;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onRecognize;
  final VoidCallback? onChangePhoto;
  final VoidCallback? onReplace;
  final VoidCallback? onCancel;
  final VoidCallback? onOpenReceiptDraft;
  final VoidCallback? onDiagnostics;

  @override
  Widget build(BuildContext context) {
    return switch (phase) {
      ReceiptScanPhase.processing => _processing(context),
      ReceiptScanPhase.failed => _failed(),
      ReceiptScanPhase.result => _result(context),
      ReceiptScanPhase.preview => _preview(context),
      ReceiptScanPhase.idle => _idle(context),
    };
  }

  Widget _processing(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (recognizing) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'Membaca struk...',
              style: AppTypography.bodyMd.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _idle(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenH),
      children: [
        const AppEmptyState(
          icon: Icons.document_scanner_outlined,
          message: 'Pilih foto struk',
          subtitle: 'Foto diproses secara lokal dan tidak disimpan permanen atau diunggah.',
        ),
        if (error != null) ...[
          _ErrorBox(
            message: error!,
            action: canOpenSettings
                ? TextButton(
                    onPressed: onOpenSettings,
                    child: const Text('Buka pengaturan'),
                  )
                : null,
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        FilledButton.icon(
          onPressed: onCamera,
          icon: const Icon(Icons.camera_alt_outlined),
          label: const Text('Ambil foto'),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: onGallery,
          icon: const Icon(Icons.photo_library_outlined),
          label: const Text('Pilih dari galeri'),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton(
          onPressed: onManual,
          child: const Text('Isi transaksi manual'),
        ),
      ],
    );
  }

  Widget _preview(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenH),
      children: [
        Text(
          'Pratinjau foto',
          style: AppTypography.titleSheet.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Pastikan seluruh struk terlihat, tidak blur, dan pencahayaan cukup.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.lg),
        ClipRRect(
          borderRadius: AppRadius.mdAll,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 480),
            child: imageReadable
                ? (imageBuilder?.call(context) ?? const SizedBox.shrink())
                : const AppEmptyState(
                    icon: Icons.broken_image_outlined,
                    message: 'Gambar tidak dapat dibaca.',
                  ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          onPressed: imageReadable ? onRecognize : null,
          child: const Text('Gunakan foto'),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton(
          onPressed: onReplace,
          child: Text(
            imageOrigin == ReceiptImageOrigin.camera
                ? 'Ambil ulang'
                : 'Ganti foto',
          ),
        ),
        TextButton(onPressed: onCancel, child: const Text('Batal')),
      ],
    );
  }

  Widget _result(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenH),
      children: [
        Text(
          'Hasil OCR',
          style: AppTypography.titleSheet.copyWith(color: colors.onSurface),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Teks ini hanya untuk ditinjau. Belum ada transaksi yang dibuat.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.lg),
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceContainer,
            borderRadius: AppRadius.mdAll,
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: SelectableText(rawText),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (showDiagnostics) ...[
          OutlinedButton.icon(
            onPressed: onDiagnostics,
            icon: const Icon(Icons.bug_report_outlined),
            label: const Text('Lihat detail teknis'),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        FilledButton(
          onPressed: onOpenReceiptDraft,
          child: const Text('Tinjau draft pengeluaran'),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton(
          onPressed: onChangePhoto,
          child: const Text('Ganti foto'),
        ),
        TextButton(onPressed: onCancel, child: const Text('Selesai')),
      ],
    );
  }

  Widget _failed() {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenH),
      children: [
        const AppEmptyState(
          icon: Icons.document_scanner_outlined,
          message: 'Struk belum berhasil dibaca.',
          subtitle: 'Coba gunakan foto yang lebih terang dan tidak blur.',
        ),
        FilledButton(onPressed: onRecognize, child: const Text('Coba lagi')),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton(
          onPressed: onChangePhoto,
          child: const Text('Ganti foto'),
        ),
        TextButton(onPressed: onManual, child: const Text('Isi manual')),
      ],
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message, this.action});

  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: AppRadius.mdAll,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMd.copyWith(
                color: colors.onErrorContainer,
              ),
            ),
            ?action,
          ],
        ),
      ),
    );
  }
}
