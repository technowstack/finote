enum AccountType { cash, bank, eWallet, savings }

extension AccountTypeLabels on AccountType {
  String get label => switch (this) {
    AccountType.cash => 'Tunai',
    AccountType.bank => 'Bank',
    AccountType.eWallet => 'E-Wallet',
    AccountType.savings => 'Tabungan',
  };
}
