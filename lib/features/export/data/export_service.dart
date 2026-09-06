import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:finote/features/app_lock/data/biometric_lock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../domain/export_document.dart';
import 'excel_exporter.dart';
import 'pdf_exporter.dart';
import 'text_exporter.dart';

enum ExportFormat { excel, text, pdf }

extension ExportFormatDetails on ExportFormat {
  String get label => switch (this) {
    ExportFormat.excel => 'Excel',
    ExportFormat.text => 'Text',
    ExportFormat.pdf => 'PDF',
  };

  String get extension => switch (this) {
    ExportFormat.excel => 'xlsx',
    ExportFormat.text => 'txt',
    ExportFormat.pdf => 'pdf',
  };

  String get mimeType => switch (this) {
    ExportFormat.excel =>
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    ExportFormat.text => 'text/plain',
    ExportFormat.pdf => 'application/pdf',
  };
}

class ExportService {
  ExportService(this._appLock);

  final AppLockController _appLock;
  Future<Uint8List> buildBytes(
    ExportDocument document,
    ExportFormat format,
  ) async {
    return switch (format) {
      ExportFormat.excel => buildExcelExport(document),
      ExportFormat.text => Uint8List.fromList(
        utf8.encode(buildTextExport(document)),
      ),
      ExportFormat.pdf => Uint8List.fromList(await buildPdfExport(document)),
    };
  }

  String fileName(ExportFormat format, {DateTime? now}) =>
      'finote_report_${DateFormat('yyyy-MM-dd').format(now ?? DateTime.now())}.${format.extension}';

  Future<bool> save(ExportDocument document, ExportFormat format) async {
    final name = fileName(format);

    // Buat file terlebih dahulu saat Finote masih aktif normal.
    final bytes = await buildBytes(document, format);
    _appLock.beginExternalActivity();

    try {
      final uri = await FilePicker.saveFile(
        dialogTitle: 'Simpan laporan',
        fileName: name,
        bytes: bytes,
        mimeType: format.mimeType,
      );
      return uri != null;
    } finally {
      _appLock.endExternalActivity();
    }
  }

  Future<void> share(ExportDocument document, ExportFormat format) async {
    final name = fileName(format);

    final bytes = await buildBytes(document, format);
    final file = XFile.fromData(bytes, name: name, mimeType: format.mimeType);

    _appLock.beginExternalActivity();

    try {
      await SharePlus.instance.share(
        ShareParams(files: [file], fileNameOverrides: [name]),
      );
    } finally {
      _appLock.endExternalActivity();
    }
  }
}

final exportServiceProvider = Provider<ExportService>(
  (ref) => ExportService(
    ref.read(appLockControllerProvider.notifier),
  ),
);