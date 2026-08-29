import 'package:drift/native.dart';
import 'package:finote/core/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('database starts at schema version 1', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    expect(database.schemaVersion, 1);
    final version = await database
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(version.read<int>('user_version'), 1);
  });
}
