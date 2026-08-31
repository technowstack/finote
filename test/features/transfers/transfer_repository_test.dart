import 'package:drift/native.dart';
import 'package:finote/core/database/app_database.dart';
import 'package:finote/features/accounts/data/account_repository.dart';
import 'package:finote/features/accounts/domain/account_summary.dart';
import 'package:finote/features/accounts/domain/account_type.dart';
import 'package:finote/features/reports/data/report_repository.dart';
import 'package:finote/features/transactions/data/transaction_repository.dart';
import 'package:finote/features/transactions/domain/transaction_type.dart';
import 'package:finote/features/transfers/data/transfer_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late AccountRepository accounts;
  late TransferRepository transfers;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    accounts = AccountRepository(database);
    transfers = TransferRepository(database);
  });

  tearDown(() => database.close());

  test('transfers move balance without changing report totals', () async {
    final source = await accounts.create(
      name: 'BCA Utama',
      type: AccountType.bank,
    );
    final destination = await accounts.create(
      name: 'BCA Tabungan',
      type: AccountType.savings,
    );
    final income = await _category(database, 'Gaji', TransactionType.income);
    final expense = await _category(
      database,
      'Belanja',
      TransactionType.expense,
    );
    final transactions = TransactionRepository(database);
    await transactions.create(
      type: TransactionType.income,
      categoryId: income.id,
      accountId: source.id,
      amount: 10000000,
      transactionDate: DateTime(2026, 8, 31),
    );
    await transactions.create(
      type: TransactionType.expense,
      categoryId: expense.id,
      accountId: source.id,
      amount: 1000000,
      transactionDate: DateTime(2026, 8, 31),
    );

    final transfer = await transfers.create(
      fromAccountId: source.id,
      toAccountId: destination.id,
      amount: 2000000,
      transferDate: DateTime(2026, 8, 31),
      note: 'Tabungan bulanan',
    );
    expect(transfer.uuid, isNotEmpty);

    expect((await _summary(accounts, source.id)).balance, 7000000);
    expect((await _summary(accounts, destination.id)).balance, 2000000);

    final report = await ReportRepository(database)
        .watchReport(
          ReportRange(start: DateTime(2026, 8, 1), end: DateTime(2026, 8, 31)),
        )
        .first;
    expect(report.totalIncome, 10000000);
    expect(report.totalExpense, 1000000);
    expect(report.balance, 9000000);
    expect(await database.select(database.transactions).get(), hasLength(2));
    expect(await transfers.watchActive().first, hasLength(1));
  });

  test(
    'editing transfer amount and destination recalculates both sides',
    () async {
      final source = await accounts.create(name: 'A', type: AccountType.bank);
      final firstDestination = await accounts.create(
        name: 'B',
        type: AccountType.cash,
      );
      final secondDestination = await accounts.create(
        name: 'C',
        type: AccountType.savings,
      );
      final transfer = await transfers.create(
        fromAccountId: source.id,
        toAccountId: firstDestination.id,
        amount: 2000000,
        transferDate: DateTime(2026, 8, 31),
      );

      await transfers.update(transfer.copyWith(amount: 3000000));
      expect((await _summary(accounts, source.id)).balance, -3000000);
      expect((await _summary(accounts, firstDestination.id)).balance, 3000000);

      final edited = transfer.copyWith(
        amount: 3000000,
        toAccountId: secondDestination.id,
      );
      await transfers.update(edited);
      expect((await _summary(accounts, source.id)).balance, -3000000);
      expect((await _summary(accounts, firstDestination.id)).balance, 0);
      expect((await _summary(accounts, secondDestination.id)).balance, 3000000);

      await transfers.update(
        edited.copyWith(fromAccountId: firstDestination.id),
      );
      expect((await _summary(accounts, source.id)).balance, 0);
      expect((await _summary(accounts, firstDestination.id)).balance, -3000000);
      expect((await _summary(accounts, secondDestination.id)).balance, 3000000);
    },
  );

  test(
    'soft delete reverses transfer and archived references remain readable',
    () async {
      final source = await accounts.create(name: 'A', type: AccountType.bank);
      final destination = await accounts.create(
        name: 'B',
        type: AccountType.cash,
      );
      final transfer = await transfers.create(
        fromAccountId: source.id,
        toAccountId: destination.id,
        amount: 1000000,
        transferDate: DateTime(2026, 8, 31),
      );

      expect(await accounts.archive(source.id), isTrue);
      final rows = await transfers.watchActive().first;
      expect(rows.single.from.name, 'A');
      expect((await _summary(accounts, source.id)).balance, -1000000);

      expect(await transfers.softDelete(transfer.id), isTrue);
      expect(await transfers.watchActive().first, isEmpty);
      expect((await _summary(accounts, source.id)).balance, 0);
      expect((await _summary(accounts, destination.id)).balance, 0);
    },
  );

  test(
    'rejects same, missing, inactive, and invalid transfer accounts or amounts',
    () async {
      final source = await accounts.create(name: 'A', type: AccountType.bank);
      final destination = await accounts.create(
        name: 'B',
        type: AccountType.cash,
      );

      await expectLater(
        transfers.create(
          fromAccountId: source.id,
          toAccountId: source.id,
          amount: 1,
          transferDate: DateTime(2026, 8, 31),
        ),
        throwsArgumentError,
      );
      await expectLater(
        transfers.create(
          fromAccountId: source.id,
          toAccountId: destination.id,
          amount: 0,
          transferDate: DateTime(2026, 8, 31),
        ),
        throwsArgumentError,
      );
      expect(await accounts.archive(destination.id), isTrue);
      await expectLater(
        transfers.create(
          fromAccountId: source.id,
          toAccountId: destination.id,
          amount: 1,
          transferDate: DateTime(2026, 8, 31),
        ),
        throwsStateError,
      );
      await expectLater(
        transfers.create(
          fromAccountId: source.id,
          toAccountId: 999,
          amount: 1,
          transferDate: DateTime(2026, 8, 31),
        ),
        throwsStateError,
      );
    },
  );

  test('allows a negative source balance', () async {
    final source = await accounts.create(
      name: 'A',
      type: AccountType.cash,
      initialBalance: 500000,
    );
    final destination = await accounts.create(
      name: 'B',
      type: AccountType.cash,
    );
    await transfers.create(
      fromAccountId: source.id,
      toAccountId: destination.id,
      amount: 1000000,
      transferDate: DateTime(2026, 8, 31),
    );

    expect((await _summary(accounts, source.id)).balance, -500000);
    expect((await _summary(accounts, destination.id)).balance, 1000000);
  });
}

Future<CategoryRecord> _category(
  AppDatabase database,
  String name,
  TransactionType type,
) {
  return database
      .into(database.categories)
      .insertReturning(CategoriesCompanion.insert(name: name, type: type));
}

Future<AccountSummary> _summary(AccountRepository repository, int id) async {
  final summaries = await repository.watchSummaries().first;
  return summaries.singleWhere((summary) => summary.account.id == id);
}
