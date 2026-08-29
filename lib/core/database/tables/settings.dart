import 'package:drift/drift.dart';

@DataClassName('SettingRecord')
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();

  @override
  Set<Column<Object>> get primaryKey => {key};
}
