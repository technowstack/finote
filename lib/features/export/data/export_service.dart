import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
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
    final uri = await FilePicker.saveFile(
      dialogTitle: 'Simpan laporan',
      fileName: name,
      bytes: await buildBytes(document, format),
      mimeType: format.mimeType,
    );
    return uri != null;
  }

  Future<void> share(ExportDocument document, ExportFormat format) async {
    final name = fileName(format);
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            await buildBytes(document, format),
            name: name,
            mimeType: format.mimeType,
          ),
        ],
        fileNameOverrides: [name],
      ),
    );
  }
}

final exportServiceProvider = Provider<ExportService>((ref) => ExportService());
