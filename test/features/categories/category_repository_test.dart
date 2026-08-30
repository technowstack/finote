import 'package:drift/native.dart';
import 'package:finote/core/database/app_database.dart';
import 'package:finote/features/categories/data/category_repository.dart';
import 'package:finote/features/transactions/data/transaction_repository.dart';
import 'package:finote/features/transactions/domain/transaction_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late CategoryRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = CategoryRepository(database);
  });

  tearDown(() => database.close());

  test('default initialization is complete and repeat-safe', () async {
    await repository.initializeDefaults();
    await repository.initializeDefaults();

    final all = await repository.watchAll().first;
    final expenses = await repository
        .watchByType(TransactionType.expense)
        .first;
    final incomes = await repository.watchByType(TransactionType.income).first;

    expect(all, hasLength(16));
    expect(
      expenses.map((category) => category.name),
      containsAll([
        'Makanan & Minuman',
        'Transportasi',
        'Belanja',
        'Tagihan',
        'Hiburan',
        'Kesehatan',
        'Pendidikan',
        'Rumah',
        'Keluarga',
        'Lainnya',
      ]),
    );
    expect(
      incomes.map((category) => category.name),
      containsAll([
        'Gaji',
        'Bonus',
        'Bisnis',
        'Hadiah',
        'Investasi',
        'Lainnya',
      ]),
    );
  });

  test('create, rename, and soft delete update reactive lists', () async {
    final category = await repository.create(
      name: '  Olahraga  ',
      type: TransactionType.expense,
    );
    expect(category.name, 'Olahraga');
    expect(
      (await repository.watchByType(TransactionType.expense).first).map(
        (item) => item.name,
      ),
      contains('Olahraga'),
    );

    expect(await repository.rename(category.id, 'Kebugaran'), isTrue);
    expect((await repository.findActiveById(category.id))?.name, 'Kebugaran');

    expect(await repository.softDelete(category.id), isTrue);
    expect(await repository.findActiveById(category.id), isNull);
    expect(
      (await repository.watchAll().first).map((item) => item.name),
      isNot(contains('Kebugaran')),
    );
  });

  test('rejects case-insensitive duplicate names for the same type', () async {
    await repository.create(
      name: 'Transportasi',
      type: TransactionType.expense,
    );

    await expectLater(
      repository.create(name: 'transportasi', type: TransactionType.expense),
      throwsStateError,
    );
    await expectLater(
      repository.create(name: 'Transportasi', type: TransactionType.income),
      completes,
    );
  });

  test('does not delete a category used by an active transaction', () async {
    final category = await repository.create(
      name: 'Makanan',
      type: TransactionType.expense,
    );
    await TransactionRepository(database).create(
      type: TransactionType.expense,
      categoryId: category.id,
      amount: 1000,
      transactionDate: DateTime(2026, 8, 30),
    );

    await expectLater(repository.softDelete(category.id), throwsStateError);
    expect((await repository.findActiveById(category.id))?.name, 'Makanan');
  });
}
