import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../categories/data/category_repository.dart';

class ResetDataService {
  ResetDataService(this._database, this._categories);

  final AppDatabase _database;
  final CategoryRepository _categories;

  Future<void> reset() async {
    await _database.transaction(() async {
      // Delete children first because the financial schema intentionally uses
      // restrictive foreign keys for user data.
      await _database.delete(_database.assetPrices).go();
      await _database.delete(_database.assetTransactions).go();
      await _database.delete(_database.assets).go();
      await _database.delete(_database.transfers).go();
      await _database.delete(_database.transactions).go();
      await _database.delete(_database.categories).go();
      await _database.delete(_database.accounts).go();
      await _database.delete(_database.settings).go();

      await _database.ensureDefaultAccount();
      await _categories.seedDefaults();
    });
  }
}

final resetDataServiceProvider = Provider<ResetDataService>((ref) {
  return ResetDataService(
    ref.watch(databaseProvider),
    ref.watch(categoryRepositoryProvider),
  );
});
