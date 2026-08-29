import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:finote/core/database/app_database.dart';
import 'package:finote/features/categories/data/category_repository.dart';
import 'package:finote/features/transactions/data/transaction_repository.dart';
import 'package:finote/features/transactions/domain/transaction_source.dart';
import 'package:finote/features/transactions/domain/transaction_type.dart';
import 'package:flutter_test/flutter_test.dart';

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

  test('fresh database creates version 2 tables and indexes', () async {
    final schema = await database
        .customSelect(
          "SELECT type, name FROM sqlite_master WHERE type IN ('table', 'index')",
        )
        .get();
    final names = schema.map((row) => row.read<String>('name')).toSet();

    expect(database.schemaVersion, 2);
    final foreignKeys = await database
        .customSelect('PRAGMA foreign_keys')
        .getSingle();
    expect(foreignKeys.read<int>('foreign_keys'), 1);
    expect(names, containsAll(['categories', 'transactions', 'settings']));
    expect(
      names,
      containsAll([
        'transactions_date',
        'transactions_category_id',
        'transactions_type',
        'transactions_deleted_at',
        'transactions_legacy_source_id',
      ]),
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

  test('version 1 database migrates to version 2 without recreation', () async {
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

    expect(version.read<int>('user_version'), 2);
    expect(marker.read<String>('value'), 'preserved');
    expect(
      tables.map((row) => row.read<String>('name')),
      containsAll(['categories', 'transactions', 'settings']),
    );
  });
}

final _uuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);
