import 'inventory_item.dart';

class InventoryStats {
  InventoryStats({
    required this.itemCount,
    required this.expiringSoon,
    required this.expired,
    required this.lowStock,
    required this.categoryTotals,
    required this.shoppingList,
  });

  final int itemCount;
  final int expiringSoon;
  final int expired;
  final int lowStock;
  final Map<String, double> categoryTotals;
  final List<InventoryItem> shoppingList;

  factory InventoryStats.fromItems(List<InventoryItem> items) {
    final totals = <String, double>{};
    final shopping = <InventoryItem>[];
    var expiringSoon = 0;
    var expired = 0;
    var lowStock = 0;

    for (final item in items) {
      totals[item.category] = (totals[item.category] ?? 0) + item.quantity;
      if (item.isExpired) {
        expired += 1;
      } else if (item.isExpiringSoon) {
        expiringSoon += 1;
      }
      if (item.isLowStock) {
        lowStock += 1;
        shopping.add(item);
      }
    }

    shopping.sort((a, b) => (b.minQuantity - b.quantity).compareTo(a.minQuantity - a.quantity));

    return InventoryStats(
      itemCount: items.length,
      expiringSoon: expiringSoon,
      expired: expired,
      lowStock: lowStock,
      categoryTotals: totals,
      shoppingList: shopping,
    );
  }
}
