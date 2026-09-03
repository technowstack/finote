import 'package:drift/drift.dart';

import '../../../features/assets/domain/asset_type.dart';
import '../../utils/uuid_generator.dart';

class AssetTypeConverter extends TypeConverter<AssetType, String> {
  const AssetTypeConverter();

  @override
  AssetType fromSql(String fromDb) => switch (fromDb) {
    'stock' => AssetType.stock,
    'crypto' => AssetType.crypto,
    'mutualFund' => AssetType.mutualFund,
    'gold' => AssetType.gold,
    'other' => AssetType.other,
    _ => throw FormatException('Unknown asset type: $fromDb'),
  };

  @override
  String toSql(AssetType value) => value.databaseValue;
}

class AssetPricingModeConverter
    extends TypeConverter<AssetPricingMode, String> {
  const AssetPricingModeConverter();

  @override
  AssetPricingMode fromSql(String fromDb) => switch (fromDb) {
    'api' => AssetPricingMode.api,
    'manual' => AssetPricingMode.manual,
    _ => throw FormatException('Unknown asset pricing mode: $fromDb'),
  };

  @override
  String toSql(AssetPricingMode value) => value.databaseValue;
}

@DataClassName('AssetRecord')
@TableIndex(
  name: 'assets_type_normalized_symbol',
  columns: {#assetType, #normalizedSymbol},
  unique: true,
)
@TableIndex(name: 'assets_active', columns: {#isActive})
class Assets extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().clientDefault(generateUuid).unique()();
  TextColumn get symbol => text().nullable()();
  TextColumn get normalizedSymbol => text().nullable()();
  TextColumn get name => text()();
  TextColumn get assetType => text()
      .customConstraint(
        "NOT NULL CHECK (asset_type IN "
        "('stock', 'crypto', 'mutualFund', 'gold', 'other'))",
      )
      .map(const AssetTypeConverter())();
  TextColumn get pricingMode => text()
      .customConstraint("NOT NULL CHECK (pricing_mode IN ('api', 'manual'))")
      .map(const AssetPricingModeConverter())();
  TextColumn get currency => text().withDefault(const Constant('IDR'))();
  TextColumn get unitLabel => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();
  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();
}
