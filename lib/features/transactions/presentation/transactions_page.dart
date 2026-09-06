import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/main_scaffold.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/financial_date_range.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../accounts/data/account_repository.dart';
import '../../categories/data/category_repository.dart';
import '../../transfers/data/transfer_repository.dart';
import '../data/financial_activity_repository.dart';
import '../data/transaction_repository.dart';
import '../domain/financial_activity.dart';
import '../domain/transaction_type.dart';

class TransactionsPage extends ConsumerStatefulWidget {
  const TransactionsPage({super.key});

  @override
  ConsumerState<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends ConsumerState<TransactionsPage> {
  final _searchController = TextEditingController();
  FinancialActivityType? _type;
  _DateFilter _dateFilter = _DateFilter.all;
  DateTimeRange? _customRange;
  int? _accountId;
  int? _categoryId;
  String _search = '';
  Timer? _searchTimer;
  bool _searchOpen = false;

  @override
  void dispose() {
    _searchTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final range = _dateRange(_dateFilter, _customRange, DateTime.now());
    final accounts = ref.watch(accountsProvider).valueOrNull ?? const [];
    final categories = ref.watch(categoriesProvider).valueOrNull ?? const [];
    final accountId = accounts.any((item) => item.id == _accountId)
        ? _accountId
        : null;
    final categoryId = categories.any((item) => item.id == _categoryId)
        ? _categoryId
        : null;
    final filter = FinancialActivityQuery(
      type: _type,
      startDate: range.start,
      endDate: range.end,
      search: _search,
      accountId: accountId,
      categoryId: categoryId,
    );
    final activities = ref.watch(financialActivityProvider(filter));

    return Scaffold(
      appBar: AppBar(
        title: _searchOpen ? null : const Text('Transaksi'),
        flexibleSpace: _searchOpen
            ? SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    AppSpacing.sm,
                  ),
                  child: SearchBar(
                    controller: _searchController,
                    hintText: 'Cari transaksi, transfer, atau akun',
                    autoFocus: true,
                    leading: const Icon(Icons.search, size: 20),
                    trailing: [
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: _closeSearch,
                        tooltip: 'Tutup pencarian',
                      ),
                    ],
                    onChanged: _scheduleSearch,
                    textInputAction: TextInputAction.search,
                    onSubmitted: _applySearch,
                    onTapOutside: (_) =>
                        FocusManager.instance.primaryFocus?.unfocus(),
                  ),
                ),
              )
            : null,
        actions: [
          if (!_searchOpen)
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: 'Cari transaksi',
              onPressed: () => setState(() => _searchOpen = true),
            ),
        ],
      ),
      body: Column(
        children: [
          // ----- Single filter row -----
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              AppSpacing.xs,
              AppSpacing.screenH,
              AppSpacing.xs,
            ),
            child: Row(
              spacing: AppSpacing.sm,
              children: [
                // Type filters
                _filterChip(
                  'Semua',
                  selected: _type == null,
                  onSelected: () => setState(() => _type = null),
                ),
                _filterChip(
                  'Pemasukan',
                  selected: _type == FinancialActivityType.income,
                  onSelected: () =>
                      setState(() => _type = FinancialActivityType.income),
                ),
                _filterChip(
                  'Pengeluaran',
                  selected: _type == FinancialActivityType.expense,
                  onSelected: () =>
                      setState(() => _type = FinancialActivityType.expense),
                ),
                _filterChip(
                  'Transfer',
                  selected: _type == FinancialActivityType.transfer,
                  onSelected: () =>
                      setState(() => _type = FinancialActivityType.transfer),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _openAdvancedFilters(accounts, categories),
                  icon: const Icon(Icons.filter_alt_outlined, size: 18),
                  label: Text(
                    'Filter${_filterCount(accountId, categoryId) > 0 ? ' • ${_filterCount(accountId, categoryId)}' : ''}',
                  ),
                ),
              ],
            ),
          ),

          if (_dateFilter != _DateFilter.all ||
              accountId != null ||
              categoryId != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                0,
                AppSpacing.screenH,
                AppSpacing.sm,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    if (_dateFilter != _DateFilter.all)
                      InputChip(
                        label: Text(_periodLabel(_dateFilter, _customRange)),
                        onDeleted: () => setState(() {
                          _dateFilter = _DateFilter.all;
                          _customRange = null;
                        }),
                      ),
                    if (accountId != null)
                      InputChip(
                        label: Text(
                          accounts
                              .firstWhere((item) => item.id == accountId)
                              .name,
                        ),
                        onDeleted: () => setState(() => _accountId = null),
                      ),
                    if (categoryId != null)
                      InputChip(
                        label: Text(
                          categories
                              .firstWhere((item) => item.id == categoryId)
                              .name,
                        ),
                        onDeleted: () => setState(() => _categoryId = null),
                      ),
                  ],
                ),
              ),
            ),

          // ----- Period summary strip -----
          activities.whenOrNull(
                data: (items) {
                  if (items.isEmpty) return null;
                  var income = 0;
                  var expense = 0;
                  var hasTransactions = false;
                  for (final item in items) {
                    if (item.type == FinancialActivityType.income) {
                      hasTransactions = true;
                      income += item.amount;
                    } else if (item.type == FinancialActivityType.expense) {
                      hasTransactions = true;
                      expense += item.amount;
                    }
                  }
                  if (!hasTransactions) return null;
                  return _PeriodSummaryStrip(income: income, expense: expense);
                },
              ) ??
              const SizedBox.shrink(),

          // ----- Transaction list -----
          Expanded(
            child: activities.when(
              loading: () => const AppLoadingState(),
              error: (error, stackTrace) => AppErrorState(
                message: 'Aktivitas belum dapat dimuat.',
                onRetry: () =>
                    ref.invalidate(financialActivityProvider(filter)),
              ),
              data: (items) => items.isEmpty
                  ? _FilteredEmptyState(
                      filtered: _hasAnyFilter(
                        _type,
                        _dateFilter,
                        accountId,
                        categoryId,
                        _search,
                      ),
                      onReset: _resetFilters,
                    )
                  : _GroupedActivityList(items: items),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(
    String label, {
    required bool selected,
    required VoidCallback onSelected,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        FocusManager.instance.primaryFocus?.unfocus();
        onSelected();
      },
    );
  }

  void _scheduleSearch(String value) {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _search = value.trim());
    });
  }

  void _closeSearch() {
    _searchTimer?.cancel();
    _searchController.clear();
    setState(() {
      _search = '';
      _searchOpen = false;
    });
  }

  void _applySearch(String value) {
    _searchTimer?.cancel();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _search = value.trim());
  }

  Future<void> _openAdvancedFilters(
    List<AccountRecord> accounts,
    List<CategoryRecord> categories,
  ) async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (ref.read(shellModalOpenProvider)) return;
    ref.read(shellModalOpenProvider.notifier).state = true;

    _AdvancedFilterResult? result;
    try {
      result = await showModalBottomSheet<_AdvancedFilterResult>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        builder: (_) => _AdvancedFilterSheet(
          dateFilter: _dateFilter,
          customRange: _customRange,
          accountId: _accountId,
          categoryId: _categoryId,
          accounts: accounts,
          categories: categories,
        ),
      );
    } finally {
      if (mounted) {
        ref.read(shellModalOpenProvider.notifier).state = false;
      }
    }
    final applied = result;
    if (!mounted || applied == null) return;
    setState(() {
      _dateFilter = applied.dateFilter;
      _customRange = applied.customRange;
      _accountId = applied.accountId;
      _categoryId = applied.categoryId;
    });
  }

  void _resetFilters() => setState(() {
    _type = null;
    _dateFilter = _DateFilter.all;
    _customRange = null;
    _accountId = null;
    _categoryId = null;
  });

  int _filterCount(int? accountId, int? categoryId) =>
      (_dateFilter == _DateFilter.all ? 0 : 1) +
      (accountId == null ? 0 : 1) +
      (categoryId == null ? 0 : 1);
}

class _FilteredEmptyState extends StatelessWidget {
  const _FilteredEmptyState({required this.filtered, required this.onReset});

  final bool filtered;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    if (!filtered) {
      return const AppEmptyState(
        icon: Icons.receipt_long_outlined,
        message: 'Belum ada transaksi.',
      );
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.filter_alt_off_outlined, size: 44),
          const SizedBox(height: AppSpacing.md),
          const Text('Tidak ada transaksi yang cocok dengan filter.'),
          const SizedBox(height: AppSpacing.sm),
          FilledButton(onPressed: onReset, child: const Text('Reset Filter')),
        ],
      ),
    );
  }
}

class _AdvancedFilterResult {
  const _AdvancedFilterResult({
    required this.dateFilter,
    required this.customRange,
    required this.accountId,
    required this.categoryId,
  });

  final _DateFilter dateFilter;
  final DateTimeRange? customRange;
  final int? accountId;
  final int? categoryId;
}

class _AdvancedFilterSheet extends StatefulWidget {
  const _AdvancedFilterSheet({
    required this.dateFilter,
    required this.customRange,
    required this.accountId,
    required this.categoryId,
    required this.accounts,
    required this.categories,
  });

  final _DateFilter dateFilter;
  final DateTimeRange? customRange;
  final int? accountId;
  final int? categoryId;
  final List<AccountRecord> accounts;
  final List<CategoryRecord> categories;

  @override
  State<_AdvancedFilterSheet> createState() => _AdvancedFilterSheetState();
}

class _AdvancedFilterSheetState extends State<_AdvancedFilterSheet> {
  late _DateFilter _dateFilter = widget.dateFilter;
  late DateTimeRange? _customRange = widget.customRange;
  late int? _accountId = widget.accountId;
  late int? _categoryId = widget.categoryId;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.screenH,
          AppSpacing.lg,
          AppSpacing.screenH,
          AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Filter transaksi',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Periode', style: Theme.of(context).textTheme.labelLarge),
            RadioGroup<_DateFilter>(
              groupValue: _dateFilter,
              onChanged: (value) {
                if (value == _DateFilter.custom) {
                  _pickCustomRange();
                } else if (value != null) {
                  setState(() {
                    _dateFilter = value;
                    _customRange = null;
                  });
                }
              },
              child: Column(
                children: [
                  for (final option in _DateFilter.values)
                    RadioListTile<_DateFilter>(
                      contentPadding: EdgeInsets.zero,
                      title: Text(_periodOptionLabel(option)),
                      subtitle:
                          option == _DateFilter.custom && _customRange != null
                          ? Text(
                              '${formatDate(_customRange!.start)} - ${formatDate(_customRange!.end)}',
                            )
                          : null,
                      value: option,
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<int?>(
              initialValue: _accountId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Akun'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Semua akun')),
                for (final account in widget.accounts)
                  DropdownMenuItem(
                    value: account.id,
                    child: Text(
                      '${account.name}${account.isActive ? '' : ' (diarsipkan)'}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) => setState(() => _accountId = value),
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<int?>(
              initialValue: _categoryId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Kategori'),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Semua kategori'),
                ),
                for (final category in widget.categories)
                  DropdownMenuItem(
                    value: category.id,
                    child: Row(
                      children: [
                        Icon(
                          category.type == TransactionType.income
                              ? Icons.south_west_rounded
                              : Icons.north_east_rounded,
                          size: 18,
                          color: category.type == TransactionType.income
                              ? Theme.of(context).colorScheme.incomeColor
                              : Theme.of(context).colorScheme.expenseColor,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            category.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: category.type == TransactionType.income
                                ? Theme.of(context).colorScheme.incomeColor
                                      .withValues(alpha: 0.12)
                                : Theme.of(context).colorScheme.expenseColor
                                      .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            category.type == TransactionType.income
                                ? 'Pemasukan'
                                : 'Pengeluaran',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: category.type == TransactionType.income
                                      ? Theme.of(context)
                                            .colorScheme
                                            .incomeColor
                                      : Theme.of(context)
                                            .colorScheme
                                            .expenseColor,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              onChanged: (value) => setState(() => _categoryId = value),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => setState(() {
                    _dateFilter = _DateFilter.all;
                    _customRange = null;
                    _accountId = null;
                    _categoryId = null;
                  }),
                  child: const Text('Reset'),
                ),
                const SizedBox(width: AppSpacing.sm),
                FilledButton(
                  onPressed: () => Navigator.pop(
                    context,
                    _AdvancedFilterResult(
                      dateFilter: _dateFilter,
                      customRange: _customRange,
                      accountId: _accountId,
                      categoryId: _categoryId,
                    ),
                  ),
                  child: const Text('Terapkan'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: _customRange ?? DateTimeRange(start: now, end: now),
    );
    if (!mounted || selected == null) return;
    setState(() {
      _dateFilter = _DateFilter.custom;
      _customRange = selected;
    });
  }
}

// ---------------------------------------------------------------------------
// Period summary strip
// ---------------------------------------------------------------------------

class _PeriodSummaryStrip extends StatelessWidget {
  const _PeriodSummaryStrip({required this.income, required this.expense});

  final int income;
  final int expense;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenH,
        vertical: AppSpacing.sm,
      ),
      color: colors.surfaceContainerHighest.withValues(alpha: 0.3),
      child: Row(
        children: [
          Icon(Icons.south_west, size: 14, color: colors.incomeColor),
          const SizedBox(width: AppSpacing.xs),
          Text(
            formatIdr(income),
            style: textTheme.labelMedium?.copyWith(color: colors.incomeColor),
          ),
          const SizedBox(width: AppSpacing.lg),
          Icon(Icons.north_east, size: 14, color: colors.expenseColor),
          const SizedBox(width: AppSpacing.xs),
          Text(
            formatIdr(expense),
            style: textTheme.labelMedium?.copyWith(color: colors.expenseColor),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Grouped transaction list — flat rows, no individual cards
// ---------------------------------------------------------------------------

class _GroupedActivityList extends StatelessWidget {
  const _GroupedActivityList({required this.items});

  final List<FinancialActivity> items;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.xs,
        AppSpacing.screenH,
        96,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final showDate =
            index == 0 || !_isSameDate(item.date, items[index - 1].date);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showDate)
              Padding(
                padding: EdgeInsets.only(
                  top: index == 0 ? AppSpacing.xs : AppSpacing.lg,
                  bottom: AppSpacing.sm,
                ),
                child: Text(
                  formatDate(item.date),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            _ActivityRow(item: item),
          ],
        );
      },
    );
  }
}

class _ActivityRow extends ConsumerWidget {
  const _ActivityRow({required this.item});

  final FinancialActivity item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTransfer = item.type == FinancialActivityType.transfer;
    final transactionType = switch (item.type) {
      FinancialActivityType.income => TransactionType.income,
      FinancialActivityType.expense => TransactionType.expense,
      FinancialActivityType.transfer => null,
    };
    final colors = Theme.of(context).colorScheme;

    return Dismissible(
      key: ValueKey(item.identity),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.xl),
        decoration: BoxDecoration(
          color: colors.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.delete_outline, color: colors.onErrorContainer),
      ),
      confirmDismiss: (_) => _confirmDelete(context),
      onDismissed: (_) => _performDelete(context, ref),
      child: Card(
        child: ListTile(
          onTap: () => isTransfer
              ? context.push('/transfers?edit=${item.entityId}')
              : context.push('/transactions/${item.entityId}/edit'),
          leading: CircleAvatar(
            backgroundColor: isTransfer
                ? colors.tertiaryContainer
                : colors
                      .amountColor(
                        isExpense: item.type == FinancialActivityType.expense,
                      )
                      .withValues(alpha: 0.15),
            child: Icon(
              switch (item.type) {
                FinancialActivityType.income => Icons.south_west,
                FinancialActivityType.expense => Icons.north_east,
                FinancialActivityType.transfer => Icons.swap_horiz,
              },
              color: isTransfer
                  ? colors.onTertiaryContainer
                  : colors.amountColor(
                      isExpense: item.type == FinancialActivityType.expense,
                    ),
            ),
          ),
          title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isTransfer && item.categoryName != null)
                Text(item.categoryName!),
              Text(item.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
          isThreeLine: !isTransfer && item.categoryName != null,
          trailing: CurrencyText(
            amount: item.amount,
            type: transactionType,
            style: isTransfer
                ? Theme.of(context).textTheme.titleMedium
                      ?.copyWith(color: colors.tertiary)
                : null,
          ),
        ),
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus aktivitas?'),
        content: const Text('Aktivitas tidak akan muncul lagi.'),
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
  }

  Future<void> _performDelete(BuildContext context, WidgetRef ref) async {
    try {
      final deleted = item.type == FinancialActivityType.transfer
          ? await ref.read(transferRepositoryProvider).softDelete(item.entityId)
          : await ref
                .read(transactionRepositoryProvider)
                .softDelete(item.entityId);
      if (!deleted) throw StateError('Activity is no longer active');
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aktivitas gagal dihapus. Coba lagi.')),
        );
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

({DateTime? start, DateTime? end}) _dateRange(
  _DateFilter filter,
  DateTimeRange? customRange,
  DateTime now,
) {
  if (filter == _DateFilter.all) {
    return (start: null, end: null);
  }
  final range = resolveFinancialDateRange(
    switch (filter) {
      _DateFilter.all => throw StateError('All-time range has no dates'),
      _DateFilter.today => FinancialPeriod.today,
      _DateFilter.week => FinancialPeriod.week,
      _DateFilter.month => FinancialPeriod.month,
      _DateFilter.custom => FinancialPeriod.custom,
    },
    now: now,
    customStart: customRange?.start,
    customEnd: customRange?.end,
  );
  return (start: range.start, end: range.end);
}

bool _isSameDate(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;

String _periodOptionLabel(_DateFilter filter) => switch (filter) {
  _DateFilter.all => 'Semua waktu',
  _DateFilter.today => 'Hari ini',
  _DateFilter.week => 'Minggu ini',
  _DateFilter.month => 'Bulan ini',
  _DateFilter.custom => 'Rentang kustom',
};

String _periodLabel(_DateFilter filter, DateTimeRange? range) {
  if (filter == _DateFilter.custom && range != null) {
    return '${formatDate(range.start)} - ${formatDate(range.end)}';
  }
  return _periodOptionLabel(filter);
}

bool _hasAnyFilter(
  FinancialActivityType? type,
  _DateFilter date,
  int? accountId,
  int? categoryId,
  String search,
) =>
    type != null ||
    date != _DateFilter.all ||
    accountId != null ||
    categoryId != null ||
    search.trim().isNotEmpty;

enum _DateFilter { all, today, week, month, custom }
