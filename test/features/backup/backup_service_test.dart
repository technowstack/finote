import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:finote/core/database/app_database.dart';
import 'package:finote/features/backup/data/backup_service.dart';
import 'package:finote/features/backup/domain/backup_manifest.dart';
import 'package:finote/features/categories/data/category_repository.dart';
import 'package:finote/features/transactions/data/transaction_repository.dart';
import 'package:finote/features/transactions/domain/transaction_type.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test(
    'backup contains a valid manifest and consistent SQLite snapshot',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      final tempDirectory = await Directory.systemTemp.createTemp(
        'finote_backup_test_',
      );
      addTearDown(database.close);
      addTearDown(() => tempDirectory.delete(recursive: true));

      final category = await CategoryRepository(database)
          .create(name: 'Makanan', type: TransactionType.expense);
      await TransactionRepository(database).create(
        type: TransactionType.expense,
        categoryId: category.id,
        amount: 25000,
        transactionDate: DateTime(2026, 8, 29),
      );

      final backup = await BackupService(database).buildBackup(
        appVersion: '1.0.0',
        createdAt: DateTime(2026, 8, 29, 14, 5),
        temporaryDirectory: tempDirectory,
      );
      final archive = ZipDecoder().decodeBytes(backup.bytes);

      expect(backup.fileName, 'finance_backup_2026-08-29_14-05.zip');
      expect(archive.files.map((file) => file.name).toSet(), {
        'database.sqlite',
        'manifest.json',
      });

      final manifestFile = archive.findFile('manifest.json')!;
      final manifest = BackupManifest.fromJson(
        jsonDecode(utf8.decode(manifestFile.content)) as Map<String, dynamic>,
      );
      expect(manifest.databaseVersion, database.schemaVersion);
      expect(manifest.appVersion, '1.0.0');

      final snapshotFile = File(
        '${tempDirectory.path}${Platform.pathSeparator}snapshot.sqlite',
      );
      await snapshotFile.writeAsBytes(
        archive.findFile('database.sqlite')!.content,
        flush: true,
      );
      final snapshot = sqlite3.open(snapshotFile.path, mode: OpenMode.readOnly);
      try {
        expect(
          snapshot.select('PRAGMA integrity_check').single['integrity_check'],
          'ok',
        );
        expect(
          snapshot
              .select('SELECT COUNT(*) AS count FROM transactions')
              .single['count'],
          1,
        );
      } finally {
        snapshot.close();
      }
    },
  );
}
