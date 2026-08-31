import 'package:drift/drift.dart';

import '../../utils/uuid_generator.dart';
import 'accounts.dart';
import '../converters.dart';
import 'categories.dart';

@DataClassName('TransactionRecord')
@TableIndex(name: 'transactions_date', columns: {#transactionDate})
@TableIndex(name: 'transactions_category_id', columns: {#categoryId})
@TableIndex(name: 'transactions_type', columns: {#type})
@TableIndex(name: 'transactions_deleted_at', columns: {#deletedAt})
@TableIndex(name: 'transactions_account_id', columns: {#accountId})
@TableIndex(
  name: 'transactions_receipt_fingerprint',
  columns: {#receiptFingerprint},
)
@TableIndex(
  name: 'transactions_legacy_source_id',
  columns: {#legacySource, #legacyId},
  unique: true,
)
class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().clientDefault(generateUuid).unique()();
  TextColumn get type => text()
      .customConstraint("NOT NULL CHECK (type IN ('income', 'expense'))")
      .map(const TransactionTypeConverter())();
  IntColumn get accountId => integer().nullable().references(
    Accounts,
    #id,
    onDelete: KeyAction.restrict,
  )();
  IntColumn get categoryId =>
      integer().references(Categories, #id, onDelete: KeyAction.restrict)();
  IntColumn get amount =>
      integer().customConstraint('NOT NULL CHECK (amount > 0)')();
  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get note => text().nullable()();
  TextColumn get transactionDate => text().map(const DateOnlyConverter())();
  TextColumn get source => text()
      .customConstraint(
        "NOT NULL CHECK (source IN ('manual', 'legacy_import', "
        "'receipt_scan', 'recurring'))",
      )
      .map(const TransactionSourceConverter())();
  TextColumn get receiptFingerprint => text().nullable()();
  TextColumn get legacySource => text().nullable()();
  IntColumn get legacyId => integer().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();
  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  List<String> get customConstraints => [
    'CHECK ((legacy_source IS NULL AND legacy_id IS NULL) OR '
        '(legacy_source IS NOT NULL AND legacy_id IS NOT NULL))',
  ];
}
