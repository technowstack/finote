import 'package:drift/drift.dart';

import '../../utils/uuid_generator.dart';
import '../converters.dart';

@DataClassName('CategoryRecord')
@TableIndex(name: 'categories_type', columns: {#type})
@TableIndex(name: 'categories_deleted_at', columns: {#deletedAt})
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().clientDefault(generateUuid).unique()();
  TextColumn get name => text()();
  TextColumn get type => text()
      .customConstraint("NOT NULL CHECK (type IN ('income', 'expense'))")
      .map(const TransactionTypeConverter())();
  TextColumn get icon => text().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();
  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}
