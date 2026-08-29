import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../categories/data/category_repository.dart';
import '../data/transaction_repository.dart';
import '../domain/transaction_source.dart';
import '../domain/transaction_type.dart';

class TransactionFormPage extends ConsumerWidget {
  const TransactionFormPage({super.key, this.transactionId});

  final int? transactionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initialization = ref.watch(categoryInitializationProvider);

    return initialization.when(
      loading: () => const _LoadingPage(),
      error: (error, stackTrace) => const _LoadErrorPage(),
      data: (_) {
        final id = transactionId;
        if (id == null) return const _TransactionForm();

        return ref
            .watch(transactionByIdProvider(id))
            .when(
              loading: () => const _LoadingPage(),
              error: (error, stackTrace) => const _LoadErrorPage(),
              data: (transaction) => transaction == null
                  ? const _LoadErrorPage()
                  : _TransactionForm(transaction: transaction),
            );
      },
    );
  }
}

class _TransactionForm extends ConsumerStatefulWidget {
  const _TransactionForm({this.transaction});

  final TransactionRecord? transaction;

  @override
  ConsumerState<_TransactionForm> createState() => _TransactionFormState();
}

class _TransactionFormState extends ConsumerState<_TransactionForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _titleController;
  late final TextEditingController _noteController;
  late TransactionType _type;
  late DateTime _date;
  int? _categoryId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final transaction = widget.transaction;
    _type = transaction?.type ?? TransactionType.expense;
    _date = transaction?.transactionDate ?? DateTime.now();
    _categoryId = transaction?.categoryId;
    _amountController = TextEditingController(
      text: transaction == null ? '' : _formatAmountInput(transaction.amount),
    );
    _titleController = TextEditingController(text: transaction?.title ?? '');
    _noteController = TextEditingController(text: transaction?.note ?? '');
  }

  @override
  void dispose() {
    _amountController.dispose();
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesByTypeProvider(_type));
    final isEditing = widget.transaction != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Ubah transaksi' : 'Tambah transaksi'),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Menyimpan...' : 'Simpan transaksi'),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            SegmentedButton<TransactionType>(
              segments: const [
                ButtonSegment(
                  value: TransactionType.expense,
                  icon: Icon(Icons.arrow_upward),
                  label: Text('Pengeluaran'),
                ),
                ButtonSegment(
                  value: TransactionType.income,
                  icon: Icon(Icons.arrow_downward),
                  label: Text('Pemasukan'),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (selection) {
                setState(() {
                  _type = selection.single;
                  _categoryId = null;
                });
              },
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _amountController,
              autofocus: !isEditing,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              inputFormatters: const [_IdrInputFormatter()],
              style: Theme.of(context).textTheme.headlineMedium,
              decoration: const InputDecoration(
                labelText: 'Nominal',
                prefixText: 'Rp',
                border: OutlineInputBorder(),
              ),
              validator: (value) => _parseAmount(value ?? '') > 0
                  ? null
                  : 'Nominal harus lebih dari Rp0.',
            ),
            const SizedBox(height: 16),
            categories.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, stackTrace) =>
                  const Text('Kategori belum dapat dimuat.'),
              data: (items) {
                final selectedExists = items.any(
                  (category) => category.id == _categoryId,
                );
                return DropdownButtonFormField<int>(
                  initialValue: selectedExists ? _categoryId : null,
                  decoration: const InputDecoration(
                    labelText: 'Kategori',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final category in items)
                      DropdownMenuItem(
                        value: category.id,
                        child: Text(category.name),
                      ),
                  ],
                  onChanged: (value) => setState(() => _categoryId = value),
                  validator: (value) =>
                      value == null ? 'Pilih kategori transaksi.' : null,
                );
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: const Icon(Icons.calendar_today_outlined),
              title: const Text('Tanggal'),
              subtitle: Text(formatDate(_date)),
              trailing: const Icon(Icons.chevron_right),
              onTap: _selectDate,
            ),
            const Divider(),
            ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 4),
              initiallyExpanded:
                  isEditing &&
                  (_titleController.text.isNotEmpty ||
                      _noteController.text.isNotEmpty),
              title: const Text('Judul dan catatan'),
              subtitle: const Text('Opsional'),
              childrenPadding: const EdgeInsets.only(bottom: 8),
              children: [
                TextFormField(
                  controller: _titleController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Judul',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _noteController,
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Catatan',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selected != null) setState(() => _date = selected);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final categoryId = _categoryId;
    if (categoryId == null) return;

    setState(() => _saving = true);
    final repository = ref.read(transactionRepositoryProvider);
    final note = _noteController.text.trim();

    try {
      final existing = widget.transaction;
      if (existing == null) {
        await repository.create(
          type: _type,
          categoryId: categoryId,
          amount: _parseAmount(_amountController.text),
          title: _titleController.text,
          note: note.isEmpty ? null : note,
          transactionDate: _date,
          source: TransactionSource.manual,
        );
      } else {
        await repository.update(
          existing.copyWith(
            type: _type,
            categoryId: categoryId,
            amount: _parseAmount(_amountController.text),
            title: _titleController.text.trim(),
            note: Value(note.isEmpty ? null : note),
            transactionDate: _date,
          ),
        );
        ref.invalidate(transactionByIdProvider(existing.id));
      }

      if (!mounted) return;
      context.canPop() ? context.pop() : context.go('/transactions');
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaksi gagal disimpan. Coba lagi.')),
        );
      }
    }
  }
}

class _IdrInputFormatter extends TextInputFormatter {
  const _IdrInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return const TextEditingValue();
    final amount = int.tryParse(digits);
    if (amount == null) return oldValue;
    final text = _formatAmountInput(amount);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

int _parseAmount(String value) =>
    int.tryParse(value.replaceAll(RegExp(r'\D'), '')) ?? 0;

String _formatAmountInput(int amount) =>
    formatIdr(amount).replaceFirst('Rp', '');

class _LoadingPage extends StatelessWidget {
  const _LoadingPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _LoadErrorPage extends StatelessWidget {
  const _LoadErrorPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transaksi')),
      body: const Center(child: Text('Transaksi belum dapat dimuat.')),
    );
  }
}
