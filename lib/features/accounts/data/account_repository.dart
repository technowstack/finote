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
      SELECT a.id,
             a.uuid,
             a.name,
             a.type,
             a.initial_balance,
             a.is_active,
             a.is_default,
             a.created_at,
             a.updated_at,
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

    return aggregate.map(
      (rows) => [
        for (final row in rows)
          AccountSummary(
            account: _database.accounts.map(row.data),
            totalIncome: row.read<int>('total_income'),
            totalExpense: row.read<int>('total_expense'),
            totalIncomingTransfer: row.read<int>('total_incoming_transfer'),
            totalOutgoingTransfer: row.read<int>('total_outgoing_transfer'),
          ),
      ],
    );
  }

  Future<AccountRecord?> findById(int id) {
    return (_database.select(
      _database.accounts,
    )..where((account) => account.id.equals(id))).getSingleOrNull();
  }

  Future<AccountUsage?> getAccountUsage(int id) => _getAccountUsage(id);

  Future<bool> canDeleteAccount(int id) async {
    return (await _getAccountUsage(id))?.canDelete ?? false;
  }

  Future<bool> deleteUnusedAccount(int id) {
    return _database.transaction(() async {
      final usage = await _getAccountUsage(id);
      if (usage == null || !usage.canDelete) return false;
      final deleted = await (_database.delete(
        _database.accounts,
      )..where((account) => account.id.equals(id))).go();
      return deleted == 1;
    });
  }

  Future<AccountUsage?> _getAccountUsage(int id) async {
    final row = await _database
        .customSelect(
          '''
          SELECT a.is_default,
                 (SELECT COUNT(*) FROM transactions t
                  WHERE t.account_id = a.id) AS transaction_count,
                 (SELECT COUNT(*) FROM transfers tr
                  WHERE tr.to_account_id = a.id) AS incoming_transfer_count,
                 (SELECT COUNT(*) FROM transfers tr
                  WHERE tr.from_account_id = a.id) AS outgoing_transfer_count
          FROM accounts a
          WHERE a.id = ?
          ''',
          variables: [Variable.withInt(id)],
          readsFrom: {
            _database.accounts,
            _database.transactions,
            _database.transfers,
          },
        )
        .getSingleOrNull();
    if (row == null) return null;
    return AccountUsage(
      isDefault: row.read<int>('is_default') != 0,
      transactionCount: row.read<int>('transaction_count'),
      incomingTransferCount: row.read<int>('incoming_transfer_count'),
      outgoingTransferCount: row.read<int>('outgoing_transfer_count'),
    );
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
    if (account.isDefault) {
      throw StateError('Default account cannot be archived');
    }

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

class AccountUsage {
  const AccountUsage({
    required this.isDefault,
    required this.transactionCount,
    required this.incomingTransferCount,
    required this.outgoingTransferCount,
  });

  final bool isDefault;
  final int transactionCount;
  final int incomingTransferCount;
  final int outgoingTransferCount;

  bool get hasFinancialHistory =>
      transactionCount > 0 ||
      incomingTransferCount > 0 ||
      outgoingTransferCount > 0;

  bool get canDelete => !isDefault && !hasFinancialHistory;
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
