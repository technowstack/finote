import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:finote/core/database/app_database.dart';
import 'package:finote/features/accounts/data/account_repository.dart';
import 'package:finote/features/accounts/domain/account_type.dart';
import 'package:finote/features/categories/data/category_repository.dart';
import 'package:finote/features/transactions/data/financial_activity_repository.dart';
import 'package:finote/features/transactions/data/transaction_repository.dart';
import 'package:finote/features/transactions/domain/financial_activity.dart';
import 'package:finote/features/transactions/domain/transaction_source.dart';
import 'package:finote/features/transactions/domain/transaction_type.dart';
import 'package:finote/features/transfers/data/transfer_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late FinancialActivityRepository activities;
  late TransactionRepository transactions;
  late TransferRepository transfers;
  late AccountRecord source;
  late AccountRecord destination;
  late TransactionRecord income;
  late TransactionRecord expense;
  late TransferRecord transfer;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    activities = FinancialActivityRepository(database);
    transactions = TransactionRepository(database);
    transfers = TransferRepository(database);
    final accounts = AccountRepository(database);
    source = await accounts.create(name: 'BCA Utama', type: AccountType.bank);
    destination = await accounts.create(
      name: 'BCA Tabungan',
      type: AccountType.savings,
    );
    final categories = CategoryRepository(database);
    final salary = await categories.create(
      name: 'Gaji',
      type: TransactionType.income,
    );
    final food = await categories.create(
      name: 'Makanan',
      type: TransactionType.expense,
    );
    income = await transactions.create(
      type: TransactionType.income,
      categoryId: salary.id,
      accountId: source.id,
      amount: 10000000,
      title: 'Gaji',
      transactionDate: DateTime(2026, 8, 31),
    );
    expense = await transactions.create(
      type: TransactionType.expense,
      categoryId: food.id,
      accountId: source.id,
      amount: 75000,
      title: 'Makan',
      transactionDate: DateTime(2026, 8, 31),
    );
    transfer = await transfers.create(
      fromAccountId: source.id,
      toAccountId: destination.id,
      amount: 2000000,
      transferDate: DateTime(2026, 8, 31),
      note: 'Tabungan bulanan',
    );
  });

  tearDown(() => database.close());

  test(
    'unifies each activity once with stable deterministic ordering',
    () async {
      final result = await activities
          .watch(const FinancialActivityQuery())
          .first;

      expect(result, hasLength(3));
      expect(result.map((item) => item.type), [
        FinancialActivityType.transfer,
        FinancialActivityType.expense,
        FinancialActivityType.income,
      ]);
      expect(
        result.map((item) => item.identity).toSet(),
        hasLength(result.length),
      );
      final transferActivity = result.first;
      expect(transferActivity.title, 'Transfer ke BCA Tabungan');
      expect(transferActivity.subtitle, 'BCA Utama → BCA Tabungan');
      expect(transferActivity.amount, 2000000);
      expect(transferActivity.date, DateTime(2026, 8, 31));
    },
  );

  test(
    'filters income, expense, transfer, and inclusive date ranges',
    () async {
      Future<List<FinancialActivity>> type(FinancialActivityType value) =>
          activities.watch(FinancialActivityQuery(type: value)).first;

      expect(
        (await type(FinancialActivityType.income)).single.entityId,
        income.id,
      );
      expect(
        (await type(FinancialActivityType.expense)).single.entityId,
        expense.id,
      );
      expect(
        (await type(FinancialActivityType.transfer)).single.entityId,
        transfer.id,
      );
      expect(
        await activities
            .watch(
              FinancialActivityQuery(
                startDate: DateTime(2026, 9, 1),
                endDate: DateTime(2026, 9, 30),
              ),
            )
            .first,
        isEmpty,
      );
    },
  );

  test(
    'all-time history exposes older transactions and same-date rows',
    () async {
      final categories = CategoryRepository(database);
      final oldCategory = await categories.create(
        name: 'Lama',
        type: TransactionType.expense,
      );
      await transactions.create(
        type: TransactionType.expense,
        categoryId: oldCategory.id,
        accountId: source.id,
        amount: 50000,
        title: 'Legacy A',
        transactionDate: DateTime(2020, 9, 10),
        source: TransactionSource.legacyImport,
        legacySource: 'fixture',
        legacyId: 1,
      );
      await transactions.create(
        type: TransactionType.expense,
        categoryId: oldCategory.id,
        accountId: source.id,
        amount: 50000,
        title: 'Legacy B',
        transactionDate: DateTime(2020, 9, 10),
        source: TransactionSource.legacyImport,
        legacySource: 'fixture',
        legacyId: 2,
      );

      final result = await activities
          .watch(const FinancialActivityQuery())
          .first;
      expect(result, hasLength(5));
      expect(
        result.where((item) => item.date == DateTime(2020, 9, 10)),
        hasLength(2),
      );
      expect(
        result.map((item) => item.title),
        containsAll(['Legacy A', 'Legacy B']),
      );
    },
  );

  test('searches transfer note and both account names', () async {
    Future<List<FinancialActivity>> search(String value) =>
        activities.watch(FinancialActivityQuery(search: value)).first;

    expect(
      (await search('bulanan')).single.type,
      FinancialActivityType.transfer,
    );
    expect(
      (await search('BCA Tabungan')).map((item) => item.type),
      contains(FinancialActivityType.transfer),
    );
    expect((await search('%')), isEmpty);
  });

  test(
    'account and category filters preserve matching transaction rows',
    () async {
      expect(
        (await activities
                .watch(FinancialActivityQuery(accountId: source.id))
                .first)
            .map((item) => item.entityId),
        containsAll([income.id, expense.id, transfer.id]),
      );
      expect(
        (await activities
                .watch(FinancialActivityQuery(categoryId: expense.categoryId))
                .first)
            .map((item) => item.entityId),
        [expense.id],
      );
    },
  );

  test('reacts to edits, soft deletes, and archived accounts', () async {
    await AccountRepository(database).archive(destination.id);
    await transfers.update(
      transfer.copyWith(
        note: const Value('Dana darurat'),
        transferDate: DateTime(2026, 9, 1),
      ),
    );
    final edited = await activities
        .watch(const FinancialActivityQuery(search: 'darurat'))
        .first;
    expect(edited.single.subtitle, 'BCA Utama → BCA Tabungan');
    expect(edited.single.date, DateTime(2026, 9, 1));

    await transfers.softDelete(transfer.id);
    await transactions.softDelete(expense.id);
    final remaining = await activities
        .watch(const FinancialActivityQuery())
        .first;
    expect(remaining.map((item) => item.entityId), [income.id]);
  });
}
