import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../features/transactions/domain/transaction_source.dart';
import '../../features/transactions/domain/transaction_type.dart';
import '../utils/uuid_generator.dart';
import 'converters.dart';
import 'tables/categories.dart';
import 'tables/settings.dart';
import 'tables/transactions.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Categories, Transactions, Settings])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'finote'));

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    onUpgrade: (migrator, from, to) async {
      if (from < 2) await migrator.createAll();
      if (from < 3) {
        final columns = await customSelect('PRAGMA table_info(transactions)')
            .get();
        if (!columns.any(
          (row) => row.read<String>('name') == 'receipt_fingerprint',
        )) {
          await migrator.addColumn(
            transactions,
            transactions.receiptFingerprint,
          );
        }
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// Mengembalikan path absolut file SQLite yang digunakan oleh database ini.
  ///
  /// Digunakan oleh [BackupService] untuk mengetahui lokasi file yang akan
  /// di-overwrite saat proses restore.
  static Future<String> resolveDatabasePath() async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, 'finote.sqlite');
  }
}

final databaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});
