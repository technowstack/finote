import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class PinStore {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> delete();
}

class SecurePinStore implements PinStore {
  const SecurePinStore();

  static const _storage = FlutterSecureStorage();
  static const _key = 'finote_pin_verifier';

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String value) => _storage.write(key: _key, value: value);

  @override
  Future<void> delete() => _storage.delete(key: _key);
}

class PinRepository {
  PinRepository(this._store, {int iterations = 210000})
    : _algorithm = Pbkdf2(
        macAlgorithm: Hmac.sha256(),
        iterations: iterations,
        bits: 256,
      );

  final PinStore _store;
  final Pbkdf2 _algorithm;

  Future<PinStatus> status() async {
    final record = await _readRecord();
    return PinStatus(enabled: record != null, length: record?.length ?? 6);
  }

  Future<void> setPin(String pin) async {
    _validatePin(pin);
    final salt = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    final hash = await _derive(pin, salt);
    await _store.write(
      jsonEncode({
        'version': 1,
        'length': pin.length,
        'salt': base64Encode(salt),
        'hash': base64Encode(hash),
        'failedAttempts': 0,
      }),
    );
  }

  Future<PinVerification> verify(String pin) async {
    final record = await _readRecord();
    if (record == null) return const PinVerification.success();

    final now = DateTime.now().toUtc();
    if (record.lockedUntil?.isAfter(now) ?? false) {
      return PinVerification.locked(record.lockedUntil!.difference(now));
    }

    final candidate = await _derive(pin, record.salt);
    if (_constantTimeEquals(candidate, record.hash)) {
      if (record.failedAttempts != 0 || record.lockedUntil != null) {
        await _writeRecord(record.copyWith(failedAttempts: 0, clearLock: true));
      }
      return const PinVerification.success();
    }

    final attempts = record.failedAttempts + 1;
    if (attempts >= 5) {
      const delay = Duration(seconds: 30);
      await _writeRecord(
        record.copyWith(failedAttempts: 0, lockedUntil: now.add(delay)),
      );
      return const PinVerification.locked(delay);
    }
    await _writeRecord(
      record.copyWith(failedAttempts: attempts, clearLock: true),
    );
    return const PinVerification.invalid();
  }

  Future<bool> disable(String currentPin) async {
    final result = await verify(currentPin);
    if (!result.isSuccess) return false;
    await _store.delete();
    return true;
  }

  Future<List<int>> _derive(String pin, List<int> salt) async {
    final key = await _algorithm.deriveKey(
      secretKey: SecretKey(utf8.encode(pin)),
      nonce: salt,
    );
    return key.extractBytes();
  }

  Future<_PinRecord?> _readRecord() async {
    final value = await _store.read();
    if (value == null) return null;
    try {
      final json = jsonDecode(value) as Map<String, dynamic>;
      if (json['version'] != 1) {
        throw const FormatException('Unsupported PIN');
      }
      final length = json['length'] as int;
      if (length != 4 && length != 6) {
        throw const FormatException('Invalid PIN');
      }
      return _PinRecord(
        length: length,
        salt: base64Decode(json['salt'] as String),
        hash: base64Decode(json['hash'] as String),
        failedAttempts: json['failedAttempts'] as int? ?? 0,
        lockedUntil: json['lockedUntil'] == null
            ? null
            : DateTime.parse(json['lockedUntil'] as String).toUtc(),
      );
    } catch (_) {
      throw const FormatException('Penyimpanan PIN tidak valid.');
    }
  }

  Future<void> _writeRecord(_PinRecord record) => _store.write(
    jsonEncode({
      'version': 1,
      'length': record.length,
      'salt': base64Encode(record.salt),
      'hash': base64Encode(record.hash),
      'failedAttempts': record.failedAttempts,
      if (record.lockedUntil != null)
        'lockedUntil': record.lockedUntil!.toIso8601String(),
    }),
  );

  void _validatePin(String pin) {
    if (!RegExp(r'^(?:\d{4}|\d{6})$').hasMatch(pin)) {
      throw const FormatException('PIN harus terdiri dari 4 atau 6 digit.');
    }
  }
}

class PinStatus {
  const PinStatus({required this.enabled, required this.length});

  final bool enabled;
  final int length;
}

class PinVerification {
  const PinVerification._(this.isSuccess, this.lockDuration);
  const PinVerification.success() : this._(true, null);
  const PinVerification.invalid() : this._(false, null);
  const PinVerification.locked(Duration duration) : this._(false, duration);

  final bool isSuccess;
  final Duration? lockDuration;
}

class _PinRecord {
  const _PinRecord({
    required this.length,
    required this.salt,
    required this.hash,
    required this.failedAttempts,
    required this.lockedUntil,
  });

  final int length;
  final List<int> salt;
  final List<int> hash;
  final int failedAttempts;
  final DateTime? lockedUntil;

  _PinRecord copyWith({
    int? failedAttempts,
    DateTime? lockedUntil,
    bool clearLock = false,
  }) => _PinRecord(
    length: length,
    salt: salt,
    hash: hash,
    failedAttempts: failedAttempts ?? this.failedAttempts,
    lockedUntil: clearLock ? null : lockedUntil ?? this.lockedUntil,
  );
}

bool _constantTimeEquals(List<int> first, List<int> second) {
  if (first.length != second.length) return false;
  var difference = 0;
  for (var index = 0; index < first.length; index++) {
    difference |= first[index] ^ second[index];
  }
  return difference == 0;
}

final pinStoreProvider = Provider<PinStore>((ref) => const SecurePinStore());

final pinRepositoryProvider = Provider<PinRepository>(
  (ref) => PinRepository(ref.watch(pinStoreProvider)),
);

final pinConfigurationRevisionProvider = StateProvider<int>((ref) => 0);
