import 'package:flutter/material.dart';

import '../models/inventory_stats.dart';
import '../widgets/common.dart';

class OverviewPage extends StatelessWidget {
  const OverviewPage({
    super.key,
    required this.stats,
    required this.advice,
    required this.onRefreshAdvice,
    required this.onGenerateRecipes,
    required this.onBulkImport,
  });

  final InventoryStats stats;
  final String advice;
  final Future<void> Function({bool force}) onRefreshAdvice;
  final VoidCallback onGenerateRecipes;
  final VoidCallback onBulkImport;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            StatCard(label: 'Items', value: '${stats.itemCount}', color: const Color(0xFF166534)),
            StatCard(label: 'Due Soon', value: '${stats.expiringSoon}', color: const Color(0xFFB45309)),
            StatCard(label: 'Expired', value: '${stats.expired}', color: const Color(0xFFB91C1C)),
            StatCard(label: 'Low Stock', value: '${stats.lowStock}', color: const Color(0xFF0F766E)),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('Today\'s Advice', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    ),
                    TextButton(
                      onPressed: () => onRefreshAdvice(force: true),
                      child: const Text('Refresh'),
                    ),
                  ],
                ),
                Text(advice),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Category Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                if (stats.categoryTotals.isEmpty)
                  const Text('No inventory items yet.')
                else
                  ...stats.categoryTotals.entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('${entry.key}: ${entry.value.toStringAsFixed(entry.value % 1 == 0 ? 0 : 1)}'),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: onGenerateRecipes,
          icon: const Icon(Icons.restaurant_menu),
          label: const Text('Generate Recipes'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onBulkImport,
          icon: const Icon(Icons.auto_awesome),
          label: const Text('Bulk Import'),
        ),
      ],
    );
  }
}
