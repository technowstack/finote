import 'package:drift/native.dart';
import 'package:finote/core/database/app_database.dart';
import 'package:finote/features/categories/data/category_repository.dart';
import 'package:finote/features/transactions/data/transaction_repository.dart';
import 'package:finote/features/transactions/domain/transaction_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late CategoryRepository categories;
  late TransactionRepository transactions;
  late TransactionRecord lunch;
  late TransactionRecord fuel;
  late TransactionRecord salary;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    categories = CategoryRepository(database);
    transactions = TransactionRepository(database);

    final food = await categories.create(
      name: 'Makanan',
      type: TransactionType.expense,
    );
    final transport = await categories.create(
      name: 'Transportasi',
      type: TransactionType.expense,
    );
    final income = await categories.create(
      name: 'Gaji',
      type: TransactionType.income,
    );
    lunch = await transactions.create(
      type: TransactionType.expense,
      categoryId: food.id,
      amount: 25000,
      title: 'Makan siang',
      note: 'Bersama tim kantor',
      transactionDate: DateTime(2026, 8, 29),
    );
    fuel = await transactions.create(
      type: TransactionType.expense,
      categoryId: transport.id,
      amount: 50000,
      title: 'Bensin',
      transactionDate: DateTime(2026, 8, 22),
    );
    salary = await transactions.create(
      type: TransactionType.income,
      categoryId: income.id,
      amount: 8500000,
      note: 'Pendapatan bulanan',
      transactionDate: DateTime(2026, 8, 29),
    );
  });

  tearDown(() => database.close());

  test('history filters type and inclusive date range in SQLite', () async {
    final income = await transactions
        .watchHistory(
          TransactionHistoryQuery(
            type: TransactionType.income,
            startDate: DateTime(2026, 8, 29),
            endDate: DateTime(2026, 8, 29),
          ),
        )
        .first;
    final recent = await transactions
        .watchHistory(
          TransactionHistoryQuery(
            startDate: DateTime(2026, 8, 23),
            endDate: DateTime(2026, 8, 29),
          ),
        )
        .first;

    expect(income.map((item) => item.transaction.id), [salary.id]);
    expect(
      recent.map((item) => item.transaction.id),
      containsAll([lunch.id, salary.id]),
    );
    expect(recent.map((item) => item.transaction.id), isNot(contains(fuel.id)));
  });

  test('history searches title, note, and category', () async {
    Future<List<int>> search(String value) async {
      final result = await transactions
          .watchHistory(TransactionHistoryQuery(search: value))
          .first;
      return result.map((item) => item.transaction.id).toList();
    }

    expect(await search('makan'), [lunch.id]);
    expect(await search('KANTOR'), [lunch.id]);
    expect(await search('Transportasi'), [fuel.id]);
    expect(await search('bulanan'), [salary.id]);
    expect(await search('%'), isEmpty);
  });

  test(
    'history orders newest first and excludes soft-deleted records',
    () async {
      await transactions.softDelete(salary.id);
      final result = await transactions.watchAll().first;

      expect(result.first.transaction.transactionDate, DateTime(2026, 8, 29));
      expect(result.map((item) => item.transaction.id), contains(lunch.id));
      expect(
        result.map((item) => item.transaction.id),
        isNot(contains(salary.id)),
      );
    },
  );
}
