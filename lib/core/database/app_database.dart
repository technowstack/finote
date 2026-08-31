import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../features/accounts/domain/account_type.dart';
import '../../features/transactions/domain/transaction_source.dart';
import '../../features/transactions/domain/transaction_type.dart';
import '../utils/uuid_generator.dart';
import 'converters.dart';
import 'tables/categories.dart';
import 'tables/accounts.dart';
import 'tables/settings.dart';
import 'tables/transactions.dart';
import 'tables/transfers.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [Accounts, Categories, Transactions, Transfers, Settings],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'finote'));

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
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
      if (from < 4) {
        if (from >= 2) await migrator.createTable(accounts);
        await ensureDefaultAccount();
      }
      if (from < 5) {
        if (from >= 2) {
          await migrator.addColumn(transactions, transactions.accountId);
        }
        await ensureDefaultAccount();
        await _backfillTransactionAccounts();
      }
      if (from < 6) {
        await customStatement(
          'CREATE INDEX IF NOT EXISTS transactions_account_id '
          'ON transactions (account_id)',
        );
      }
      if (from < 7) {
        await migrator.createTable(transfers);
      }
    },
    onCreate: (migrator) async {
      await migrator.createAll();
      await ensureDefaultAccount();
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<void> ensureDefaultAccount() async {
    final existing = await (select(
      accounts,
    )..where((account) => account.isDefault.equals(true))).getSingleOrNull();
    if (existing != null) return;
    await into(accounts).insert(
      AccountsCompanion.insert(
        name: 'Tunai',
        type: AccountType.cash,
        isDefault: const Value(true),
      ),
    );
  }

  Future<void> _backfillTransactionAccounts() async {
    final defaultAccount = await (select(
      accounts,
    )..where((account) => account.isDefault.equals(true))).getSingleOrNull();
    if (defaultAccount == null) {
      throw StateError('Default account is missing');
    }
    await customStatement(
      'UPDATE transactions SET account_id = ? WHERE account_id IS NULL',
      [defaultAccount.id],
    );
    final unassigned = await customSelect(
      'SELECT COUNT(*) AS count FROM transactions WHERE account_id IS NULL',
    ).getSingle();
    if (unassigned.read<int>('count') != 0) {
      throw StateError('Some transactions have no account');
    }
  }

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
