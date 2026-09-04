import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_spacing.dart';
import '../../accounts/data/account_repository.dart';
import '../../accounts/domain/account_type.dart';
import '../../categories/data/category_repository.dart';
import '../../transactions/domain/transaction_type.dart';
import '../data/report_chart_providers.dart';
import '../data/report_repository.dart';
import '../domain/report_chart_data.dart';
import 'account_balance_chart.dart';
import 'expense_category_chart.dart';
import 'financial_trend_chart.dart';
import 'income_expense_chart.dart';
import 'report_chart_section.dart';
import 'report_period.dart';

class AnalyticsChartPage extends ConsumerStatefulWidget {
  const AnalyticsChartPage({super.key, required this.initialRange});

  final ReportRange initialRange;

  static String locationFor(ReportRange range) => Uri(
    path: '/reports/analytics',
    queryParameters: {
      'start': _queryDate(range.start),
      'end': _queryDate(range.end),
    },
  ).toString();

  static ReportRange rangeFromUri(Uri uri, {DateTime? now}) {
    final start = _parseQueryDate(uri.queryParameters['start']);
    final end = _parseQueryDate(uri.queryParameters['end']);
    if (start == null ||
        end == null ||
        start.isBefore(DateTime(2000)) ||
        end.isAfter(DateTime(2100, 12, 31)) ||
        start.isAfter(end)) {
      return resolveReportRange(ReportPeriod.month, now: now);
    }
    return ReportRange(start: start, end: end);
  }

  @override
  ConsumerState<AnalyticsChartPage> createState() => _AnalyticsChartPageState();
}

class _AnalyticsChartPageState extends ConsumerState<AnalyticsChartPage> {
  late ReportRange _range;
  late ReportPeriod _period;
  DateTimeRange? _customRange;
  int? _accountId;
  int? _categoryId;

  @override
  void initState() {
    super.initState();
    _range = widget.initialRange;
    _period = reportPeriodForRange(_range);
    if (_period == ReportPeriod.custom) {
      _customRange = DateTimeRange(start: _range.start, end: _range.end);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider).valueOrNull ?? const [];
    final categories = ref.watch(categoriesProvider).valueOrNull ?? const [];
    final accountId = accounts.any((account) => account.id == _accountId)
        ? _accountId
        : null;
    final categoryId = categories.any((category) => category.id == _categoryId)
        ? _categoryId
        : null;
    final filter = ReportFilter(
      range: _range,
      accountId: accountId,
      categoryId: categoryId,
    );
    final trend = ref.watch(financialTrendProvider(filter));
    final expenseCategories = ref.watch(expenseCategoryChartProvider(filter));
    final accountBalances = ref.watch(accountBalanceChartProvider);
    final categoryCount = expenseCategories.valueOrNull?.length ?? 0;
    final accountCount =
        accountBalances.valueOrNull?.where((point) => point.isActive).length ??
        0;
    final granularity = chartGranularityFor(_range);
    return Scaffold(
      appBar: AppBar(title: const Text('Analisis Grafik')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              AppSpacing.md,
              AppSpacing.screenH,
              AppSpacing.xs,
            ),
            child: Row(
              spacing: AppSpacing.sm,
              children: [
                _periodChip('Semua', ReportPeriod.all),
                _periodChip('Hari ini', ReportPeriod.today),
                _periodChip('Minggu ini', ReportPeriod.week),
                _periodChip('Bulan ini', ReportPeriod.month),
                _periodChip('Tahun ini', ReportPeriod.year),
                ChoiceChip(
                  label: const Text('Rentang'),
                  selected: _period == ReportPeriod.custom,
                  onSelected: (_) => _selectCustomRange(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              AppSpacing.sm,
              AppSpacing.screenH,
              0,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _rangeLabel(_range, _period),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                OutlinedButton.icon(
                  key: const Key('analytics-filter'),
                  onPressed: () => _openFilters(
                    accounts,
                    categories,
                    accountId: accountId,
                    categoryId: categoryId,
                  ),
                  icon: const Icon(Icons.filter_list, size: 18),
                  label: Text(
                    filter.hasTransactionFilter
                        ? 'Filter (${[accountId, categoryId].whereType<int>().length})'
                        : 'Filter',
                  ),
                ),
              ],
            ),
          ),
          if (filter.hasTransactionFilter)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                AppSpacing.sm,
                AppSpacing.screenH,
                0,
              ),
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (accountId != null)
                    InputChip(
                      label: Text(
                        'Akun: ${_accountLabel(accounts.firstWhere((item) => item.id == accountId))}',
                      ),
                      onDeleted: () => setState(() => _accountId = null),
                    ),
                  if (categoryId != null)
                    InputChip(
                      label: Text(
                        'Kategori: ${_categoryLabel(categories.firstWhere((item) => item.id == categoryId))}',
                      ),
                      onDeleted: () => setState(() => _categoryId = null),
                    ),
                  TextButton(
                    onPressed: _resetFilters,
                    child: const Text('Reset'),
                  ),
                  const Text(
                    'Filter akun dan kategori tidak mengubah Saldo per Akun.',
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              AppSpacing.xl,
              AppSpacing.screenH,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Arus Keuangan',
                  style: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(color: Theme.of(context).colorScheme.primary),
                ),
                const SizedBox(height: AppSpacing.sm),
                ReportChartSection<List<FinancialTrendPoint>>(
                  title: 'Pemasukan vs Pengeluaran',
                  subtitle: 'Perbandingan berdasarkan periode analisis',
                  data: trend,
                  isEmpty: (points) => !hasIncomeExpenseData(points),
                  onRetry: () => ref.invalidate(financialTrendProvider(filter)),
                  height: 340,
                  emptyMessage: filter.hasTransactionFilter
                      ? 'Tidak ada data untuk filter ini.'
                      : 'Belum ada transaksi pada periode ini.',
                  builder: (context, points) => IncomeExpenseChart(
                    points: points,
                    granularity: granularity,
                    range: _range,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Pengeluaran',
                  style: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(color: Theme.of(context).colorScheme.primary),
                ),
                const SizedBox(height: AppSpacing.sm),
                ReportChartSection<List<CategoryChartPoint>>(
                  title: 'Pengeluaran per Kategori',
                  subtitle: 'Kategori dengan pengeluaran terbesar',
                  data: expenseCategories,
                  isEmpty: (points) => points.isEmpty,
                  onRetry: () =>
                      ref.invalidate(expenseCategoryChartProvider(filter)),
                  height: _categoryChartHeight(categoryCount),
                  emptyMessage: filter.hasTransactionFilter
                      ? 'Tidak ada data untuk filter ini.'
                      : 'Belum ada pengeluaran pada periode ini.',
                  builder: (context, points) =>
                      ExpenseCategoryChart(points: points),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Tren Keuangan',
                  style: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(color: Theme.of(context).colorScheme.primary),
                ),
                const SizedBox(height: AppSpacing.sm),
                ReportChartSection<List<FinancialTrendPoint>>(
                  title: 'Tren Keuangan',
                  subtitle: 'Pergerakan pemasukan, pengeluaran, dan net',
                  data: trend,
                  isEmpty: (points) => !hasFinancialTrendData(points),
                  onRetry: () => ref.invalidate(financialTrendProvider(filter)),
                  height: 360,
                  emptyMessage: filter.hasTransactionFilter
                      ? 'Tidak ada data untuk filter ini.'
                      : 'Belum ada data tren pada periode ini.',
                  builder: (context, points) => FinancialTrendChart(
                    points: points,
                    granularity: granularity,
                    range: _range,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Akun & Saldo',
                  style: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(color: Theme.of(context).colorScheme.primary),
                ),
                const SizedBox(height: AppSpacing.sm),
                ReportChartSection<List<AccountBalanceChartPoint>>(
                  title: 'Saldo per Akun',
                  subtitle: 'Saldo saat ini, tidak dibatasi periode laporan',
                  data: accountBalances,
                  isEmpty: (points) => !points.any((point) => point.isActive),
                  onRetry: () => ref.invalidate(accountBalanceChartProvider),
                  height: _accountChartHeight(accountCount),
                  emptyMessage: 'Belum ada akun untuk ditampilkan.',
                  builder: (context, points) => AccountBalanceChart(
                    points: visibleAccountBalances(points),
                    totalAssets: points.fold<int>(
                      0,
                      (sum, point) => sum + point.balance,
                    ),
                    archivedCount: points
                        .where((point) => !point.isActive)
                        .length,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _periodChip(String label, ReportPeriod period) {
    return ChoiceChip(
      label: Text(label),
      selected: _period == period,
      onSelected: (_) => setState(() {
        _period = period;
        _customRange = null;
        _range = resolveReportRange(period);
      }),
    );
  }

  Future<void> _selectCustomRange() async {
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
      initialDateRange: _customRange,
    );
    if (selected == null || !mounted) return;
    setState(() {
      _period = ReportPeriod.custom;
      _customRange = selected;
      _range = resolveReportRange(ReportPeriod.custom, customRange: selected);
    });
  }

  Future<void> _openFilters(
    List<AccountRecord> accounts,
    List<CategoryRecord> categories, {
    required int? accountId,
    required int? categoryId,
  }) async {
    final result =
        await showModalBottomSheet<({int? accountId, int? categoryId})>(
          context: context,
          isScrollControlled: true,
          builder: (context) => _AnalyticsFilterSheet(
            accounts: accounts,
            categories: categories,
            accountId: accountId,
            categoryId: categoryId,
          ),
        );
    if (result == null || !mounted) return;
    setState(() {
      _accountId = result.accountId;
      _categoryId = result.categoryId;
    });
  }

  void _resetFilters() => setState(() {
    _period = ReportPeriod.month;
    _customRange = null;
    _range = resolveReportRange(ReportPeriod.month);
    _accountId = null;
    _categoryId = null;
  });
}

class _AnalyticsFilterSheet extends StatefulWidget {
  const _AnalyticsFilterSheet({
    required this.accounts,
    required this.categories,
    required this.accountId,
    required this.categoryId,
  });

  final List<AccountRecord> accounts;
  final List<CategoryRecord> categories;
  final int? accountId;
  final int? categoryId;

  @override
  State<_AnalyticsFilterSheet> createState() => _AnalyticsFilterSheetState();
}

class _AnalyticsFilterSheetState extends State<_AnalyticsFilterSheet> {
  late int? _accountId = widget.accountId;
  late int? _categoryId = widget.categoryId;

  @override
  Widget build(BuildContext context) {
    final accounts = widget.accounts
        .where((account) => account.isActive || account.id == _accountId)
        .toList(growable: false);
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
              'Filter Analisis',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.lg),
            DropdownButtonFormField<int?>(
              key: const Key('analytics-account-filter'),
              initialValue: _accountId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Akun'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Semua Akun')),
                for (final account in accounts)
                  DropdownMenuItem(
                    value: account.id,
                    child: Text(
                      '${_accountLabel(account)}${account.isActive ? '' : ' (diarsipkan)'}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) => setState(() => _accountId = value),
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<int?>(
              key: const Key('analytics-category-filter'),
              initialValue: _categoryId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Kategori'),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Semua Kategori'),
                ),
                for (final category in widget.categories)
                  DropdownMenuItem(
                    value: category.id,
                    child: Text(
                      _categoryLabel(category),
                      overflow: TextOverflow.ellipsis,
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
                    _accountId = null;
                    _categoryId = null;
                  }),
                  child: const Text('Reset'),
                ),
                const SizedBox(width: AppSpacing.sm),
                FilledButton(
                  onPressed: () => Navigator.pop(context, (
                    accountId: _accountId,
                    categoryId: _categoryId,
                  )),
                  child: const Text('Terapkan'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _accountLabel(AccountRecord account) =>
    '${account.name} - ${account.type.label}';

String _categoryLabel(CategoryRecord category) =>
    '${category.name} - ${category.type == TransactionType.income ? 'Pemasukan' : 'Pengeluaran'}';

double _categoryChartHeight(int categoryCount) {
  final visibleCount = categoryCount > maxVisibleExpenseCategories
      ? maxVisibleExpenseCategories + 1
      : categoryCount;
  return max(330, visibleCount * 56 + 250).toDouble();
}

double _accountChartHeight(int accountCount) =>
    max(270, accountCount * 80 + 130).toDouble();

String _rangeLabel(ReportRange range, ReportPeriod period) {
  if (period == ReportPeriod.all) return 'Semua transaksi';
  if (period == ReportPeriod.month) {
    return DateFormat('MMMM y', 'id_ID').format(range.start);
  }
  if (period == ReportPeriod.year) return '${range.start.year}';
  final format = DateFormat('d MMM y', 'id_ID');
  if (range.start == range.end) return format.format(range.start);
  return '${format.format(range.start)} - ${format.format(range.end)}';
}

String _queryDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

DateTime? _parseQueryDate(String? value) {
  if (value == null || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    return null;
  }
  final date = DateTime.tryParse(value);
  return date != null && _queryDate(date) == value ? date : null;
}
