import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../domain/account_type.dart';
import '../domain/account_summary.dart';

class AccountRepository {
  AccountRepository(this._database);

  final AppDatabase _database;

  Future<void> initializeDefaults() => _database.ensureDefaultAccount();

  Stream<List<AccountRecord>> watchActive() {
    return (_database.select(_database.accounts)
          ..where((account) => account.isActive.equals(true))
          ..orderBy([(account) => OrderingTerm.asc(account.name)]))
        .watch();
  }

  Stream<List<AccountRecord>> watchAll() {
    return (_database.select(_database.accounts)..orderBy([
          (account) => OrderingTerm.desc(account.isActive),
          (account) => OrderingTerm.asc(account.name),
        ]))
        .watch();
  }

  Stream<List<AccountSummary>> watchSummaries() {
    final aggregate = _database
        .customSelect(
          '''
      SELECT a.id AS account_id,
             COALESCE(SUM(CASE WHEN t.type = 'income' THEN t.amount ELSE 0 END), 0)
               AS total_income,
             COALESCE(SUM(CASE WHEN t.type = 'expense' THEN t.amount ELSE 0 END), 0)
               AS total_expense,
             COALESCE(incoming.total_amount, 0) AS total_incoming_transfer,
             COALESCE(outgoing.total_amount, 0) AS total_outgoing_transfer
      FROM accounts a
      LEFT JOIN transactions t
        ON t.account_id = a.id AND t.deleted_at IS NULL
      LEFT JOIN (
        SELECT to_account_id AS account_id, SUM(amount) AS total_amount
        FROM transfers
        WHERE deleted_at IS NULL
        GROUP BY to_account_id
      ) incoming ON incoming.account_id = a.id
      LEFT JOIN (
        SELECT from_account_id AS account_id, SUM(amount) AS total_amount
        FROM transfers
        WHERE deleted_at IS NULL
        GROUP BY from_account_id
      ) outgoing ON outgoing.account_id = a.id
      GROUP BY a.id
      ORDER BY a.is_active DESC, a.name ASC
      ''',
          readsFrom: {
            _database.accounts,
            _database.transactions,
            _database.transfers,
          },
        )
        .watch();

    return aggregate.asyncMap((rows) async {
      final accounts =
          await (_database.select(_database.accounts)..orderBy([
                (account) => OrderingTerm.desc(account.isActive),
                (account) => OrderingTerm.asc(account.name),
              ]))
              .get();
      final byId = {for (final account in accounts) account.id: account};
      return [
        for (final row in rows)
          if (byId[row.read<int>('account_id')] case final account?)
            AccountSummary(
              account: account,
              totalIncome: row.read<int>('total_income'),
              totalExpense: row.read<int>('total_expense'),
              totalIncomingTransfer: row.read<int>('total_incoming_transfer'),
              totalOutgoingTransfer: row.read<int>('total_outgoing_transfer'),
            ),
      ];
    });
  }

  Future<AccountRecord?> findById(int id) {
    return (_database.select(
      _database.accounts,
    )..where((account) => account.id.equals(id))).getSingleOrNull();
  }

  Future<AccountRecord> create({
    required String name,
    required AccountType type,
    int initialBalance = 0,
  }) async {
    final normalizedName = _validate(name, initialBalance);
    return _database
        .into(_database.accounts)
        .insertReturning(
          AccountsCompanion.insert(
            name: normalizedName,
            type: type,
            initialBalance: Value(initialBalance),
          ),
        );
  }

  Future<bool> update({
    required int id,
    required String name,
    required AccountType type,
    required int initialBalance,
  }) async {
    final normalizedName = _validate(name, initialBalance);
    final count =
        await (_database.update(
          _database.accounts,
        )..where((account) => account.id.equals(id))).write(
          AccountsCompanion(
            name: Value(normalizedName),
            type: Value(type),
            initialBalance: Value(initialBalance),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
    return count == 1;
  }

  Future<bool> archive(int id) async {
    final account = await findById(id);
    if (account == null || !account.isActive) return false;

    final active = await (_database.select(
      _database.accounts,
    )..where((row) => row.isActive.equals(true))).get();
    if (active.length <= 1) {
      throw StateError('At least one active account is required');
    }

    return _setActive(id, false);
  }

  Future<bool> reactivate(int id) => _setActive(id, true);

  Future<bool> _setActive(int id, bool isActive) async {
    final count =
        await (_database.update(
          _database.accounts,
        )..where((account) => account.id.equals(id))).write(
          AccountsCompanion(
            isActive: Value(isActive),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
    return count == 1;
  }

  String _validate(String name, int initialBalance) {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Account name cannot be empty');
    }
    if (normalizedName.length > 100) {
      throw ArgumentError.value(name, 'name', 'Account name is too long');
    }
    if (initialBalance < 0) {
      throw ArgumentError.value(
        initialBalance,
        'initialBalance',
        'Initial balance cannot be negative',
      );
    }
    return normalizedName;
  }
}

final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => AccountRepository(ref.watch(databaseProvider)),
);

final accountInitializationProvider = FutureProvider<void>(
  (ref) => ref.watch(accountRepositoryProvider).initializeDefaults(),
);

final accountsProvider = StreamProvider<List<AccountRecord>>(
  (ref) => ref.watch(accountRepositoryProvider).watchAll(),
);

final accountSummariesProvider = StreamProvider<List<AccountSummary>>(
  (ref) => ref.watch(accountRepositoryProvider).watchSummaries(),
);

final activeAccountsProvider = StreamProvider<List<AccountRecord>>(
  (ref) => ref.watch(accountRepositoryProvider).watchActive(),
);

final accountByIdProvider = FutureProvider.family<AccountRecord?, int>(
  (ref, id) => ref.watch(accountRepositoryProvider).findById(id),
);
