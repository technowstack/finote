import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../domain/account_type.dart';

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

final activeAccountsProvider = StreamProvider<List<AccountRecord>>(
  (ref) => ref.watch(accountRepositoryProvider).watchActive(),
);
