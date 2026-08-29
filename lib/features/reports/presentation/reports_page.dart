import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/currency_formatter.dart';
import '../data/report_repository.dart';

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  _ReportPeriod _period = _ReportPeriod.month;
  DateTimeRange? _customRange;

  @override
  Widget build(BuildContext context) {
    final range = _reportRange(_period, _customRange, DateTime.now());
    final report = ref.watch(reportProvider(range));

    return Scaffold(
      appBar: AppBar(title: const Text('Laporan')),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              spacing: 8,
              children: [
                _periodChip('Hari Ini', _ReportPeriod.today),
                _periodChip('Minggu Ini', _ReportPeriod.week),
                _periodChip('Bulan Ini', _ReportPeriod.month),
                ChoiceChip(
                  label: const Text('Rentang'),
                  selected: _period == _ReportPeriod.custom,
                  onSelected: (_) => _selectCustomRange(),
                ),
              ],
            ),
          ),
          Expanded(
            child: report.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => _ErrorState(
                onRetry: () => ref.invalidate(reportProvider(range)),
              ),
              data: (data) => _ReportContent(data: data),
            ),
          ),
        ],
      ),
    );
  }

  Widget _periodChip(String label, _ReportPeriod period) {
    return ChoiceChip(
      label: Text(label),
      selected: _period == period,
      onSelected: (_) => setState(() => _period = period),
    );
  }

  Future<void> _selectCustomRange() async {
    final today = DateTime.now();
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: _customRange ?? DateTimeRange(start: today, end: today),
    );
    if (selected != null) {
      setState(() {
        _customRange = selected;
        _period = _ReportPeriod.custom;
      });
    }
  }
}

class _ReportContent extends StatelessWidget {
  const _ReportContent({required this.data});

  final ReportData data;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        _Summary(data: data),
        if (data.isEmpty) ...[
          const SizedBox(height: 24),
          const _EmptyState(),
        ] else ...[
          const SizedBox(height: 28),
          _CategorySection(
            title: 'Kategori pengeluaran teratas',
            items: data.topExpenseCategories,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 24),
          _CategorySection(
            title: 'Kategori pemasukan teratas',
            items: data.topIncomeCategories,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 24),
          Text(
            'Riwayat bulanan',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          for (final month in data.monthlyHistory)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _MonthlyTile(month: month),
            ),
        ],
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.data});

  final ReportData data;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colors.secondaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Saldo periode'),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  formatIdr(data.netBalance),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colors.onSecondaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _TotalCard(
                label: 'Total pemasukan',
                amount: data.totalIncome,
                color: colors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _TotalCard(
                label: 'Total pengeluaran',
                amount: data.totalExpense,
                color: colors.error,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({
    required this.label,
    required this.amount,
    required this.color,
  });

  final String label;
  final int amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, maxLines: 2),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                formatIdr(amount),
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(color: color, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.title,
    required this.items,
    required this.color,
  });

  final String title;
  final List<CategoryTotal> items;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        if (items.isEmpty)
          const Text('Belum ada data pada periode ini.')
        else
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                for (var index = 0; index < items.length; index++) ...[
                  ListTile(
                    leading: CircleAvatar(child: Text('${index + 1}')),
                    title: Text(items[index].categoryName),
                    trailing: Text(
                      formatIdr(items[index].amount),
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (index != items.length - 1) const Divider(height: 1),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _MonthlyTile extends StatelessWidget {
  const _MonthlyTile({required this.month});

  final MonthlyTotal month;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatMonth(month.month),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: Text('+${formatIdr(month.income)}')),
                Expanded(child: Text('-${formatIdr(month.expense)}')),
                Text(
                  formatIdr(month.netBalance),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Icon(
            Icons.summarize_outlined,
            size: 44,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 12),
          const Text('Belum ada data pada periode ini.'),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Laporan belum dapat dimuat.'),
          const SizedBox(height: 8),
          TextButton(onPressed: onRetry, child: const Text('Coba lagi')),
        ],
      ),
    );
  }
}

ReportRange _reportRange(
  _ReportPeriod period,
  DateTimeRange? customRange,
  DateTime now,
) {
  final today = DateTime(now.year, now.month, now.day);
  return switch (period) {
    _ReportPeriod.today => ReportRange(start: today, end: today),
    _ReportPeriod.week => ReportRange(
      start: today.subtract(Duration(days: today.weekday - 1)),
      end: today.add(Duration(days: 7 - today.weekday)),
    ),
    _ReportPeriod.month => ReportRange(
      start: DateTime(today.year, today.month),
      end: DateTime(today.year, today.month + 1, 0),
    ),
    _ReportPeriod.custom => ReportRange(
      start: customRange?.start ?? today,
      end: customRange?.end ?? today,
    ),
  };
}

String _formatMonth(String month) =>
    DateFormat('MMMM y', 'id_ID').format(DateTime.parse('$month-01'));

enum _ReportPeriod { today, week, month, custom }
