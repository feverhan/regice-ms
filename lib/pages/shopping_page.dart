import 'package:flutter/material.dart';

import '../models/inventory_item.dart';
import '../widgets/common.dart';

class ShoppingPage extends StatelessWidget {
  const ShoppingPage({
    super.key,
    required this.shoppingItems,
    required this.onClearExpired,
    required this.onExport,
  });

  final List<InventoryItem> shoppingItems;
  final VoidCallback onClearExpired;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final padding = AppLayout.pagePadding(context);
    final theme = Theme.of(context);

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(padding),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onClearExpired,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('清理过期'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onExport,
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('导出清单'),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: shoppingItems.isEmpty
              ? const Center(child: Text('目前没有需要补货的食材。'))
              : ListView.builder(
                  padding: EdgeInsets.fromLTRB(padding, 0, padding, 120),
                  itemCount: shoppingItems.length,
                  itemBuilder: (context, index) {
                    final item = shoppingItems[index];
                    final gap = (item.minQuantity - item.quantity) > item.defaultStep
                        ? (item.minQuantity - item.quantity)
                        : item.defaultStep;
                    return Card(
                      margin: EdgeInsets.only(bottom: AppLayout.sectionGap(context)),
                      child: Padding(
                        padding: EdgeInsets.all(AppLayout.cardPadding(context)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontSize: AppLayout.itemTitleSize(context),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text('当前库存 ${item.quantityLabel}'),
                            Text('提醒阈值 ${item.minQuantityLabel}'),
                            const SizedBox(height: 6),
                            Text('建议补货 ${InventoryItem.formatNumber(gap)}${item.unit}'),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
