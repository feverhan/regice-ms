import 'package:flutter/material.dart';

import '../models/inventory_item.dart';
import '../widgets/common.dart';

class InventoryPage extends StatelessWidget {
  const InventoryPage({
    super.key,
    required this.items,
    required this.categories,
    required this.searchController,
    required this.sortKey,
    required this.statusFilter,
    required this.categoryFilter,
    required this.onSortChanged,
    required this.onStatusChanged,
    required this.onCategoryChanged,
    required this.onEdit,
    required this.onDelete,
    required this.onIncrement,
    required this.onDecrement,
  });

  final List<InventoryItem> items;
  final List<String> categories;
  final TextEditingController searchController;
  final String sortKey;
  final String statusFilter;
  final String categoryFilter;
  final ValueChanged<String> onSortChanged;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<InventoryItem> onEdit;
  final ValueChanged<InventoryItem> onDelete;
  final ValueChanged<InventoryItem> onIncrement;
  final ValueChanged<InventoryItem> onDecrement;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: searchController,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search name, category, or note',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownField(
                      value: sortKey,
                      items: const {
                        'recent': 'Recently added',
                        'status': 'Status priority',
                        'expiry': 'Expiry date',
                        'quantity_desc': 'Quantity high to low',
                        'quantity_asc': 'Quantity low to high',
                        'name': 'Name',
                        'category': 'Category',
                      },
                      onChanged: onSortChanged,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownField(
                      value: statusFilter,
                      items: const {
                        '': 'All statuses',
                        'expired': 'Expired',
                        'warning': 'Due soon',
                        'low': 'Low stock',
                        'normal': 'Normal',
                      },
                      onChanged: onStatusChanged,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              DropdownField(
                value: categoryFilter,
                items: {
                  '': 'All categories',
                  for (final category in categories) category: category,
                },
                onChanged: onCategoryChanged,
              ),
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? const Center(child: Text('No matching items.'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 6),
                            Text('${item.category} | ${item.quantityLabel}'),
                            const SizedBox(height: 6),
                            Text(item.statusDescription),
                            if (item.note.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(item.note),
                            ],
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton(onPressed: () => onDecrement(item), child: const Text('-1')),
                                OutlinedButton(onPressed: () => onIncrement(item), child: const Text('+1')),
                                TextButton(onPressed: () => onEdit(item), child: const Text('Edit')),
                                TextButton(onPressed: () => onDelete(item), child: const Text('Delete')),
                              ],
                            ),
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
