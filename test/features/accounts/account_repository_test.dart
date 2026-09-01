import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:finote/core/database/app_database.dart';
import 'package:finote/features/accounts/data/account_repository.dart';
import 'package:finote/features/accounts/domain/account_type.dart';
import 'package:finote/features/accounts/domain/account_summary.dart';
import 'package:finote/features/transactions/data/transaction_repository.dart';
import 'package:finote/features/transactions/domain/transaction_type.dart';
import 'package:finote/features/transfers/data/transfer_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late AccountRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = AccountRepository(database);
  });

  tearDown(() => database.close());

  test('default account is created once and remains stable', () async {
    final first = await database.select(database.accounts).getSingle();
    await repository.initializeDefaults();
    await repository.initializeDefaults();
    final second = await database.select(database.accounts).getSingle();

    expect(first.id, second.id);
    expect(first.uuid, second.uuid);
    expect(first.isDefault, isTrue);
    expect(first.type, AccountType.cash);
  });

  test('create and update trim names and preserve UUID', () async {
    final account = await repository.create(
      name: '  BCA Utama  ',
      type: AccountType.bank,
      initialBalance: 250000,
    );
    expect(account.name, 'BCA Utama');
    expect(account.initialBalance, 250000);
    expect(account.uuid, matches(_uuidPattern));

    expect(
      await repository.update(
        id: account.id,
        name: ' BCA Harian ',
        type: AccountType.savings,
        initialBalance: 0,
      ),
      isTrue,
    );
    final updated = await repository.findById(account.id);
    expect(updated?.name, 'BCA Harian');
    expect(updated?.type, AccountType.savings);
    expect(updated?.uuid, account.uuid);
  });

  test('accepts zero and large integer initial balances', () async {
    final zero = await repository.create(
      name: 'Tunai Cadangan',
      type: AccountType.cash,
    );
    final large = await repository.create(
      name: 'Tabungan',
      type: AccountType.savings,
      initialBalance: 9000000000000,
    );

    expect(zero.initialBalance, 0);
    expect(large.initialBalance, 9000000000000);
  });

  test('active account list reacts to archive and reactivation', () async {
    final account = await repository.create(
      name: 'GoPay',
      type: AccountType.eWallet,
    );
    expect(
      (await repository.watchActive().first).map((item) => item.name),
      contains('GoPay'),
    );

    expect(await repository.archive(account.id), isTrue);
    expect(
      (await repository.watchActive().first).map((item) => item.name),
      isNot(contains('GoPay')),
    );
    expect(await repository.reactivate(account.id), isTrue);
    expect(
      (await repository.watchActive().first).map((item) => item.name),
      contains('GoPay'),
    );
  });

  test('cannot archive the only active account', () async {
    final defaultAccount = await database.select(database.accounts).getSingle();
    await expectLater(repository.archive(defaultAccount.id), throwsStateError);
    expect((await repository.findById(defaultAccount.id))?.isActive, isTrue);
  });

  test('keeps the canonical default account active', () async {
    final defaultAccount = await database.select(database.accounts).getSingle();
    await repository.create(name: 'BCA', type: AccountType.bank);

    await expectLater(repository.archive(defaultAccount.id), throwsStateError);
    await (database.update(database.accounts)
          ..where((account) => account.id.equals(defaultAccount.id)))
        .write(const AccountsCompanion(isActive: Value(false)));
    await repository.initializeDefaults();

    final repaired = await repository.findById(defaultAccount.id);
    expect(repaired?.isActive, isTrue);
    expect(
      (await database.select(database.accounts).get()).where(
        (account) => account.isDefault,
      ),
      hasLength(1),
    );
  });

  test('rejects empty, overly long, and negative initial balance', () async {
    await expectLater(
      repository.create(name: '  ', type: AccountType.cash),
      throwsArgumentError,
    );
    await expectLater(
      repository.create(name: 'a' * 101, type: AccountType.cash),
      throwsArgumentError,
    );
    await expectLater(
      repository.create(
        name: 'Utang',
        type: AccountType.cash,
        initialBalance: -1,
      ),
      throwsArgumentError,
    );
  });

  test('deletes only unused non-default accounts', () async {
    final defaultAccount = await database.select(database.accounts).getSingle();
    final unused = await repository.create(
      name: 'Saldo Awal',
      type: AccountType.savings,
      initialBalance: 500000,
    );

    expect(await repository.canDeleteAccount(defaultAccount.id), isFalse);
    expect(await repository.deleteUnusedAccount(defaultAccount.id), isFalse);
    expect(await repository.canDeleteAccount(unused.id), isTrue);
    expect(await repository.deleteUnusedAccount(unused.id), isTrue);
    expect(await repository.findById(unused.id), isNull);
    expect(await repository.deleteUnusedAccount(unused.id), isFalse);
  });

  test('transaction history blocks deletion after soft delete', () async {
    final account = await repository.create(
      name: 'BCA',
      type: AccountType.bank,
    );
    final category = await _category(
      database,
      'Makan',
      TransactionType.expense,
    );
    final transactions = TransactionRepository(database);
    final transaction = await transactions.create(
      type: TransactionType.expense,
      categoryId: category.id,
      accountId: account.id,
      amount: 25000,
      transactionDate: DateTime(2026, 9, 1),
    );

    expect((await repository.getAccountUsage(account.id))?.transactionCount, 1);
    expect(await repository.deleteUnusedAccount(account.id), isFalse);
    await transactions.softDelete(transaction.id);
    expect(await repository.canDeleteAccount(account.id), isFalse);
    expect(await repository.findById(account.id), isNotNull);
  });

  test('incoming and outgoing transfer history blocks deletion', () async {
    final source = await repository.create(name: 'BCA', type: AccountType.bank);
    final destination = await repository.create(
      name: 'Tabungan',
      type: AccountType.savings,
    );
    final transfers = TransferRepository(database);
    final transfer = await transfers.create(
      fromAccountId: source.id,
      toAccountId: destination.id,
      amount: 100000,
      transferDate: DateTime(2026, 9, 1),
    );

    final sourceUsage = await repository.getAccountUsage(source.id);
    final destinationUsage = await repository.getAccountUsage(destination.id);
    expect(sourceUsage?.outgoingTransferCount, 1);
    expect(destinationUsage?.incomingTransferCount, 1);
    expect(await repository.deleteUnusedAccount(source.id), isFalse);
    expect(await repository.deleteUnusedAccount(destination.id), isFalse);

    await transfers.softDelete(transfer.id);
    expect(await repository.canDeleteAccount(source.id), isFalse);
    expect(await repository.canDeleteAccount(destination.id), isFalse);
  });

  test(
    'derives balances from initial balance and active transactions',
    () async {
      final account = await repository.create(
        name: 'BCA Utama',
        type: AccountType.bank,
        initialBalance: 1000000,
      );
      final expenseCategory = await _category(
        database,
        'Belanja',
        TransactionType.expense,
      );
      final incomeCategory = await _category(
        database,
        'Gaji',
        TransactionType.income,
      );
      final transactions = TransactionRepository(database);

      await transactions.create(
        type: TransactionType.income,
        categoryId: incomeCategory.id,
        accountId: account.id,
        amount: 10000000,
        transactionDate: DateTime(2026, 8, 31),
      );
      final expense = await transactions.create(
        type: TransactionType.expense,
        categoryId: expenseCategory.id,
        accountId: account.id,
        amount: 2500000,
        transactionDate: DateTime(2026, 8, 31),
      );

      expect((await _summary(repository, account.id)).balance, 8500000);

      await transactions.update(expense.copyWith(amount: 3000000));
      expect((await _summary(repository, account.id)).balance, 8000000);

      await transactions.softDelete(expense.id);
      expect((await _summary(repository, account.id)).balance, 11000000);
    },
  );

  test('keeps balances isolated and recalculates type changes', () async {
    final accountA = await repository.create(
      name: 'BCA',
      type: AccountType.bank,
      initialBalance: 1000000,
    );
    final accountB = await repository.create(
      name: 'Tunai Cadangan',
      type: AccountType.cash,
      initialBalance: 500000,
    );
    final expenseCategory = await _category(
      database,
      'Belanja',
      TransactionType.expense,
    );
    final incomeCategory = await _category(
      database,
      'Gaji',
      TransactionType.income,
    );
    final transactions = TransactionRepository(database);

    await transactions.create(
      type: TransactionType.income,
      categoryId: incomeCategory.id,
      accountId: accountA.id,
      amount: 10000000,
      transactionDate: DateTime(2026, 8, 31),
    );
    final expense = await transactions.create(
      type: TransactionType.expense,
      categoryId: expenseCategory.id,
      accountId: accountA.id,
      amount: 2000000,
      transactionDate: DateTime(2026, 8, 31),
    );
    await transactions.create(
      type: TransactionType.income,
      categoryId: incomeCategory.id,
      accountId: accountB.id,
      amount: 250000,
      transactionDate: DateTime(2026, 8, 31),
    );
    await transactions.create(
      type: TransactionType.expense,
      categoryId: expenseCategory.id,
      accountId: accountB.id,
      amount: 100000,
      transactionDate: DateTime(2026, 8, 31),
    );

    expect((await _summary(repository, accountA.id)).balance, 9000000);
    expect((await _summary(repository, accountB.id)).balance, 650000);

    await transactions.update(
      expense.copyWith(
        type: TransactionType.income,
        categoryId: incomeCategory.id,
      ),
    );
    expect((await _summary(repository, accountA.id)).balance, 13000000);

    await transactions.update(
      expense.copyWith(accountId: Value<int?>(accountB.id)),
    );
    expect((await _summary(repository, accountA.id)).balance, 11000000);
    expect((await _summary(repository, accountB.id)).balance, -1350000);

    expect(
      await repository.update(
        id: accountA.id,
        name: accountA.name,
        type: accountA.type,
        initialBalance: 2000000,
      ),
      isTrue,
    );
    expect((await _summary(repository, accountA.id)).balance, 12000000);

    expect(await repository.archive(accountB.id), isTrue);
    expect((await _summary(repository, accountB.id)).balance, -1350000);
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

final _uuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);
