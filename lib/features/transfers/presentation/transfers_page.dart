import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;

import '../../../core/database/app_database.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../accounts/data/account_repository.dart';
import '../../accounts/domain/account_type.dart';
import '../data/transfer_repository.dart';
import '../domain/transfer_form_data.dart';

class TransfersPage extends ConsumerStatefulWidget {
  const TransfersPage({super.key, this.editTransferId});

  final int? editTransferId;

  @override
  ConsumerState<TransfersPage> createState() => _TransfersPageState();
}

class _TransfersPageState extends ConsumerState<TransfersPage> {
  bool _openedRequestedTransfer = false;

  Future<void> _openForm([TransferListItem? item]) async {
    final allAccounts = await ref.read(accountsProvider.future);
    final activeAccounts = allAccounts.where((account) => account.isActive);
    final accounts = item == null
        ? activeAccounts.toList()
        : [
            for (final account in allAccounts)
              if (account.isActive ||
                  account.id == item.transfer.fromAccountId ||
                  account.id == item.transfer.toAccountId)
                account,
          ];
    if (accounts.length < 2) {
      _showMessage('Buat setidaknya dua akun aktif terlebih dahulu.');
      return;
    }
    if (!mounted) return;

    final data = await showDialog<TransferFormData>(
      context: context,
      builder: (context) =>
          _TransferFormDialog(accounts: accounts, transfer: item?.transfer),
    );
    if (data == null || !mounted) return;

    try {
      final repository = ref.read(transferRepositoryProvider);
      if (item == null) {
        await repository.create(
          fromAccountId: data.fromAccountId,
          toAccountId: data.toAccountId,
          amount: data.amount,
          transferDate: data.transferDate,
          note: data.note,
        );
      } else {
        final updated = await repository.update(
          item.transfer.copyWith(
            fromAccountId: data.fromAccountId,
            toAccountId: data.toAccountId,
            amount: data.amount,
            transferDate: data.transferDate,
            note: Value<String?>(data.note),
          ),
        );
        if (!updated) throw StateError('Transfer is no longer available');
      }
    } catch (_) {
      _showMessage(
        item == null
            ? 'Gagal menyimpan transfer.'
            : 'Gagal memperbarui transfer.',
      );
    }
  }

  Future<void> _delete(TransferListItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus transfer?'),
        content: const Text('Transfer ini tidak akan memengaruhi saldo lagi.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(transferRepositoryProvider).softDelete(item.transfer.id);
    } catch (_) {
      _showMessage('Gagal menghapus transfer.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final transfers = ref.watch(transfersProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transfer Antar Akun'),
        actions: [
          IconButton(
            onPressed: _openForm,
            tooltip: 'Tambah transfer',
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: transfers.when(
        loading: () => const AppLoadingState(),
        error: (_, _) => AppErrorState(
          message: 'Transfer belum dapat dimuat.',
          onRetry: () => ref.invalidate(transfersProvider),
        ),
        data: (items) => items.isEmpty
            ? const AppEmptyState(
                icon: Icons.swap_horiz,
                message: 'Belum ada transfer.',
              )
            : Builder(
                builder: (context) {
                  final editTransferId = widget.editTransferId;
                  if (!_openedRequestedTransfer && editTransferId != null) {
                    _openedRequestedTransfer = true;
                    final matches = items.where(
                      (item) => item.transfer.id == editTransferId,
                    );
                    if (matches.isNotEmpty) {
                      WidgetsBinding.instance.addPostFrameCallback(
                        (_) => _openForm(matches.first),
                      );
                    }
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return Card(
                        child: ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.swap_horiz),
                          ),
                          title: Text(
                            '${item.from.name} → ${item.to.name}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${formatDate(item.transfer.transferDate)}'
                            '${item.transfer.note?.isNotEmpty == true ? ' · ${item.transfer.note}' : ''}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 120,
                                ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerRight,
                                  child: Text(formatIdr(item.transfer.amount)),
                                ),
                              ),
                              PopupMenuButton<_TransferAction>(
                                tooltip: 'Tindakan transfer',
                                onSelected: (action) {
                                  switch (action) {
                                    case _TransferAction.edit:
                                      _openForm(item);
                                    case _TransferAction.delete:
                                      _delete(item);
                                  }
                                },
                                itemBuilder: (context) => const [
                                  PopupMenuItem(
                                    value: _TransferAction.edit,
                                    child: Text('Ubah'),
                                  ),
                                  PopupMenuItem(
                                    value: _TransferAction.delete,
                                    child: Text('Hapus'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openForm,
        tooltip: 'Tambah transfer',
        child: const Icon(Icons.add),
      ),
    );
  }
}

enum _TransferAction { edit, delete }

class _TransferFormDialog extends StatefulWidget {
  const _TransferFormDialog({required this.accounts, this.transfer});

  final List<AccountRecord> accounts;
  final TransferRecord? transfer;

  @override
  State<_TransferFormDialog> createState() => _TransferFormDialogState();
}

class _TransferFormDialogState extends State<_TransferFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount;
  late final TextEditingController _note;
  late int? _fromAccountId;
  late int? _toAccountId;
  late DateTime _date;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final transfer = widget.transfer;
    _amount = TextEditingController(text: transfer?.amount.toString() ?? '');
    _note = TextEditingController(text: transfer?.note ?? '');
    _fromAccountId = transfer?.fromAccountId;
    _toAccountId = transfer?.toAccountId;
    _date = transfer?.transferDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _submit() {
    if (_saving || !_formKey.currentState!.validate()) return;
    final amount = int.tryParse(_amount.text);
    if (amount == null || amount <= 0 || amount > 9223372036854775807) return;
    setState(() => _saving = true);
    Navigator.pop(
      context,
      TransferFormData(
        fromAccountId: _fromAccountId!,
        toAccountId: _toAccountId!,
        amount: amount,
        transferDate: _date,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.transfer == null ? 'Transfer Antar Akun' : 'Ubah Transfer',
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: _fromAccountId,
                decoration: const InputDecoration(labelText: 'Dari'),
                items: [
                  for (final account in widget.accounts)
                    DropdownMenuItem(
                      value: account.id,
                      child: Text('${account.name} · ${account.type.label}'),
                    ),
                ],
                onChanged: (value) => setState(() => _fromAccountId = value),
                validator: (value) => value == null ? 'Pilih akun asal.' : null,
              ),
              DropdownButtonFormField<int>(
                initialValue: _toAccountId,
                decoration: const InputDecoration(labelText: 'Ke'),
                items: [
                  for (final account in widget.accounts)
                    DropdownMenuItem(
                      value: account.id,
                      child: Text('${account.name} · ${account.type.label}'),
                    ),
                ],
                onChanged: (value) => setState(() => _toAccountId = value),
                validator: (value) => value == null
                    ? 'Pilih akun tujuan.'
                    : value == _fromAccountId
                    ? 'Akun asal dan tujuan tidak boleh sama.'
                    : null,
              ),
              TextFormField(
                controller: _amount,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Nominal'),
                validator: (value) {
                  final amount = int.tryParse(value ?? '');
                  return amount == null ||
                          amount <= 0 ||
                          amount > 9223372036854775807
                      ? 'Masukkan nominal transfer yang valid.'
                      : null;
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Tanggal'),
                subtitle: Text(formatDate(_date)),
                trailing: const Icon(Icons.calendar_today_outlined),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (date != null && mounted) setState(() => _date = date);
                },
              ),
              TextFormField(
                controller: _note,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Catatan (opsional)',
                ),
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
          child: Text(_saving ? 'Menyimpan...' : 'Transfer'),
        ),
      ],
    );
  }
}
