import 'package:drift/native.dart';
import 'package:finote/core/database/app_database.dart';
import 'package:finote/features/accounts/data/account_repository.dart';
import 'package:finote/features/accounts/domain/account_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late AccountRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = AccountRepository(database);
  });

  tearDown(() => database.close());

  test('default account is created once and remains stable', () async {
    final first = await database.select(database.accounts).getSingle();
    await repository.initializeDefaults();
    await repository.initializeDefaults();
    final second = await database.select(database.accounts).getSingle();

    expect(first.id, second.id);
    expect(first.uuid, second.uuid);
    expect(first.isDefault, isTrue);
    expect(first.type, AccountType.cash);
  });

  test('create and update trim names and preserve UUID', () async {
    final account = await repository.create(
      name: '  BCA Utama  ',
      type: AccountType.bank,
      initialBalance: 250000,
    );
    expect(account.name, 'BCA Utama');
    expect(account.initialBalance, 250000);
    expect(account.uuid, matches(_uuidPattern));

    expect(
      await repository.update(
        id: account.id,
        name: ' BCA Harian ',
        type: AccountType.savings,
        initialBalance: 0,
      ),
      isTrue,
    );
    final updated = await repository.findById(account.id);
    expect(updated?.name, 'BCA Harian');
    expect(updated?.type, AccountType.savings);
    expect(updated?.uuid, account.uuid);
  });

  test('accepts zero and large integer initial balances', () async {
    final zero = await repository.create(
      name: 'Tunai Cadangan',
      type: AccountType.cash,
    );
    final large = await repository.create(
      name: 'Tabungan',
      type: AccountType.savings,
      initialBalance: 9000000000000,
    );

    expect(zero.initialBalance, 0);
    expect(large.initialBalance, 9000000000000);
  });

  test('active account list reacts to archive and reactivation', () async {
    final account = await repository.create(
      name: 'GoPay',
      type: AccountType.eWallet,
    );
    expect(
      (await repository.watchActive().first).map((item) => item.name),
      contains('GoPay'),
    );

    expect(await repository.archive(account.id), isTrue);
    expect(
      (await repository.watchActive().first).map((item) => item.name),
      isNot(contains('GoPay')),
    );
    expect(await repository.reactivate(account.id), isTrue);
    expect(
      (await repository.watchActive().first).map((item) => item.name),
      contains('GoPay'),
    );
  });

  test('cannot archive the only active account', () async {
    final defaultAccount = await database.select(database.accounts).getSingle();
    await expectLater(repository.archive(defaultAccount.id), throwsStateError);
    expect((await repository.findById(defaultAccount.id))?.isActive, isTrue);
  });

  test('rejects empty, overly long, and negative initial balance', () async {
    await expectLater(
      repository.create(name: '  ', type: AccountType.cash),
      throwsArgumentError,
    );
    await expectLater(
      repository.create(name: 'a' * 101, type: AccountType.cash),
      throwsArgumentError,
    );
    await expectLater(
      repository.create(
        name: 'Utang',
        type: AccountType.cash,
        initialBalance: -1,
      ),
      throwsArgumentError,
    );
  });
}

final _uuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);
