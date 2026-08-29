import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../transactions/domain/transaction_type.dart';

class CategoryRepository {
  CategoryRepository(this._database);

  final AppDatabase _database;

  Stream<List<CategoryRecord>> watchAll() {
    return (_database.select(_database.categories)
          ..where((category) => category.deletedAt.isNull())
          ..orderBy([
            (category) => OrderingTerm.asc(category.type),
            (category) => OrderingTerm.asc(category.name),
          ]))
        .watch();
  }

  Stream<List<CategoryRecord>> watchByType(TransactionType type) {
    return (_database.select(_database.categories)
          ..where(
            (category) =>
                category.type.equals(type.name) & category.deletedAt.isNull(),
          )
          ..orderBy([(category) => OrderingTerm.asc(category.name)]))
        .watch();
  }

  Future<void> initializeDefaults() {
    return _database.transaction(() async {
      final initialized =
          await (_database.select(_database.settings)
                ..where((setting) => setting.key.equals(_defaultsSettingKey)))
              .getSingleOrNull();
      if (initialized != null) return;

      for (final category in _defaultCategories) {
        final existing =
            await (_database.select(_database.categories)..where(
                  (row) =>
                      row.name.equals(category.name) &
                      row.type.equals(category.type.name),
                ))
                .getSingleOrNull();
        if (existing == null) {
          await _database
              .into(_database.categories)
              .insert(
                CategoriesCompanion.insert(
                  name: category.name,
                  type: category.type,
                ),
              );
        }
      }

      await _database
          .into(_database.settings)
          .insert(
            SettingsCompanion.insert(key: _defaultsSettingKey, value: '1'),
          );
    });
  }

  Future<CategoryRecord> create({
    required String name,
    required TransactionType type,
    String? icon,
  }) {
    if (name.trim().isEmpty) {
      throw ArgumentError.value(name, 'name', 'Category name cannot be empty');
    }

    return _database
        .into(_database.categories)
        .insertReturning(
          CategoriesCompanion.insert(
            name: name.trim(),
            type: type,
            icon: Value(icon),
          ),
        );
  }

  Future<CategoryRecord?> findActiveById(int id) {
    return (_database.select(_database.categories)..where(
          (category) => category.id.equals(id) & category.deletedAt.isNull(),
        ))
        .getSingleOrNull();
  }

  Future<bool> rename(int id, String name) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Category name cannot be empty');
    }

    final count =
        await (_database.update(_database.categories)..where(
              (category) =>
                  category.id.equals(id) & category.deletedAt.isNull(),
            ))
            .write(
              CategoriesCompanion(
                name: Value(normalizedName),
                updatedAt: Value(DateTime.now().toUtc()),
              ),
            );
    return count == 1;
  }

  Future<bool> softDelete(int id) async {
    final now = DateTime.now().toUtc();
    final count =
        await (_database.update(_database.categories)..where(
              (category) =>
                  category.id.equals(id) & category.deletedAt.isNull(),
            ))
            .write(
              CategoriesCompanion(updatedAt: Value(now), deletedAt: Value(now)),
            );
    return count == 1;
  }
}

final categoryRepositoryProvider = Provider<CategoryRepository>(
  (ref) => CategoryRepository(ref.watch(databaseProvider)),
);

final categoryInitializationProvider = FutureProvider<void>(
  (ref) => ref.watch(categoryRepositoryProvider).initializeDefaults(),
);

final categoriesProvider = StreamProvider<List<CategoryRecord>>(
  (ref) => ref.watch(categoryRepositoryProvider).watchAll(),
);

final categoriesByTypeProvider =
    StreamProvider.family<List<CategoryRecord>, TransactionType>(
      (ref, type) => ref.watch(categoryRepositoryProvider).watchByType(type),
    );

const _defaultsSettingKey = 'default_categories_initialized';

const _defaultCategories = [
  (name: 'Makanan & Minuman', type: TransactionType.expense),
  (name: 'Transportasi', type: TransactionType.expense),
  (name: 'Belanja', type: TransactionType.expense),
  (name: 'Tagihan', type: TransactionType.expense),
  (name: 'Hiburan', type: TransactionType.expense),
  (name: 'Kesehatan', type: TransactionType.expense),
  (name: 'Pendidikan', type: TransactionType.expense),
  (name: 'Rumah', type: TransactionType.expense),
  (name: 'Keluarga', type: TransactionType.expense),
  (name: 'Lainnya', type: TransactionType.expense),
  (name: 'Gaji', type: TransactionType.income),
  (name: 'Bonus', type: TransactionType.income),
  (name: 'Bisnis', type: TransactionType.income),
  (name: 'Hadiah', type: TransactionType.income),
  (name: 'Investasi', type: TransactionType.income),
  (name: 'Lainnya', type: TransactionType.income),
];
