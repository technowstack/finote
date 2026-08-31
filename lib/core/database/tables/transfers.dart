import 'package:drift/drift.dart';

import '../../utils/uuid_generator.dart';
import '../converters.dart';
import 'accounts.dart';

@DataClassName('TransferRecord')
@TableIndex(name: 'transfers_from_account_id', columns: {#fromAccountId})
@TableIndex(name: 'transfers_to_account_id', columns: {#toAccountId})
@TableIndex(name: 'transfers_date', columns: {#transferDate})
@TableIndex(name: 'transfers_deleted_at', columns: {#deletedAt})
class Transfers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().clientDefault(generateUuid).unique()();
  IntColumn get fromAccountId =>
      integer().references(Accounts, #id, onDelete: KeyAction.restrict)();
  IntColumn get toAccountId =>
      integer().references(Accounts, #id, onDelete: KeyAction.restrict)();
  IntColumn get amount =>
      integer().customConstraint('NOT NULL CHECK (amount > 0)')();
  TextColumn get transferDate => text().map(const DateOnlyConverter())();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();
  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  List<String> get customConstraints => [
    'CHECK (from_account_id <> to_account_id)',
  ];
}
