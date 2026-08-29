import 'package:finote/features/backup/domain/backup_manifest.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('valid manifest round-trips all required version metadata', () {
    final manifest = BackupManifest.create(
      databaseVersion: 2,
      createdAt: DateTime.utc(2026, 8, 29, 7, 5),
      appVersion: '1.0.0',
    );
    final restored = BackupManifest.fromJson(manifest.toJson());

    expect(restored.application, 'Catatan Keuangan');
    expect(restored.backupVersion, 1);
    expect(restored.databaseVersion, 2);
    expect(restored.createdAt, DateTime.utc(2026, 8, 29, 7, 5));
    expect(restored.appVersion, '1.0.0');
  });

  test('manifest validation rejects missing or unsupported metadata', () {
    final valid = BackupManifest.create(
      databaseVersion: 2,
      createdAt: DateTime.utc(2026, 8, 29),
      appVersion: '1.0.0',
    ).toJson();

    for (final invalid in [
      {...valid}..remove('application'),
      {...valid, 'backupVersion': 99},
      {...valid, 'databaseVersion': 0},
      {...valid, 'createdAt': 'not-a-date'},
      {...valid, 'appVersion': ''},
    ]) {
      expect(
        () => BackupManifest.fromJson(invalid),
        throwsA(isA<FormatException>()),
      );
    }
  });
}
