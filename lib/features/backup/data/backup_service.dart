import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../../core/database/app_database.dart';
import '../domain/backup_manifest.dart';

class BackupService {
  BackupService(this._database);

  final AppDatabase _database;

  Future<bool> createAndSave() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final backup = await buildBackup(appVersion: packageInfo.version);
    final uri = await FilePicker.saveFile(
      dialogTitle: 'Simpan backup',
      fileName: backup.fileName,
      bytes: backup.bytes,
      mimeType: 'application/zip',
    );
    return uri != null;
  }

  Future<BackupArchive> buildBackup({
    required String appVersion,
    DateTime? createdAt,
    Directory? temporaryDirectory,
  }) async {
    final timestamp = createdAt ?? DateTime.now();
    final tempRoot = temporaryDirectory ?? await getTemporaryDirectory();
    final workingDirectory = await tempRoot.createTemp('finote_backup_');

    try {
      final databaseFile = File(
        '${workingDirectory.path}${Platform.pathSeparator}database.sqlite',
      );
      await _database.customStatement('VACUUM INTO ?', [databaseFile.path]);
      await _validateSnapshot(databaseFile);

      final manifest = BackupManifest.create(
        databaseVersion: _database.schemaVersion,
        createdAt: timestamp,
        appVersion: appVersion,
      );
      final archive = Archive()
        ..addFile(
          ArchiveFile.bytes(
            'database.sqlite',
            await databaseFile.readAsBytes(),
          ),
        )
        ..addFile(
          ArchiveFile.string(
            'manifest.json',
            const JsonEncoder.withIndent('  ').convert(manifest.toJson()),
          ),
        );

      return BackupArchive(
        fileName:
            'finance_backup_${DateFormat('yyyy-MM-dd_HH-mm').format(timestamp.toLocal())}.zip',
        bytes: ZipEncoder().encodeBytes(archive),
        manifest: manifest,
      );
    } finally {
      if (await workingDirectory.exists()) {
        await workingDirectory.delete(recursive: true);
      }
    }
  }

  Future<void> _validateSnapshot(File file) async {
    final snapshot = sqlite3.open(file.path, mode: OpenMode.readOnly);
    try {
      final integrity = snapshot.select('PRAGMA integrity_check').single;
      if (integrity['integrity_check'] != 'ok' ||
          snapshot.userVersion != _database.schemaVersion) {
        throw StateError('Database snapshot validation failed');
      }
    } finally {
      snapshot.close();
    }
  }
}

class BackupArchive {
  const BackupArchive({
    required this.fileName,
    required this.bytes,
    required this.manifest,
  });

  final String fileName;
  final Uint8List bytes;
  final BackupManifest manifest;
}

final backupServiceProvider = Provider<BackupService>(
  (ref) => BackupService(ref.watch(databaseProvider)),
);
