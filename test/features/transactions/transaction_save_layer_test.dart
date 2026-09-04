import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:finote/core/database/app_database.dart';
import 'package:finote/features/accounts/data/account_repository.dart';
import 'package:finote/features/accounts/domain/account_type.dart';
import 'package:finote/features/categories/data/category_repository.dart';
import 'package:finote/features/transactions/data/transaction_repository.dart';
import 'package:finote/features/transactions/domain/transaction_source.dart';
import 'package:finote/features/transactions/domain/transaction_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    await database.ensureDefaultAccount();
    await CategoryRepository(database).initializeDefaults();
  });

  tearDown(() => database.close());

  test(
    'direct Drift transaction insert completes with required defaults',
    () async {
      final category = (await CategoryRepository(
        database,
      ).watchByType(TransactionType.expense).first).first;
      final account = (await AccountRepository(
        database,
      ).watchActive().first).first;

      final saved = await database
          .into(database.transactions)
          .insertReturning(
            TransactionsCompanion.insert(
              type: TransactionType.expense,
              accountId: Value(account.id),
              categoryId: category.id,
              amount: 10000,
              title: const Value('Test'),
              transactionDate: DateTime(2026, 9, 4),
              source: TransactionSource.manual,
            ),
          )
          .timeout(const Duration(seconds: 5));

      expect(saved.amount, 10000);
      expect(saved.accountId, account.id);
      expect(await database.select(database.assetTransactions).get(), isEmpty);
    },
  );

  test(
    'repository creates and edits normal Expense and Income independently',
    () async {
      final categories = CategoryRepository(database);
      final accounts = AccountRepository(database);
      final repository = TransactionRepository(database);
      final expenseCategory =
          (await categories.watchByType(TransactionType.expense).first).first;
      final incomeCategory =
          (await categories.watchByType(TransactionType.income).first).first;
      final defaultAccount = (await accounts.watchActive().first).first;
      final secondAccount = await accounts.create(
        name: 'Bank',
        type: AccountType.bank,
      );

      final expense = await repository.create(
        type: TransactionType.expense,
        categoryId: expenseCategory.id,
        amount: 10000,
        accountId: defaultAccount.id,
        title: 'Test expense',
        note: 'Before',
        transactionDate: DateTime(2026, 9, 4),
      );
      final income = await repository.create(
        type: TransactionType.income,
        categoryId: incomeCategory.id,
        amount: 20000,
        accountId: defaultAccount.id,
        title: 'Test income',
        transactionDate: DateTime(2026, 9, 4),
      );

      expect(
        await repository.update(
          expense.copyWith(
            amount: 12000,
            accountId: Value(secondAccount.id),
            title: 'Edited expense',
            note: const Value('After'),
            transactionDate: DateTime(2026, 9, 3),
          ),
        ),
        isTrue,
      );
      expect(
        await repository.update(
          income.copyWith(
            amount: 22000,
            title: 'Edited income',
            note: const Value('Income note'),
          ),
        ),
        isTrue,
      );

      final rows = await database.select(database.transactions).get();
      expect(rows, hasLength(2));
      expect(rows.map((row) => row.amount), containsAll([12000, 22000]));
      expect(await database.select(database.assetTransactions).get(), isEmpty);
    },
  );

  test('repository recovers after a failed insert', () async {
    final repository = TransactionRepository(database);

    await expectLater(
      repository.create(
        type: TransactionType.expense,
        categoryId: 999999,
        amount: 10000,
        transactionDate: DateTime(2026, 9, 4),
      ),
      throwsA(isA<StateError>()),
    );

    final category = (await CategoryRepository(
      database,
    ).watchByType(TransactionType.expense).first).first;
    final saved = await repository.create(
      type: TransactionType.expense,
      categoryId: category.id,
      amount: 10000,
      transactionDate: DateTime(2026, 9, 4),
    );
    expect(saved.amount, 10000);
    expect(await database.select(database.transactions).get(), hasLength(1));
  });
}
