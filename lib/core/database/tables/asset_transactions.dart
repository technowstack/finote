import 'package:drift/drift.dart';

import '../../../features/assets/domain/asset_transaction_action.dart';
import '../../utils/uuid_generator.dart';
import '../converters.dart';
import 'assets.dart';
import 'transactions.dart';

class AssetTransactionActionConverter
    extends TypeConverter<AssetTransactionAction, String> {
  const AssetTransactionActionConverter();

  @override
  AssetTransactionAction fromSql(String fromDb) => switch (fromDb) {
    'openingPosition' => AssetTransactionAction.openingPosition,
    'buy' => AssetTransactionAction.buy,
    'sell' => AssetTransactionAction.sell,
    'adjustment' => AssetTransactionAction.adjustment,
    _ => throw FormatException('Unknown asset transaction action: $fromDb'),
  };

  @override
  String toSql(AssetTransactionAction value) => value.databaseValue;
}

@DataClassName('AssetTransactionRecord')
@TableIndex(name: 'asset_transactions_asset_id', columns: {#assetId})
@TableIndex(name: 'asset_transactions_date', columns: {#transactionDate})
@TableIndex(name: 'asset_transactions_deleted_at', columns: {#deletedAt})
@TableIndex(
  name: 'asset_transactions_source_transaction_id',
  columns: {#sourceTransactionId},
  unique: true,
)
class AssetTransactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().clientDefault(generateUuid).unique()();
  IntColumn get assetId =>
      integer().references(Assets, #id, onDelete: KeyAction.restrict)();
  TextColumn get action => text()
      .customConstraint(
        'NOT NULL CHECK ("action" IN '
        "('openingPosition', 'buy', 'sell', 'adjustment'))",
      )
      .map(const AssetTransactionActionConverter())();
  IntColumn get quantityScaled =>
      integer().customConstraint('NOT NULL CHECK (quantity_scaled <> 0)')();
  IntColumn get priceAmount => integer().nullable()();
  IntColumn get totalAmount => integer().nullable()();
  TextColumn get transactionDate => text().map(const DateOnlyConverter())();
  TextColumn get note => text().nullable()();
  IntColumn get sourceTransactionId => integer().nullable().references(
    Transactions,
    #id,
    onDelete: KeyAction.restrict,
  )();
  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();
  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  List<String> get customConstraints => [
    'CHECK (price_amount IS NULL OR price_amount >= 0)',
    'CHECK (total_amount IS NULL OR total_amount >= 0)',
  ];
}
