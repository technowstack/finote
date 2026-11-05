import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/finance/net_worth.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/category_style.dart';
import '../../../core/theme/finote_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../data/account_repository.dart';
import '../domain/account_type.dart';
import '../domain/account_summary.dart';

class AccountsPage extends ConsumerStatefulWidget {
  const AccountsPage({super.key});

  @override
  ConsumerState<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends ConsumerState<AccountsPage> {
  Future<void> _openForm([AccountRecord? account]) async {
    final data = await showDialog<_AccountFormData>(
      context: context,
      builder: (context) => _AccountFormDialog(account: account),
    );
    if (data == null || !mounted) return;

    try {
      final repository = ref.read(accountRepositoryProvider);
      if (account == null) {
        await repository.create(
          name: data.name,
          type: data.type,
          initialBalance: data.initialBalance,
        );
      } else {
        final updated = await repository.update(
          id: account.id,
          name: data.name,
          type: data.type,
          initialBalance: data.initialBalance,
        );
        if (!updated) throw StateError('Account is no longer available');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              account == null
                  ? 'Gagal menyimpan akun.'
                  : 'Gagal memperbarui akun.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _setActive(AccountRecord account, bool active) async {
    try {
      final repository = ref.read(accountRepositoryProvider);
      if (active) {
        await repository.reactivate(account.id);
      } else {
        await repository.archive(account.id);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Akun tidak dapat dinonaktifkan.')),
        );
      }
    }
  }

  Future<void> _deleteAccount(AccountRecord account) async {
    final repository = ref.read(accountRepositoryProvider);
    try {
      final usage = await repository.getAccountUsage(account.id);
      if (!mounted || usage == null || usage.isDefault) return;

      if (usage.hasFinancialHistory) {
        final archive = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Akun tidak dapat dihapus'),
            content: const Text(
              'Akun ini memiliki riwayat transaksi atau transfer. '
              'Nonaktifkan akun agar riwayat keuangan tetap aman.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Tutup'),
              ),
              if (account.isActive)
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Nonaktifkan'),
                ),
            ],
          ),
        );
        if (archive == true && mounted) await _setActive(account, false);
        return;
      }

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Hapus akun?'),
          content: Text(
            'Akun “${account.name}” akan dihapus permanen. '
            'Tindakan ini tidak dapat dibatalkan.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Hapus Permanen'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;

      final deleted = await repository.deleteUnusedAccount(account.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            deleted
                ? 'Akun berhasil dihapus.'
                : 'Akun tidak dapat dihapus karena sudah memiliki riwayat.',
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Akun tidak dapat dihapus.')),
        );
      }
    }
  }

  Widget _accountCard(AccountSummary item) => _AccountCard(
    summary: item,
    onEdit: () => _openForm(item.account),
    onSetActive: (active) => _setActive(item.account, active),
    onDelete: () => _deleteAccount(item.account),
  );

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountSummariesProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Akun & Dompet',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        actions: [
          IconButton.filledTonal(
            onPressed: () => context.push('/transfers'),
            tooltip: 'Transfer antar akun',
            icon: const Icon(Icons.swap_horiz),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openForm,
        tooltip: 'Tambah akun',
        child: const Icon(Icons.add),
      ),
      body: accounts.when(
        loading: () => const AppLoadingState(),
        error: (_, _) => AppErrorState(
          message: 'Akun belum dapat dimuat.',
          onRetry: () => ref.invalidate(accountSummariesProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const AppEmptyState(
              icon: Icons.account_balance_wallet_outlined,
              message: 'Belum ada akun.',
            );
          }
          final active = items.where((item) => item.account.isActive);
          final archived = items.where((item) => !item.account.isActive);
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              AppSpacing.sm,
              AppSpacing.screenH,
              96,
            ),
            children: [
              _AccountsTotalCard(
                summaries: items,
                netWorth: ref.watch(netWorthProvider),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Akun aktif',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final item in active) ...[
                _accountCard(item),
                const SizedBox(height: AppSpacing.sm),
              ],
              if (archived.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Diarsipkan',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Akun dengan riwayat hanya bisa diarsipkan, tidak dihapus.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                for (final item in archived) ...[
                  _accountCard(item),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Total balance shown above the list. It reads the same cash figure as the
/// Beranda "Kas & Dompet" tile (netWorthProvider), so the two always agree.
/// That figure sums every account, archived ones included, so the label says
/// so instead of claiming "aktif" only.
class _AccountsTotalCard extends StatelessWidget {
  const _AccountsTotalCard({required this.summaries, required this.netWorth});

  final List<AccountSummary> summaries;
  final AsyncValue<NetWorthSnapshot> netWorth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = summaries.where((item) => item.account.isActive).length;
    final archived = summaries.length - active;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total saldo semua akun', style: theme.textTheme.bodySmall),
            const SizedBox(height: AppSpacing.xs),
            netWorth.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => Text(
                'Total saldo belum dapat dimuat.',
                style: theme.textTheme.bodySmall,
              ),
              data: (snapshot) => CurrencyText(
                amount: snapshot.cashValue,
                maskable: true,
                alignment: Alignment.centerLeft,
                style: AppTypography.amountXl.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              archived == 0
                  ? '$active akun aktif'
                  : '$active akun aktif · $archived diarsipkan',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.summary,
    required this.onEdit,
    required this.onSetActive,
    required this.onDelete,
  });

  final AccountSummary summary;
  final VoidCallback onEdit;
  final ValueChanged<bool> onSetActive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final account = summary.account;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final finote = theme.finote;
    final (tileColor, iconColor, icon) = _accountTile(account, colors, finote);
    final balance = CurrencyText(
      amount: summary.balance,
      maskable: true,
      alignment: Alignment.centerLeft,
      style: AppTypography.amountMd.copyWith(color: colors.onSurface),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.xs,
          AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                // Narrow cards (320dp with large text) put the balance under the
                // name instead of squeezing it into a trailing slot.
                final wide = constraints.maxWidth >= 340;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: tileColor,
                            borderRadius: AppRadius.mdAll,
                          ),
                          child: SizedBox.square(
                            dimension: 44,
                            child: Icon(icon, color: iconColor),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      account.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.labelLg.copyWith(
                                        color: colors.onSurface,
                                      ),
                                    ),
                                  ),
                                  if (account.isDefault) ...[
                                    const SizedBox(width: AppSpacing.xs),
                                    DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: colors.primaryContainer,
                                        borderRadius: AppRadius.smAll,
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: AppSpacing.sm,
                                          vertical: AppSpacing.xs,
                                        ),
                                        child: Text(
                                          'Default',
                                          style: AppTypography.captionSemibold
                                              .copyWith(
                                                color:
                                                    colors.onPrimaryContainer,
                                              ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              Text(
                                '${_accountTypeText(account.type)}'
                                '${account.isActive ? '' : ' · Diarsipkan'}',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        if (wide) ...[
                          const SizedBox(width: AppSpacing.sm),
                          Flexible(child: balance),
                        ],
                        PopupMenuButton<_AccountAction>(
                          tooltip: 'Tindakan akun',
                          onSelected: (action) async {
                            switch (action) {
                              case _AccountAction.edit:
                                onEdit();
                              case _AccountAction.archive:
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Nonaktifkan akun ini?'),
                                    content: const Text(
                                      'Akun tidak aktif tidak akan ditawarkan untuk transaksi baru.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text('Batal'),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: const Text('Nonaktifkan'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed == true) onSetActive(false);
                              case _AccountAction.reactivate:
                                onSetActive(true);
                              case _AccountAction.delete:
                                onDelete();
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: _AccountAction.edit,
                              child: Text('Ubah'),
                            ),
                            if (!account.isDefault)
                              PopupMenuItem(
                                value: account.isActive
                                    ? _AccountAction.archive
                                    : _AccountAction.reactivate,
                                child: Text(
                                  account.isActive ? 'Nonaktifkan' : 'Aktifkan',
                                ),
                              ),
                            if (!account.isDefault)
                              const PopupMenuItem(
                                value: _AccountAction.delete,
                                child: Text('Hapus Permanen'),
                              ),
                          ],
                        ),
                      ],
                    ),
                    if (!wide)
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 60,
                          top: AppSpacing.xs,
                        ),
                        child: balance,
                      ),
                  ],
                );
              },
            ),
            if (account.isActive) ...[
              const SizedBox(height: AppSpacing.md),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: finote.surfaceAlt,
                  borderRadius: AppRadius.mdAll,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      Expanded(
                        child: _FlowAmount(
                          label: 'Total masuk',
                          amount: summary.totalIncome,
                          color: finote.income,
                        ),
                      ),
                      Expanded(
                        child: _FlowAmount(
                          label: 'Total keluar',
                          amount: summary.totalExpense,
                          color: finote.expense,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FlowAmount extends StatelessWidget {
  const _FlowAmount({
    required this.label,
    required this.amount,
    required this.color,
  });

  final String label;
  final int amount;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.bodySmall),
      CurrencyText(
        amount: amount,
        maskable: true,
        alignment: Alignment.centerLeft,
        style: AppTypography.amountSm.copyWith(color: color),
      ),
    ],
  );
}

/// Display-only labels for the account card. [AccountType.label] stays the
/// source for exports, charts and the transfer dialog, so it is not changed.
String _accountTypeText(AccountType type) => switch (type) {
  AccountType.cash => 'Uang tunai',
  AccountType.bank => 'Rekening bank',
  AccountType.eWallet => 'E-Wallet',
  AccountType.savings => 'Tabungan',
};

(Color, Color, IconData) _accountTile(
  AccountRecord account,
  ColorScheme colors,
  FinoteColors finote,
) {
  if (!account.isActive) {
    return (
      colors.surfaceContainerHighest,
      colors.onSurfaceVariant,
      Icons.archive_outlined,
    );
  }
  return switch (account.type) {
    AccountType.cash => (
      finote.categories[FinoteCategory.salary]!.background,
      finote.categories[FinoteCategory.salary]!.foreground,
      Icons.account_balance_wallet_outlined,
    ),
    AccountType.bank => (
      colors.primaryContainer,
      colors.onPrimaryContainer,
      Icons.account_balance_outlined,
    ),
    AccountType.eWallet => (
      colors.tertiaryContainer,
      colors.onTertiaryContainer,
      Icons.smartphone_outlined,
    ),
    AccountType.savings => (
      colors.secondaryContainer,
      colors.onSecondaryContainer,
      Icons.savings_outlined,
    ),
  };
}

enum _AccountAction { edit, archive, reactivate, delete }

const _maxAccountBalance = 9223372036854775807;

class _AccountFormData {
  const _AccountFormData(this.name, this.type, this.initialBalance);

  final String name;
  final AccountType type;
  final int initialBalance;
}

class _AccountFormDialog extends StatefulWidget {
  const _AccountFormDialog({this.account});

  final AccountRecord? account;

  @override
  State<_AccountFormDialog> createState() => _AccountFormDialogState();
}

class _AccountFormDialogState extends State<_AccountFormDialog> {
  late final TextEditingController _name;
  late final TextEditingController _balance;
  late AccountType _type;
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final account = widget.account;
    _name = TextEditingController(text: account?.name);
    _balance = TextEditingController(
      text: _formatAccountBalance(account?.initialBalance ?? 0),
    );
    _type = account?.type ?? AccountType.cash;
  }

  @override
  void dispose() {
    _name.dispose();
    _balance.dispose();
    super.dispose();
  }

  void _submit() {
    if (_saving || !_formKey.currentState!.validate()) return;
    final balance = _parseAccountBalance(_balance.text);
    if (balance == null) return;
    setState(() => _saving = true);
    Navigator.pop(context, _AccountFormData(_name.text, _type, balance));
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.account != null;
    return AlertDialog(
      title: Text(editing ? 'Ubah akun' : 'Tambah akun'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                autofocus: true,
                maxLength: 100,
                decoration: const InputDecoration(labelText: 'Nama'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Nama akun wajib diisi.'
                    : null,
              ),
              DropdownButtonFormField<AccountType>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Jenis'),
                items: [
                  for (final type in AccountType.values)
                    DropdownMenuItem(value: type, child: Text(type.label)),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _type = value);
                },
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _balance,
                keyboardType: TextInputType.number,
                inputFormatters: const [_ThousandsSeparatorInputFormatter()],
                decoration: const InputDecoration(labelText: 'Saldo Awal'),
                validator: (value) => _parseAccountBalance(value) == null
                    ? 'Masukkan nominal yang valid.'
                    : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: Text(editing ? 'Simpan' : 'Tambah'),
        ),
      ],
    );
  }
}

int? _parseAccountBalance(String? value) {
  final balance = int.tryParse((value ?? '').replaceAll('.', ''));
  return balance != null && balance <= _maxAccountBalance ? balance : null;
}

String _formatAccountBalance(int balance) =>
    formatIdr(balance).replaceFirst('Rp', '');

class _ThousandsSeparatorInputFormatter extends TextInputFormatter {
  const _ThousandsSeparatorInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }
    final balance = int.tryParse(digits);
    if (balance == null || balance > _maxAccountBalance) return oldValue;

    final formatted = _formatAccountBalance(balance);
    final cursor = newValue.selection.baseOffset.clamp(0, newValue.text.length);
    final digitsBeforeCursor = newValue.text
        .substring(0, cursor)
        .replaceAll(RegExp(r'\D'), '')
        .length;
    var formattedCursor = 0;
    var seenDigits = 0;
    while (formattedCursor < formatted.length &&
        seenDigits < digitsBeforeCursor) {
      if (RegExp(r'\d').hasMatch(formatted[formattedCursor])) seenDigits++;
      formattedCursor++;
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formattedCursor),
    );
  }
}
