import 'package:drift/drift.dart';

import '../../../features/accounts/domain/account_type.dart';
import '../../utils/uuid_generator.dart';

class AccountTypeConverter extends TypeConverter<AccountType, String> {
  const AccountTypeConverter();

  @override
  AccountType fromSql(String fromDb) => switch (fromDb) {
    'cash' => AccountType.cash,
    'bank' => AccountType.bank,
    'e_wallet' => AccountType.eWallet,
    'savings' => AccountType.savings,
    _ => throw FormatException('Unknown account type: $fromDb'),
  };

  @override
  String toSql(AccountType value) => switch (value) {
    AccountType.cash => 'cash',
    AccountType.bank => 'bank',
    AccountType.eWallet => 'e_wallet',
    AccountType.savings => 'savings',
  };
}

@DataClassName('AccountRecord')
@TableIndex(name: 'accounts_active', columns: {#isActive})
class Accounts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().clientDefault(generateUuid).unique()();
  TextColumn get name => text()();
  TextColumn get type => text()
      .customConstraint(
        "NOT NULL CHECK (type IN ('cash', 'bank', 'e_wallet', 'savings'))",
      )
      .map(const AccountTypeConverter())();
  IntColumn get initialBalance => integer().withDefault(const Constant(0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();
  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();

  @override
  List<String> get customConstraints => ['CHECK (initial_balance >= 0)'];
}
