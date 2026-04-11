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
    final padding = AppLayout.pagePadding(context);
    final gap = AppLayout.sectionGap(context);
    final theme = Theme.of(context);

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(padding),
          child: Container(
            padding: EdgeInsets.all(AppLayout.cardPadding(context)),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFCF7),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE8DFD1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('查找食材', style: theme.textTheme.titleMedium),
                const SizedBox(height: 10),
                TextField(
                  controller: searchController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: '搜索名称、分类或备注',
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
                          'recent': '最新添加',
                          'status': '按状态',
                          'expiry': '临期优先',
                          'quantity_desc': '数量从多到少',
                          'quantity_asc': '数量从少到多',
                          'name': '按名称',
                          'category': '按分类',
                        },
                        onChanged: onSortChanged,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownField(
                        value: statusFilter,
                        items: const {
                          '': '全部',
                          'expired': '已过期',
                          'warning': '快到期',
                          'low': '库存不足',
                          'normal': '可正常使用',
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
                    '': '全部分类',
                    for (final category in categories) category: category,
                  },
                  onChanged: onCategoryChanged,
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? const Center(child: Text('没有找到匹配的食材，换个关键词试试。'))
              : ListView.builder(
                  padding: EdgeInsets.fromLTRB(padding, 0, padding, 120),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final stepLabel = '${InventoryItem.formatNumber(item.defaultStep)}${item.unit}';
                    return Card(
                      margin: EdgeInsets.only(bottom: gap),
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
                            Text('${item.category} · ${item.quantityLabel}'),
                            const SizedBox(height: 6),
                            Text(item.statusDescription),
                            if (item.note.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(item.note, style: theme.textTheme.bodyMedium),
                            ],
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton(onPressed: () => onDecrement(item), child: Text('减少 $stepLabel')),
                                OutlinedButton(onPressed: () => onIncrement(item), child: Text('补充 $stepLabel')),
                                TextButton(onPressed: () => onEdit(item), child: const Text('编辑')),
                                TextButton(onPressed: () => onDelete(item), child: const Text('删除')),
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
