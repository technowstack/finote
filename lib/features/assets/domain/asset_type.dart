enum AssetType { stock, crypto, mutualFund, gold, other }

extension AssetTypeDatabaseValue on AssetType {
  String get databaseValue => switch (this) {
    AssetType.stock => 'stock',
    AssetType.crypto => 'crypto',
    AssetType.mutualFund => 'mutualFund',
    AssetType.gold => 'gold',
    AssetType.other => 'other',
  };

  String get label => switch (this) {
    AssetType.stock => 'Saham',
    AssetType.crypto => 'Crypto',
    AssetType.mutualFund => 'Reksadana',
    AssetType.gold => 'Emas',
    AssetType.other => 'Lainnya',
  };

  String get description => switch (this) {
    AssetType.stock => 'Pantau saham secara offline',
    AssetType.crypto => 'Pantau aset crypto',
    AssetType.mutualFund => 'Input nilai secara manual',
    AssetType.gold => 'Input harga secara manual',
    AssetType.other => 'Aset manual atau custom',
  };

  AssetPricingMode get defaultPricingMode => switch (this) {
    AssetType.stock || AssetType.crypto => AssetPricingMode.api,
    AssetType.mutualFund ||
    AssetType.gold ||
    AssetType.other => AssetPricingMode.manual,
  };

  String get defaultUnitLabel => switch (this) {
    AssetType.stock => 'share',
    AssetType.crypto => 'coin/token',
    AssetType.mutualFund => 'unit',
    AssetType.gold => 'gram',
    AssetType.other => 'unit',
  };

  String get iconName => switch (this) {
    AssetType.stock => 'show_chart',
    AssetType.crypto => 'currency_bitcoin',
    AssetType.mutualFund => 'account_balance',
    AssetType.gold => 'savings',
    AssetType.other => 'inventory_2',
  };
}

enum AssetPricingMode { api, manual }

extension AssetPricingModeDatabaseValue on AssetPricingMode {
  String get databaseValue => switch (this) {
    AssetPricingMode.api => 'api',
    AssetPricingMode.manual => 'manual',
  };
}
