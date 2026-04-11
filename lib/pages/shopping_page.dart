import 'package:flutter/material.dart';

import '../models/inventory_item.dart';

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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onClearExpired,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Clear Expired'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onExport,
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Export'),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: shoppingItems.isEmpty
              ? const Center(child: Text('Nothing needs restocking right now.'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                  itemCount: shoppingItems.length,
                  itemBuilder: (context, index) {
                    final item = shoppingItems[index];
                    final gap = (item.minQuantity - item.quantity) > item.defaultStep
                        ? (item.minQuantity - item.quantity)
                        : item.defaultStep;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 6),
                            Text('Current ${item.quantityLabel}'),
                            Text('Threshold ${item.minQuantityLabel}'),
                            const SizedBox(height: 6),
                            Text('Suggested restock ${InventoryItem.formatNumber(gap)} ${item.unit}'),
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
