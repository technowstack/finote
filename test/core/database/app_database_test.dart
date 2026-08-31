import 'dart:io';

import 'package:drift/drift.dart' show Value, Variable;
import 'package:drift/native.dart';
import 'package:finote/core/database/app_database.dart';
import 'package:finote/features/accounts/data/account_repository.dart';
import 'package:finote/features/accounts/domain/account_type.dart';
import 'package:finote/features/categories/data/category_repository.dart';
import 'package:finote/features/transactions/data/transaction_repository.dart';
import 'package:finote/features/transactions/domain/transaction_source.dart';
import 'package:finote/features/transactions/domain/transaction_type.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late AppDatabase database;
  late CategoryRepository categories;
  late TransactionRepository transactions;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    categories = CategoryRepository(database);
    transactions = TransactionRepository(database);
  });

  tearDown(() => database.close());

  test('fresh database creates version 8 tables and indexes', () async {
    final schema = await database
        .customSelect(
          "SELECT type, name FROM sqlite_master WHERE type IN ('table', 'index')",
        )
        .get();
    final names = schema.map((row) => row.read<String>('name')).toSet();

    expect(database.schemaVersion, 8);
    final foreignKeys = await database
        .customSelect('PRAGMA foreign_keys')
        .getSingle();
    expect(foreignKeys.read<int>('foreign_keys'), 1);
    expect(
      names,
      containsAll(['accounts', 'categories', 'transactions', 'settings']),
    );
    expect(
      names,
      containsAll([
        'transactions_date',
        'transactions_category_id',
        'transactions_type',
        'transactions_deleted_at',
        'transactions_account_id',
        'transfers_from_account_id',
        'transfers_to_account_id',
        'transfers_date',
        'transfers_deleted_at',
        'transactions_receipt_fingerprint',
        'transactions_legacy_source_id',
        'accounts_active',
      ]),
    );
    final defaultAccount = await database.select(database.accounts).getSingle();
    expect(defaultAccount.name, 'Tunai');
    expect(defaultAccount.type.name, 'cash');
    expect(defaultAccount.isDefault, isTrue);
    final transactionColumns = await database
        .customSelect('PRAGMA table_info(transactions)')
        .get();
    expect(
      transactionColumns.map((row) => row.read<String>('name')),
      contains('account_id'),
    );
  });

  test('category insert generates UUID and stores domain type', () async {
    final category = await categories.create(
      name: 'Transportasi',
      type: TransactionType.expense,
      icon: 'directions_car',
    );

    expect(category.id, isPositive);
    expect(category.uuid, matches(_uuidPattern));
    expect(category.type, TransactionType.expense);
    expect(category.deletedAt, isNull);
  });

  test(
    'transaction insert stores integer amount and supported source',
    () async {
      final category = await categories.create(
        name: 'Gaji',
        type: TransactionType.income,
      );
      final transaction = await transactions.create(
        type: TransactionType.income,
        categoryId: category.id,
        amount: 8500000,
        transactionDate: DateTime(2026, 8, 29),
        source: TransactionSource.manual,
      );

      final raw = await database
          .customSelect(
            'SELECT typeof(amount) AS amount_type, type, source, transaction_date '
            'FROM transactions WHERE id = ?',
            variables: [Variable.withInt(transaction.id)],
          )
          .getSingle();

      expect(transaction.uuid, matches(_uuidPattern));
      expect(transaction.amount, 8500000);
      expect(raw.read<String>('amount_type'), 'integer');
      expect(raw.read<String>('type'), 'income');
      expect(raw.read<String>('source'), 'manual');
      expect(raw.read<String>('transaction_date'), '2026-08-29');
    },
  );

  test('all declared transaction sources round-trip through SQLite', () async {
    final category = await categories.create(
      name: 'Lainnya',
      type: TransactionType.expense,
    );

    for (final source in TransactionSource.values) {
      final isLegacy = source == TransactionSource.legacyImport;
      final transaction = await transactions.create(
        type: TransactionType.expense,
        categoryId: category.id,
        amount: 1,
        transactionDate: DateTime(2026, 8, 29),
        source: source,
        legacySource: isLegacy ? 'test' : null,
        legacyId: isLegacy ? source.index : null,
      );
      expect(transaction.source, source);
    }
  });

  test('transaction can be updated without changing identity', () async {
    final category = await categories.create(
      name: 'Belanja',
      type: TransactionType.expense,
    );
    final original = await transactions.create(
      type: TransactionType.expense,
      categoryId: category.id,
      amount: 25000,
      transactionDate: DateTime(2026, 8, 29),
    );

    expect(
      await transactions.update(original.copyWith(title: 'Belanja mingguan')),
      isTrue,
    );
    final updated = await transactions.findActiveById(original.id);

    expect(updated?.title, 'Belanja mingguan');
    expect(updated?.uuid, original.uuid);
  });

  test('soft delete hides records without removing them', () async {
    final category = await categories.create(
      name: 'Makanan',
      type: TransactionType.expense,
    );
    final transaction = await transactions.create(
      type: TransactionType.expense,
      categoryId: category.id,
      amount: 15000,
      transactionDate: DateTime(2026, 8, 29),
    );

    expect(await transactions.softDelete(transaction.id), isTrue);
    expect(await transactions.findActiveById(transaction.id), isNull);
    final stored = await (database.select(
      database.transactions,
    )..where((row) => row.id.equals(transaction.id))).getSingle();
    expect(stored.deletedAt, isNotNull);

    expect(await categories.softDelete(category.id), isTrue);
    expect(await categories.findActiveById(category.id), isNull);
  });

  test('legacy source and id prevent duplicate imports', () async {
    final category = await categories.create(
      name: 'Bonus',
      type: TransactionType.income,
    );
    Future<void> insert() => transactions.create(
      type: TransactionType.income,
      categoryId: category.id,
      amount: 100000,
      transactionDate: DateTime(2026, 8, 29),
      source: TransactionSource.legacyImport,
      legacySource: 'catatan_keuangan_old',
      legacyId: 123,
    );

    await insert();
    await expectLater(insert(), throwsA(isA<Exception>()));
  });

  test('version 1 database migrates to version 8 without recreation', () async {
    await database.close();
    database = AppDatabase(
      NativeDatabase.memory(
        setup: (sqlite) {
          sqlite.execute(
            'CREATE TABLE phase_zero_marker (value TEXT NOT NULL)',
          );
          sqlite.execute("INSERT INTO phase_zero_marker VALUES ('preserved')");
          sqlite.userVersion = 1;
        },
      ),
    );

    final tables = await database
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
        .get();
    final version = await database
        .customSelect('PRAGMA user_version')
        .getSingle();
    final marker = await database
        .customSelect('SELECT value FROM phase_zero_marker')
        .getSingle();

    expect(version.read<int>('user_version'), 8);
    expect(marker.read<String>('value'), 'preserved');
    expect(
      tables.map((row) => row.read<String>('name')),
      containsAll(['accounts', 'categories', 'transactions', 'settings']),
    );
  });

  test('populated version 2 database preserves financial rows', () async {
    await database.close();
    database = AppDatabase(
      NativeDatabase.memory(
        setup: (sqlite) {
          sqlite.execute('''
            CREATE TABLE categories (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              uuid TEXT NOT NULL UNIQUE,
              name TEXT NOT NULL,
              type TEXT NOT NULL,
              icon TEXT,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL,
              deleted_at INTEGER
            )
          ''');
          sqlite.execute('''
            CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)
          ''');
          sqlite.execute('''
            CREATE TABLE transactions (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              uuid TEXT NOT NULL UNIQUE,
              type TEXT NOT NULL,
              category_id INTEGER NOT NULL,
              amount INTEGER NOT NULL,
              title TEXT NOT NULL,
              note TEXT,
              transaction_date TEXT NOT NULL,
              source TEXT NOT NULL,
              legacy_source TEXT,
              legacy_id INTEGER,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL,
              deleted_at INTEGER
            )
          ''');
          sqlite.execute(
            "INSERT INTO categories VALUES "
            "(1, 'category-v2', 'Makan', 'expense', NULL, 1, 1, NULL)",
          );
          sqlite.execute(
            "INSERT INTO transactions VALUES "
            "(1, 'transaction-v2', 'expense', 1, 25000, 'Sarapan', NULL, "
            "'2026-08-29', 'manual', NULL, NULL, 1, 1, NULL)",
          );
          sqlite.userVersion = 2;
        },
      ),
    );

    final transaction = await database
        .select(database.transactions)
        .getSingle();
    final category = await database.select(database.categories).getSingle();
    final columns = await database
        .customSelect('PRAGMA table_info(transactions)')
        .get();

    expect(database.schemaVersion, 8);
    expect(transaction.uuid, 'transaction-v2');
    expect(transaction.amount, 25000);
    expect(transaction.transactionDate, DateTime(2026, 8, 29));
    expect(transaction.accountId, isNotNull);
    expect(transaction.deletedAt, isNull);
    expect(category.uuid, 'category-v2');
    expect(
      columns.map((row) => row.read<String>('name')),
      contains('receipt_fingerprint'),
    );
    expect(await database.select(database.accounts).getSingle(), isNotNull);
    expect(transaction.accountId, isNotNull);
  });

  test('version 7 migration repairs account and transfer indexes', () async {
    await database.close();
    final directory = await Directory.systemTemp.createTemp(
      'finote_schema_7_repair_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/finote.sqlite');
    database = AppDatabase(NativeDatabase(file));
    await database.customSelect('SELECT 1').getSingle();
    await database.close();

    final native = sqlite3.open(file.path);
    for (final index in [
      'accounts_active',
      'transfers_from_account_id',
      'transfers_to_account_id',
      'transfers_date',
      'transfers_deleted_at',
    ]) {
      native.execute('DROP INDEX IF EXISTS $index');
    }
    native.userVersion = 7;
    native.close();

    database = AppDatabase(NativeDatabase(file));
    final indexes = await database
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'index'")
        .get();
    expect(
      indexes.map((row) => row.read<String>('name')),
      containsAll([
        'accounts_active',
        'transfers_from_account_id',
        'transfers_to_account_id',
        'transfers_date',
        'transfers_deleted_at',
      ]),
    );
  });

  test(
    'transactions persist and can change account without duplication',
    () async {
      final defaultAccount = await database
          .select(database.accounts)
          .getSingle();
      final otherAccount = await database
          .into(database.accounts)
          .insertReturning(
            AccountsCompanion.insert(name: 'BCA Utama', type: AccountType.bank),
          );
      final category = await categories.create(
        name: 'Makan',
        type: TransactionType.expense,
      );
      final transaction = await transactions.create(
        type: TransactionType.expense,
        categoryId: category.id,
        amount: 50000,
        accountId: otherAccount.id,
        transactionDate: DateTime(2026, 8, 31),
      );

      expect(transaction.accountId, otherAccount.id);
      expect(
        await transactions.update(
          transaction.copyWith(accountId: Value(defaultAccount.id)),
        ),
        isTrue,
      );
      expect(
        (await transactions.findActiveById(transaction.id))?.accountId,
        defaultAccount.id,
      );
      expect(await database.select(database.transactions).get(), hasLength(1));
    },
  );

  test(
    'archived account remains readable through historical transaction',
    () async {
      final defaultAccount = await database
          .select(database.accounts)
          .getSingle();
      final otherAccount = await database
          .into(database.accounts)
          .insertReturning(
            AccountsCompanion.insert(name: 'GoPay', type: AccountType.eWallet),
          );
      final category = await categories.create(
        name: 'Transportasi',
        type: TransactionType.expense,
      );
      await transactions.create(
        type: TransactionType.expense,
        categoryId: category.id,
        amount: 10000,
        accountId: otherAccount.id,
        transactionDate: DateTime(2026, 8, 31),
      );
      await AccountRepository(database).archive(otherAccount.id);

      final row = await transactions.watchAll().first;
      expect(row.single.account.id, otherAccount.id);
      expect(row.single.account.isActive, isFalse);
      expect(defaultAccount.isActive, isTrue);
    },
  );
}

final _uuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);
