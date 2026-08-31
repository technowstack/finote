import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_spacing.dart';
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

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountSummariesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Akun & Dompet'),
        actions: [
          IconButton(
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
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              AppSpacing.sm,
              AppSpacing.screenH,
              96,
            ),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) => _AccountCard(
              summary: items[index],
              onEdit: () => _openForm(items[index].account),
              onSetActive: (active) => _setActive(items[index].account, active),
            ),
          );
        },
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.summary,
    required this.onEdit,
    required this.onSetActive,
  });

  final AccountSummary summary;
  final VoidCallback onEdit;
  final ValueChanged<bool> onSetActive;

  @override
  Widget build(BuildContext context) {
    final account = summary.account;
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: account.isActive
              ? colors.primaryContainer
              : colors.surfaceContainerHighest,
          child: Icon(
            account.isActive
                ? Icons.account_balance_wallet_outlined
                : Icons.archive_outlined,
          ),
        ),
        title: Text(account.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${account.type.label}${account.isActive ? '' : ' • Tidak aktif'}',
            ),
            Text('Saldo ${formatIdr(summary.balance)}'),
            Text(
              'Masuk ${formatIdr(summary.totalIncome)} · '
              'Keluar ${formatIdr(summary.totalExpense)}',
            ),
          ],
        ),
        trailing: PopupMenuButton<_AccountAction>(
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
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Batal'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Nonaktifkan'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) onSetActive(false);
              case _AccountAction.reactivate:
                onSetActive(true);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: _AccountAction.edit,
              child: Text('Ubah'),
            ),
            PopupMenuItem(
              value: account.isActive
                  ? _AccountAction.archive
                  : _AccountAction.reactivate,
              child: Text(account.isActive ? 'Nonaktifkan' : 'Aktifkan'),
            ),
          ],
        ),
      ),
    );
  }
}

enum _AccountAction { edit, archive, reactivate }

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
      text: account?.initialBalance.toString() ?? '0',
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
    setState(() => _saving = true);
    Navigator.pop(
      context,
      _AccountFormData(_name.text, _type, int.parse(_balance.text)),
    );
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
              TextFormField(
                controller: _balance,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Saldo Awal'),
                validator: (value) => int.tryParse(value ?? '') == null
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
