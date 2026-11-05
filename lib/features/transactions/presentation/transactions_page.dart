import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/main_scaffold.dart';
import '../../../core/database/app_database.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/finote_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/financial_date_range.dart';
import '../../../core/widgets/app_snackbars.dart';
import '../../../core/widgets/finance_tiles.dart';
import '../../../core/widgets/finote_controls.dart';
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final filterCount = _filterCount(accountId, categoryId);
    final totals = activities.whenOrNull(data: _totalsOf);

    return Scaffold(
      appBar: AppBar(
        title: _searchOpen
            ? SizedBox(
                width: double.infinity,
                child: SearchBar(
                  controller: _searchController,
                  hintText: 'Cari transaksi, transfer, atau akun',
                  autoFocus: true,
                  leading: const Icon(Icons.search),
                  trailing: [
                    IconButton(
                      icon: const Icon(Icons.close),
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
              )
            : Text('Transaksi', style: theme.textTheme.headlineLarge),
        actions: [
          if (!_searchOpen)
            IconButton(
              tooltip: 'Cari transaksi',
              onPressed: () => setState(() => _searchOpen = true),
              style: IconButton.styleFrom(
                backgroundColor: colors.surface,
                fixedSize: const Size(40, 40),
              ),
              icon: const Icon(Icons.search),
            ),
          Badge(
            isLabelVisible: filterCount > 0,
            label: Text('$filterCount'),
            child: IconButton(
              tooltip: 'Filter transaksi',
              onPressed: () => _openAdvancedFilters(accounts, categories),
              style: IconButton.styleFrom(
                backgroundColor: colors.primaryContainer,
                foregroundColor: colors.onPrimaryContainer,
                fixedSize: const Size(40, 40),
              ),
              icon: const Icon(Icons.filter_list_rounded),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          if (totals != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenH,
                  AppSpacing.sm,
                  AppSpacing.screenH,
                  AppSpacing.xs,
                ),
                child: _CashflowSummaryCard(
                  title:
                      'Arus kas · ${_periodLabel(_dateFilter, _customRange)}',
                  income: totals.income,
                  expense: totals.expense,
                ),
              ),
            ),
          // Type filters stay pinned so they are reachable at any scroll.
          SliverPersistentHeader(
            pinned: true,
            delegate: _FilterBarDelegate(
              color: theme.scaffoldBackgroundColor,
              child: _typeChips(),
            ),
          ),
          if (_dateFilter != _DateFilter.all ||
              accountId != null ||
              categoryId != null)
            SliverToBoxAdapter(
              child: Padding(
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
            ),
          ...activities.when(
            loading: () => const [
              SliverFillRemaining(
                hasScrollBody: false,
                child: AppLoadingState(),
              ),
            ],
            error: (error, stackTrace) => [
              SliverFillRemaining(
                hasScrollBody: false,
                child: AppErrorState(
                  message: 'Aktivitas belum dapat dimuat.',
                  onRetry: () =>
                      ref.invalidate(financialActivityProvider(filter)),
                ),
              ),
            ],
            data: (items) => items.isEmpty
                ? [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _FilteredEmptyState(
                        filtered: _hasAnyFilter(
                          _type,
                          _dateFilter,
                          accountId,
                          categoryId,
                          _search,
                        ),
                        onReset: _resetFilters,
                      ),
                    ),
                  ]
                : [_GroupedActivitySliver(items: items)],
          ),
        ],
      ),
    );
  }

  Widget _typeChips() {
    final options = <(String, FinancialActivityType?)>[
      ('Semua', null),
      ('Pemasukan', FinancialActivityType.income),
      ('Pengeluaran', FinancialActivityType.expense),
      ('Transfer', FinancialActivityType.transfer),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
      child: Row(
        spacing: AppSpacing.sm,
        children: [
          for (final (label, type) in options)
            FinoteChip(
              label: label,
              selected: _type == type,
              onSelected: () {
                FocusManager.instance.primaryFocus?.unfocus();
                setState(() => _type = type);
              },
            ),
        ],
      ),
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
      // The shell FAB is the add action on this tab.
      return const AppEmptyState(
        icon: Icons.receipt_long_outlined,
        message: 'Belum ada transaksi.',
        subtitle: 'Catat pemasukan atau pengeluaran pertama Anda.',
      );
    }
    return AppEmptyState(
      icon: Icons.filter_alt_off_outlined,
      message: 'Tidak ada transaksi yang cocok dengan filter.',
      actionLabel: 'Reset Filter',
      onAction: onReset,
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
                          Theme.of(context).finote
                              .categoryStyle(category.name)
                              .icon,
                          size: 18,
                          color: Theme.of(context).finote
                              .categoryStyle(category.name)
                              .foreground,
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
// Cashflow summary (income/expense of what the list currently shows)
// ---------------------------------------------------------------------------

({int income, int expense})? _totalsOf(List<FinancialActivity> items) {
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
  return hasTransactions ? (income: income, expense: expense) : null;
}

class _CashflowSummaryCard extends StatelessWidget {
  const _CashflowSummaryCard({
    required this.title,
    required this.income,
    required this.expense,
  });

  final String title;
  final int income;
  final int expense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final net = income - expense;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.bodySmall),
            const SizedBox(height: AppSpacing.xs),
            CurrencyText(
              amount: net.abs(),
              type: net == 0
                  ? null
                  : net > 0
                  ? TransactionType.income
                  : TransactionType.expense,
              maskable: true,
              alignment: Alignment.centerLeft,
              style: AppTypography.amountXl.copyWith(color: colors.onSurface),
            ),
            const SizedBox(height: AppSpacing.md),
            ExcludeSemantics(
              child: _SplitBar(income: income, expense: expense),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _LegendAmount(
                    dot: colors.primary,
                    label: 'Pemasukan',
                    amount: income,
                    color: colors.incomeColor,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _LegendAmount(
                    dot: colors.primaryContainer,
                    label: 'Pengeluaran',
                    amount: expense,
                    color: colors.expenseColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Proportion of income vs expense; carries no amounts, so it is safe to
/// show while balances are hidden.
class _SplitBar extends StatelessWidget {
  const _SplitBar({required this.income, required this.expense});

  final int income;
  final int expense;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final total = income + expense;
    if (total <= 0) return const SizedBox.shrink();
    int flex(int part) => (part / total * 1000).round().clamp(1, 1000);
    Widget bar(Color color) => DecoratedBox(
      decoration: BoxDecoration(color: color, borderRadius: AppRadius.smAll),
      child: const SizedBox(height: 8),
    );
    return Row(
      children: [
        if (income > 0)
          Expanded(flex: flex(income), child: bar(colors.primary)),
        if (income > 0 && expense > 0) const SizedBox(width: AppSpacing.xs),
        if (expense > 0)
          Expanded(flex: flex(expense), child: bar(colors.primaryContainer)),
      ],
    );
  }
}

class _LegendAmount extends StatelessWidget {
  const _LegendAmount({
    required this.dot,
    required this.label,
    required this.amount,
    required this.color,
  });

  final Color dot;
  final String label;
  final int amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
              child: const SizedBox(width: 8, height: 8),
            ),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(label, style: Theme.of(context).textTheme.bodySmall),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        CurrencyText(
          amount: amount,
          maskable: true,
          alignment: Alignment.centerLeft,
          style: AppTypography.amountMd.copyWith(color: color),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Pinned type filter bar
// ---------------------------------------------------------------------------

class _FilterBarDelegate extends SliverPersistentHeaderDelegate {
  const _FilterBarDelegate({required this.child, required this.color});

  final Widget child;
  final Color color;

  static const _height = 56.0;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => ColoredBox(
    color: color,
    child: SizedBox(height: _height, child: child),
  );

  @override
  bool shouldRebuild(covariant _FilterBarDelegate oldDelegate) => true;
}

// ---------------------------------------------------------------------------
// Date-grouped list. Flattened (header + rows) so rows still build lazily
// for large histories; each group reads as one rounded surface.
// ---------------------------------------------------------------------------

class _Entry {
  const _Entry.header(this.date, this.total)
    : item = null,
      first = false,
      last = false;
  const _Entry.row(
    FinancialActivity this.item, {
    this.first = false,
    this.last = false,
  }) : date = null,
       total = null;

  final DateTime? date;
  final int? total;
  final FinancialActivity? item;
  final bool first;
  final bool last;
}

/// Groups consecutive same-date activities (the list is already ordered by
/// date). The daily total counts income/expense only; transfers are neither,
/// so a transfers-only day shows no total.
List<_Entry> _entriesOf(List<FinancialActivity> items) {
  final entries = <_Entry>[];
  var start = 0;
  while (start < items.length) {
    var end = start;
    var total = 0;
    var hasTransactions = false;
    while (end < items.length &&
        _isSameDate(items[end].date, items[start].date)) {
      final type = items[end].type;
      if (type != FinancialActivityType.transfer) {
        hasTransactions = true;
        total += type == FinancialActivityType.income
            ? items[end].amount
            : -items[end].amount;
      }
      end++;
    }
    entries.add(
      _Entry.header(items[start].date, hasTransactions ? total : null),
    );
    for (var i = start; i < end; i++) {
      entries.add(_Entry.row(items[i], first: i == start, last: i == end - 1));
    }
    start = end;
  }
  return entries;
}

class _GroupedActivitySliver extends StatelessWidget {
  const _GroupedActivitySliver({required this.items});

  final List<FinancialActivity> items;

  @override
  Widget build(BuildContext context) {
    final entries = _entriesOf(items);
    final now = DateTime.now();
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        0,
        AppSpacing.screenH,
        kFabClearance,
      ),
      sliver: SliverList.builder(
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final entry = entries[index];
          final item = entry.item;
          if (item == null) {
            return Padding(
              padding: EdgeInsets.only(top: index == 0 ? 0 : AppSpacing.md),
              child: DateHeader(
                label: formatActivityDateLabel(entry.date!, now),
                total: entry.total,
                maskable: true,
              ),
            );
          }
          return _ActivityRow(item: item, first: entry.first, last: entry.last);
        },
      ),
    );
  }
}

class _ActivityRow extends ConsumerWidget {
  const _ActivityRow({
    required this.item,
    required this.first,
    required this.last,
  });

  final FinancialActivity item;
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTransfer = item.type == FinancialActivityType.transfer;
    final colors = Theme.of(context).colorScheme;
    final clock = _entryClock(item);

    final Widget tile;
    if (isTransfer) {
      tile = TransferTile(
        title: item.title,
        route: [item.subtitle, ?clock].join(' · '),
        amount: item.amount,
        maskable: true,
        onTap: () => context.push('/transfers?edit=${item.entityId}'),
      );
    } else {
      // categoryName is null when the transaction has no title of its own
      // (the title then already is the category name).
      final untitled = item.categoryName == null;
      final category = item.categoryName ?? item.title;
      tile = TransactionTile(
        title: untitled ? '' : item.title,
        categoryName: category,
        subtitle: _transactionSubtitle(item, clock) ?? '',
        caption: untitled ? null : category,
        amount: item.amount,
        type: item.type == FinancialActivityType.expense
            ? TransactionType.expense
            : TransactionType.income,
        maskable: true,
        onTap: () => context.push('/transactions/${item.entityId}/edit'),
      );
    }

    const radius = Radius.circular(AppRadius.lg);
    return Material(
      color: colors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: first ? radius : Radius.zero,
          bottom: last ? radius : Radius.zero,
        ),
      ),
      child: Dismissible(
        key: ValueKey(item.identity),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: AppSpacing.xl),
          color: colors.errorContainer,
          child: Icon(Icons.delete_outline, color: colors.onErrorContainer),
        ),
        confirmDismiss: (_) => _confirmDelete(context),
        onDismissed: (_) => _performDelete(context, ref),
        child: Padding(
          padding: EdgeInsets.only(
            top: first ? AppSpacing.xs : 0,
            bottom: last ? AppSpacing.xs : 0,
          ),
          child: tile,
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
        showAppErrorSnackBar(context, 'Aktivitas gagal dihapus. Coba lagi.');
      }
    }
  }
}

/// Entry time, shown only when the record was entered on its own calendar
/// date. The stored time is when the row was created, not a transaction
/// time, so for backdated or imported rows it would be misleading.
String? _entryClock(FinancialActivity item) {
  final created = item.createdAt?.toLocal();
  if (created == null || !_isSameDate(created, item.date)) return null;
  return formatClock(created);
}

/// "note · time · account", with the account only when it is not the default
/// one (an unavailable account is still shown so it never hides silently).
String? _transactionSubtitle(FinancialActivity item, String? clock) {
  final note = item.note?.trim().replaceAll(RegExp(r'\s+'), ' ') ?? '';
  final parts = [
    if (note.isNotEmpty) note,
    ?clock,
    if (!item.isDefaultAccount) item.subtitle,
  ];
  return parts.isEmpty ? null : parts.join(' · ');
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
