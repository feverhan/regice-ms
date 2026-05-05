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
    required this.onBulkImport,
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
  final VoidCallback onBulkImport;

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
                Row(
                  children: [
                    Expanded(
                        child:
                            Text('查找食材', style: theme.textTheme.titleMedium)),
                    IconButton.filledTonal(
                      onPressed: onBulkImport,
                      icon: const Icon(Icons.auto_awesome_rounded),
                      tooltip: 'AI 识别清单',
                    ),
                  ],
                ),
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
                    final stepLabel =
                        '${InventoryItem.formatNumber(item.defaultStep)}${item.unit}';
                    return Card(
                      margin: EdgeInsets.only(bottom: gap * 0.65),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppLayout.cardPadding(context),
                          vertical: AppLayout.isPhone(context) ? 10 : 12,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                          fontSize:
                                              AppLayout.itemTitleSize(context) -
                                                  1,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${item.category} · ${item.quantityLabel}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF2F4F40),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _TinyIconButton(
                                  icon: Icons.edit_outlined,
                                  tooltip: '编辑',
                                  onPressed: () => onEdit(item),
                                ),
                                _TinyIconButton(
                                  icon: Icons.delete_outline,
                                  tooltip: '删除',
                                  onPressed: () => onDelete(item),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Text(
                              item.statusDescription,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall,
                            ),
                            if (item.note.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                item.note,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _CompactQuantityButton(
                                  icon: Icons.remove_rounded,
                                  label: stepLabel,
                                  tooltip: '减少 $stepLabel',
                                  onPressed: () => onDecrement(item),
                                ),
                                _CompactQuantityButton(
                                  icon: Icons.add_rounded,
                                  label: stepLabel,
                                  tooltip: '补充 $stepLabel',
                                  onPressed: () => onIncrement(item),
                                ),
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

class _TinyIconButton extends StatelessWidget {
  const _TinyIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 32, height: 32),
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: const Color(0xFF526158),
      ),
    );
  }
}

class _CompactQuantityButton extends StatelessWidget {
  const _CompactQuantityButton({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 32),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 0),
          textStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: const BorderSide(color: Color(0xFFD8D0C4)),
        ),
      ),
    );
  }
}
