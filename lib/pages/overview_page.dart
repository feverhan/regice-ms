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
    final padding = AppLayout.pagePadding(context);
    final gap = AppLayout.sectionGap(context);

    return ListView(
      padding: EdgeInsets.all(padding),
      children: [
        Container(
          padding: EdgeInsets.all(AppLayout.cardPadding(context) + 2),
          decoration: BoxDecoration(
            color: const Color(0xFFEAE2D1),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('今日饮食建议', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              Text(
                advice,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(height: 1.45),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: onGenerateRecipes,
                      child: const Text('厨房助手'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: () => onRefreshAdvice(force: true),
                    icon: const Icon(Icons.refresh_rounded),
                    tooltip: '换一条建议',
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: onBulkImport,
                    icon: const Icon(Icons.auto_awesome_rounded),
                    tooltip: '识别清单',
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: gap),
        Text('库存一览', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final columnGap = gap;
            final width = (constraints.maxWidth - columnGap) / 2;
            return Wrap(
              spacing: columnGap,
              runSpacing: columnGap,
              children: [
                StatCard(label: '现有食材', value: '${stats.itemCount}', color: const Color(0xFF315947), width: width),
                StatCard(label: '快到期', value: '${stats.expiringSoon}', color: const Color(0xFFB26A1D), width: width),
                StatCard(label: '已过期', value: '${stats.expired}', color: const Color(0xFFB14242), width: width),
                StatCard(label: '补货提醒', value: '${stats.lowStock}', color: const Color(0xFF176B67), width: width),
              ],
            );
          },
        ),
        SizedBox(height: gap),
        Card(
          child: Padding(
            padding: EdgeInsets.all(AppLayout.cardPadding(context)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('分类数量', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (stats.categoryTotals.isEmpty)
                  const Text('还没有食材记录，先添加几样常用食材吧。')
                else
                  ...stats.categoryTotals.entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Expanded(child: Text(entry.key)),
                          Text(entry.value.toStringAsFixed(entry.value % 1 == 0 ? 0 : 1)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
