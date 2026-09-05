enum AssetTransactionAction { openingPosition, buy, sell, adjustment }

extension AssetTransactionActionDatabaseValue on AssetTransactionAction {
  String get databaseValue => switch (this) {
    AssetTransactionAction.openingPosition => 'openingPosition',
    AssetTransactionAction.buy => 'buy',
    AssetTransactionAction.sell => 'sell',
    AssetTransactionAction.adjustment => 'adjustment',
  };
}
