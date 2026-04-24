import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../transactions/transactions_provider.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: transactionsAsync.when(
        data: (transactions) {
          if (transactions.isEmpty) return const Center(child: Text('No data for reports'));

          // Calculate category totals for expenses
          final categoryTotals = <String, double>{};
          for (var t in transactions) {
            // Only plot expenses for the pie chart
            if (t.type == 'expense') {
              categoryTotals[t.category] = (categoryTotals[t.category] ?? 0) + t.amount;
            }
          }

          if (categoryTotals.isEmpty) {
            return const Center(child: Text('No expenses to analyze yet.'));
          }

          final List<PieChartSectionData> sections = [];
          int i = 0;
          final colors = [
            AppTheme.primaryBlue,
            Colors.purpleAccent,
            Colors.orangeAccent,
            Colors.redAccent,
            Colors.teal,
          ];

          categoryTotals.forEach((category, amount) {
            sections.add(
              PieChartSectionData(
                color: colors[i % colors.length],
                value: amount,
                title: category,
                radius: 60,
                titleStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            );
            i++;
          });

          return Column(
            children: [
              const SizedBox(height: 40),
              Text('Expense Breakdown', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 40),
              SizedBox(
                height: 300,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 60,
                    sections: sections,
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
