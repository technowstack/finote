enum AssetTransactionAction { openingPosition, buy, sell, adjustment }

extension AssetTransactionActionDatabaseValue on AssetTransactionAction {
  String get databaseValue => name;
}
