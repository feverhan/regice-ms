import 'package:flutter/material.dart';

import '../models/inventory_item.dart';
import '../models/inventory_stats.dart';
import '../models/settings_data.dart';
import '../services/inventory_store.dart';
import '../services/qwen_service.dart';
import '../services/settings_repository.dart';
import '../widgets/dialogs.dart';
import 'inventory_page.dart';
import 'overview_page.dart';
import 'shopping_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final InventoryStore _store = InventoryStore();
  final QwenService _qwen = const QwenService();
  final TextEditingController _searchController = TextEditingController();

  List<InventoryItem> _items = <InventoryItem>[];
  SettingsData _settings = SettingsData.defaults();
  String _dailyAdvice = 'Add your AI key in settings first.';
  bool _loading = true;
  int _tabIndex = 0;
  String _sortKey = 'recent';
  String _statusFilter = '';
  String _categoryFilter = '';

  @override
  void initState() {
    super.initState();
    _bootstrap();
    _searchController.addListener(_rerender);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final settings = await SettingsRepository.load();
    final items = await _store.loadItems();
    final advice = await SettingsRepository.readCachedAdvice();
    if (!mounted) {
      return;
    }
    setState(() {
      _settings = settings;
      _items = items;
      _dailyAdvice = advice ?? _dailyAdvice;
      _loading = false;
    });
  }

  void _rerender() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _saveItems() async {
    await _store.saveItems(_items);
    if (mounted) {
      setState(() {});
    }
  }

  InventoryStats get _stats => InventoryStats.fromItems(_items);

  List<InventoryItem> get _filteredItems {
    final query = _searchController.text.trim().toLowerCase();
    final list = _items.where((item) {
      final matchesQuery = query.isEmpty ||
          item.name.toLowerCase().contains(query) ||
          item.category.toLowerCase().contains(query) ||
          item.note.toLowerCase().contains(query);
      final matchesCategory = _categoryFilter.isEmpty || item.category == _categoryFilter;
      final matchesStatus = switch (_statusFilter) {
        'expired' => item.isExpired,
        'warning' => item.isExpiringSoon && !item.isExpired,
        'low' => item.isLowStock,
        'normal' => !item.isExpired && !item.isExpiringSoon && !item.isLowStock,
        _ => true,
      };
      return matchesQuery && matchesCategory && matchesStatus;
    }).toList();

    list.sort((a, b) => _compareItems(a, b, _sortKey));
    return list;
  }

  int _compareItems(InventoryItem a, InventoryItem b, String key) {
    switch (key) {
      case 'status':
        return a.statusRank.compareTo(b.statusRank) != 0
            ? a.statusRank.compareTo(b.statusRank)
            : a.expiryOrMax.compareTo(b.expiryOrMax);
      case 'expiry':
        return a.expiryOrMax.compareTo(b.expiryOrMax);
      case 'quantity_desc':
        return b.quantity.compareTo(a.quantity);
      case 'quantity_asc':
        return a.quantity.compareTo(b.quantity);
      case 'name':
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      case 'category':
        return a.category.toLowerCase().compareTo(b.category.toLowerCase());
      case 'recent':
      default:
        return b.addedDate.compareTo(a.addedDate);
    }
  }

  Future<void> _showItemEditor([InventoryItem? item]) async {
    final edited = await showDialog<InventoryItem>(
      context: context,
      builder: (context) => ItemEditorDialog(item: item),
    );
    if (edited == null) return;

    setState(() {
      final index = _items.indexWhere((entry) => entry.id == edited.id);
      if (index >= 0) {
        _items[index] = edited;
      } else {
        _items.insert(0, edited);
      }
    });
    await _saveItems();
  }

  Future<void> _deleteItem(InventoryItem item) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete item'),
            content: Text('Delete "${item.name}"?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;

    setState(() {
      _items.removeWhere((entry) => entry.id == item.id);
    });
    await _saveItems();
  }

  Future<void> _adjustQuantity(InventoryItem item, double delta) async {
    final index = _items.indexWhere((entry) => entry.id == item.id);
    if (index < 0) return;
    final next = (_items[index].quantity + delta).clamp(0, double.infinity).toDouble();
    setState(() {
      _items[index] = _items[index].copyWith(quantity: next);
    });
    await _saveItems();
  }

  Future<void> _clearExpired() async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Clear expired'),
            content: const Text('Remove all expired items from inventory?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm')),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;

    setState(() {
      _items = _items.where((item) => !item.isExpired).toList();
    });
    await _saveItems();
  }

  Future<void> _refreshAdvice({bool force = false}) async {
    if (_settings.apiKey.trim().isEmpty) {
      _showSnack('Add your AI key in settings first.');
      return;
    }
    setState(() => _dailyAdvice = 'Loading...');
    try {
      final advice = await _qwen.fetchDailyAdvice(_items, _settings);
      await SettingsRepository.saveCachedAdvice(advice);
      if (!mounted) return;
      setState(() => _dailyAdvice = advice);
    } catch (error) {
      if (!mounted) return;
      setState(() => _dailyAdvice = 'Advice failed: $error');
    }
  }

  Future<void> _openAiSettings() async {
    final updated = await showDialog<SettingsData>(
      context: context,
      builder: (context) => SettingsDialog(settings: _settings),
    );
    if (updated == null) return;
    await SettingsRepository.save(updated);
    if (!mounted) return;
    setState(() => _settings = updated);
    _showSnack('Settings saved.');
  }

  Future<String?> _askForText({
    required String title,
    required String hint,
    required String confirmText,
  }) {
    return showDialog<String>(
      context: context,
      builder: (context) => TextInputDialog(
        title: title,
        hint: hint,
        confirmText: confirmText,
      ),
    );
  }

  Future<void> _generateRecipes() async {
    if (_settings.apiKey.trim().isEmpty) {
      _showSnack('Add your AI key in settings first.');
      return;
    }
    final prompt = await _askForText(
      title: 'Recipe request',
      hint: 'Optional extra request',
      confirmText: 'Generate',
    );
    if (prompt == null) return;
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final result = await _qwen.fetchRecipeSuggestions(_items, _settings, prompt);
      if (!mounted) return;
      Navigator.of(context).pop();
      await showDialog<void>(
        context: context,
        builder: (context) => OutputDialog(title: 'Recipe Suggestions', content: result),
      );
    } catch (error) {
      if (!mounted) return;
      Navigator.of(context).pop();
      _showSnack('Recipe generation failed: $error');
    }
  }

  Future<void> _bulkImport() async {
    if (_settings.apiKey.trim().isEmpty) {
      _showSnack('Add your AI key in settings first.');
      return;
    }
    final rawText = await _askForText(
      title: 'Bulk Import',
      hint: 'Paste a shopping list, notes, or receipt text',
      confirmText: 'Import',
    );
    if (rawText == null || rawText.trim().isEmpty) return;
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final imported = await _qwen.bulkImport(rawText, _settings);
      if (!mounted) return;
      setState(() {
        _items = [...imported, ..._items];
      });
      await _saveItems();
      if (!mounted) return;
      Navigator.of(context).pop();
      await showDialog<void>(
        context: context,
        builder: (context) => OutputDialog(
          title: 'Import Result',
          content: imported.map((item) => '${item.name}\n${item.quantityLabel} | ${item.category}').join('\n\n'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      Navigator.of(context).pop();
      _showSnack('Bulk import failed: $error');
    }
  }

  Future<void> _exportData() async {
    final file = await _store.exportItems(_items);
    _showSnack('Exported to ${file.path}');
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final body = _loading
        ? const Center(child: CircularProgressIndicator())
        : IndexedStack(
            index: _tabIndex,
            children: [
              OverviewPage(
                stats: _stats,
                advice: _dailyAdvice,
                onRefreshAdvice: _refreshAdvice,
                onGenerateRecipes: () {
                  _generateRecipes();
                },
                onBulkImport: () {
                  _bulkImport();
                },
              ),
              InventoryPage(
                items: _filteredItems,
                categories: {for (final item in _items) item.category}.toList()..sort(),
                searchController: _searchController,
                sortKey: _sortKey,
                statusFilter: _statusFilter,
                categoryFilter: _categoryFilter,
                onSortChanged: (value) => setState(() => _sortKey = value),
                onStatusChanged: (value) => setState(() => _statusFilter = value),
                onCategoryChanged: (value) => setState(() => _categoryFilter = value),
                onEdit: (item) {
                  _showItemEditor(item);
                },
                onDelete: (item) {
                  _deleteItem(item);
                },
                onIncrement: (item) {
                  _adjustQuantity(item, item.defaultStep);
                },
                onDecrement: (item) {
                  _adjustQuantity(item, -item.defaultStep);
                },
              ),
              ShoppingPage(
                shoppingItems: _stats.shoppingList,
                onClearExpired: () {
                  _clearExpired();
                },
                onExport: () {
                  _exportData();
                },
              ),
            ],
          );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fridge Inventory'),
        actions: [
          IconButton(
            onPressed: () {
              _bootstrap();
            },
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: _openAiSettings,
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      body: body,
      floatingActionButton: _tabIndex == 1
          ? FloatingActionButton.extended(
              onPressed: () => _showItemEditor(),
              icon: const Icon(Icons.add),
              label: const Text('Add Item'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (value) => setState(() => _tabIndex = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Overview'),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), label: 'Inventory'),
          NavigationDestination(icon: Icon(Icons.shopping_cart_outlined), label: 'Shopping'),
        ],
      ),
    );
  }
}
