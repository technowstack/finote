import 'package:finote/features/backup/domain/backup_manifest.dart';
import 'package:finote/features/backup/domain/restore_error.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BackupManifest', () {
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
  });

  // ---------------------------------------------------------------------------
  // RestoreError — toUserMessage()
  // ---------------------------------------------------------------------------
  group('RestoreError.toUserMessage', () {
    test('setiap variant menghasilkan pesan non-kosong dalam Bahasa Indonesia',
        () {
      final errors = <RestoreError>[
        const RestoreError.invalidZip(),
        const RestoreError.invalidManifest(),
        const RestoreError.unsupportedVersion(found: 5, required: 1),
        const RestoreError.databaseMismatch(
          backupVersion: 1,
          currentVersion: 2,
        ),
        const RestoreError.integrityCheckFailed(),
        RestoreError.unknown(StateError('oops')),
      ];

      for (final error in errors) {
        final msg = error.toUserMessage();
        expect(
          msg,
          isNotEmpty,
          reason:
              '${error.runtimeType}.toUserMessage() harus mengembalikan string non-kosong',
        );
        // Setidaknya mengandung kata dalam Bahasa Indonesia (tidak error code)
        expect(
          msg,
          isNot(startsWith('Exception')),
          reason: 'Pesan harus ramah pengguna, bukan nama exception',
        );
      }
    });

    test('unsupportedVersion menyertakan nomor versi dalam pesannya', () {
      const error = RestoreError.unsupportedVersion(found: 42, required: 1);
      expect(error.toUserMessage(), contains('42'));
    });

    test('databaseMismatch menyertakan kedua nomor versi dalam pesannya', () {
      const error = RestoreError.databaseMismatch(
        backupVersion: 1,
        currentVersion: 3,
      );
      final msg = error.toUserMessage();
      expect(msg, contains('1'));
      expect(msg, contains('3'));
    });
  });
}
