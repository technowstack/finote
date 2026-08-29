import 'package:finote/features/app_lock/data/pin_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stores a salted verifier instead of the PIN', () async {
    final store = _MemoryPinStore();
    final repository = PinRepository(store, iterations: 2);

    await repository.setPin('123456');

    expect(store.value, isNot(contains('123456')));
    expect((await repository.status()).enabled, isTrue);
    expect((await repository.verify('123456')).isSuccess, isTrue);
    expect((await repository.verify('654321')).isSuccess, isFalse);
  });

  test('accepts only 4 or 6 digits and can disable with current PIN', () async {
    final store = _MemoryPinStore();
    final repository = PinRepository(store, iterations: 2);

    await expectLater(repository.setPin('12345'), throwsFormatException);
    await expectLater(repository.setPin('abcd'), throwsFormatException);
    await repository.setPin('1234');

    expect(await repository.disable('0000'), isFalse);
    expect(await repository.disable('1234'), isTrue);
    expect((await repository.status()).enabled, isFalse);
  });

  test('temporarily locks verification after five failures', () async {
    final repository = PinRepository(_MemoryPinStore(), iterations: 2);
    await repository.setPin('1234');

    for (var attempt = 0; attempt < 4; attempt++) {
      expect((await repository.verify('0000')).lockDuration, isNull);
    }
    final result = await repository.verify('0000');

    expect(result.isSuccess, isFalse);
    expect(result.lockDuration, const Duration(seconds: 30));
    expect((await repository.verify('1234')).lockDuration, isNotNull);
  });
}

class _MemoryPinStore implements PinStore {
  String? value;

  @override
  Future<void> delete() async => value = null;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async => this.value = value;
}
