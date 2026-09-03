import 'package:drift/drift.dart';

import 'assets.dart';

@DataClassName('AssetPriceRecord')
@TableIndex(name: 'asset_prices_asset_id', columns: {#assetId}, unique: true)
@TableIndex(name: 'asset_prices_fetched_at', columns: {#fetchedAt})
class AssetPrices extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get assetId =>
      integer().references(Assets, #id, onDelete: KeyAction.cascade)();
  IntColumn get priceAmount => integer()();
  TextColumn get currency => text()();
  DateTimeColumn get marketUpdatedAt => dateTime().nullable()();
  DateTimeColumn get fetchedAt => dateTime()();
  BoolColumn get isBackendStale =>
      boolean().withDefault(const Constant(false))();

  @override
  List<String> get customConstraints => ['CHECK (price_amount >= 0)'];
}
