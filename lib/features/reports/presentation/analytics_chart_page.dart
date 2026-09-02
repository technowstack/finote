import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_spacing.dart';
import '../data/report_chart_providers.dart';
import '../data/report_repository.dart';
import '../domain/report_chart_data.dart';
import 'expense_category_chart.dart';
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
    final trend = ref.watch(financialTrendProvider(_range));
    final expenseCategories = ref.watch(expenseCategoryChartProvider(_range));
    final categoryCount = expenseCategories.valueOrNull?.length ?? 0;
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
            child: Text(
              _rangeLabel(_range),
              style: Theme.of(context).textTheme.bodySmall,
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
                  onRetry: () => ref.invalidate(financialTrendProvider(_range)),
                  height: 340,
                  emptyMessage: 'Belum ada transaksi pada periode ini.',
                  builder: (context, points) => IncomeExpenseChart(
                    points: points,
                    granularity: chartGranularityFor(_range),
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
                      ref.invalidate(expenseCategoryChartProvider(_range)),
                  height: _categoryChartHeight(categoryCount),
                  emptyMessage: 'Belum ada pengeluaran pada periode ini.',
                  builder: (context, points) => ExpenseCategoryChart(
                    points: visibleExpenseCategories(points),
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
}

double _categoryChartHeight(int categoryCount) {
  final visibleCount = categoryCount > maxVisibleExpenseCategories
      ? maxVisibleExpenseCategories + 1
      : categoryCount;
  return visibleCount <= 2 ? 180 : (visibleCount * 58 + 28).toDouble();
}

String _rangeLabel(ReportRange range) {
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
