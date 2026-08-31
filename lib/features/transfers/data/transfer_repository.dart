import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';

class TransferRepository {
  TransferRepository(this._database);

  final AppDatabase _database;

  Stream<List<TransferListItem>> watchActive() {
    final transfers = _database.transfers;
    final source = _database.alias(_database.accounts, 'source_account');
    final destination = _database.alias(
      _database.accounts,
      'destination_account',
    );
    final query =
        _database.select(transfers).join([
            innerJoin(source, source.id.equalsExp(transfers.fromAccountId)),
            innerJoin(
              destination,
              destination.id.equalsExp(transfers.toAccountId),
            ),
          ])
          ..where(transfers.deletedAt.isNull())
          ..orderBy([
            OrderingTerm.desc(transfers.transferDate),
            OrderingTerm.desc(transfers.createdAt),
            OrderingTerm.desc(transfers.id),
          ]);

    return query.watch().map(
      (rows) => [
        for (final row in rows)
          (
            transfer: row.readTable(transfers),
            from: row.readTable(source),
            to: row.readTable(destination),
          ),
      ],
    );
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
