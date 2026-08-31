import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';

class TransferRepository {
  TransferRepository(this._database);

  final AppDatabase _database;

  Stream<List<TransferListItem>> watchActive() {
    return (_database.select(_database.transfers)
          ..where((transfer) => transfer.deletedAt.isNull())
          ..orderBy([
            (transfer) => OrderingTerm.desc(transfer.transferDate),
            (transfer) => OrderingTerm.desc(transfer.createdAt),
          ]))
        .watch()
        .asyncMap((transfers) async {
          final accounts = await _database.select(_database.accounts).get();
          final byId = {for (final account in accounts) account.id: account};
          return [
            for (final transfer in transfers)
              if (byId[transfer.fromAccountId] case final from?)
                if (byId[transfer.toAccountId] case final to?)
                  (transfer: transfer, from: from, to: to),
          ];
        });
  }

  Future<TransferRecord?> findById(int id) {
    return (_database.select(
      _database.transfers,
    )..where((transfer) => transfer.id.equals(id))).getSingleOrNull();
  }

  Future<TransferRecord> create({
    required int fromAccountId,
    required int toAccountId,
    required int amount,
    required DateTime transferDate,
    String? note,
  }) async {
    _validate(fromAccountId, toAccountId, amount);
    await _requireActiveAccount(fromAccountId);
    await _requireActiveAccount(toAccountId);
    return _database
        .into(_database.transfers)
        .insertReturning(
          TransfersCompanion.insert(
            fromAccountId: fromAccountId,
            toAccountId: toAccountId,
            amount: amount,
            transferDate: transferDate,
            note: Value(note?.trim()),
          ),
        );
  }

  Future<bool> update(TransferRecord transfer) async {
    _validate(transfer.fromAccountId, transfer.toAccountId, transfer.amount);
    if (transfer.deletedAt != null) {
      throw ArgumentError('Use softDelete to delete a transfer');
    }
    await _requireAccount(transfer.fromAccountId);
    await _requireAccount(transfer.toAccountId);
    final count =
        await (_database.update(_database.transfers)..where(
              (row) => row.id.equals(transfer.id) & row.deletedAt.isNull(),
            ))
            .write(
              transfer
                  .copyWith(updatedAt: DateTime.now().toUtc())
                  .toCompanion(true),
            );
    return count == 1;
  }

  Future<bool> softDelete(int id) async {
    final now = DateTime.now().toUtc();
    final count =
        await (_database.update(_database.transfers)..where(
              (transfer) =>
                  transfer.id.equals(id) & transfer.deletedAt.isNull(),
            ))
            .write(
              TransfersCompanion(deletedAt: Value(now), updatedAt: Value(now)),
            );
    return count == 1;
  }

  void _validate(int fromAccountId, int toAccountId, int amount) {
    if (fromAccountId == toAccountId) {
      throw ArgumentError('Akun asal dan tujuan tidak boleh sama.');
    }
    if (amount <= 0 || amount > 9223372036854775807) {
      throw ArgumentError('Masukkan nominal transfer yang valid.');
    }
  }

  Future<void> _requireActiveAccount(int id) async {
    final account = await _requireAccount(id);
    if (!account.isActive) throw StateError('Account must be active');
  }

  Future<AccountRecord> _requireAccount(int id) async {
    final account = await (_database.select(
      _database.accounts,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    if (account == null) throw StateError('Account does not exist');
    return account;
  }
}

typedef TransferListItem = ({
  TransferRecord transfer,
  AccountRecord from,
  AccountRecord to,
});

final transferRepositoryProvider = Provider<TransferRepository>(
  (ref) => TransferRepository(ref.watch(databaseProvider)),
);

final transfersProvider = StreamProvider<List<TransferListItem>>(
  (ref) => ref.watch(transferRepositoryProvider).watchActive(),
);
