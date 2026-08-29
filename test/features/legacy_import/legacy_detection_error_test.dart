import 'package:finote/features/legacy_import/domain/legacy_detection_error.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LegacyDetectionError.toUserMessage', () {
    test('setiap variant menghasilkan pesan non-kosong', () {
      final errors = <LegacyDetectionError>[
        const LegacyDetectionError.notSqlite(),
        LegacyDetectionError.incompatibleSchema(
          missingTables: {'Transaction', 'TransactionSubType'},
        ),
        LegacyDetectionError.unknown(StateError('oops')),
      ];

      for (final error in errors) {
        final msg = error.toUserMessage();
        expect(
          msg,
          isNotEmpty,
          reason: '${error.runtimeType}.toUserMessage() harus non-kosong',
        );
        expect(
          msg,
          isNot(startsWith('Exception')),
          reason: 'Pesan harus ramah pengguna, bukan nama exception',
        );
      }
    });

    test('notSqlite menyebutkan SQLite atau file', () {
      const error = LegacyDetectionError.notSqlite();
      final msg = error.toUserMessage();
      expect(
        msg,
        anyOf(contains('SQLite'), contains('file'), contains('database')),
      );
    });

    test('incompatibleSchema menyertakan nama tabel yang hilang', () {
      final error = LegacyDetectionError.incompatibleSchema(
        missingTables: {'Transaction', 'TransactionSubType'},
      );
      final msg = error.toUserMessage();
      expect(msg, contains('Transaction'));
      expect(msg, contains('TransactionSubType'));
    });

    test('incompatibleSchema dengan satu tabel hilang', () {
      final error = LegacyDetectionError.incompatibleSchema(
        missingTables: {'TransactionSubType'},
      );
      final msg = error.toUserMessage();
      expect(msg, contains('TransactionSubType'));
      expect(msg, isNotEmpty);
    });

    test('unknown menghasilkan pesan generik yang ramah', () {
      final error = LegacyDetectionError.unknown(Exception('detail'));
      final msg = error.toUserMessage();
      expect(msg, isNotEmpty);
      expect(msg, isNot(contains('Exception')));
    });
  });
}
