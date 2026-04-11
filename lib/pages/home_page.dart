import 'package:flutter/material.dart';

import '../models/inventory_item.dart';
import '../models/inventory_stats.dart';
import '../models/settings_data.dart';
import '../services/inventory_store.dart';
import '../services/qwen_service.dart';
import '../services/settings_repository.dart';
import '../widgets/dialogs.dart';
import 'ai_assistant_page.dart';
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
  String _dailyAdvice = '先在设置中填写 AI 密钥，再生成每日饮食建议。';
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
    if (edited == null) {
      return;
    }

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
            title: const Text('删除食材'),
            content: Text('确认删除“${item.name}”吗？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('删除'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) {
      return;
    }

    setState(() {
      _items.removeWhere((entry) => entry.id == item.id);
    });
    await _saveItems();
  }

  Future<void> _adjustQuantity(InventoryItem item, double delta) async {
    final index = _items.indexWhere((entry) => entry.id == item.id);
    if (index < 0) {
      return;
    }
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
            title: const Text('清理过期食材'),
            content: const Text('确认从库存中移除所有已过期食材吗？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('确认'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) {
      return;
    }

    setState(() {
      _items = _items.where((item) => !item.isExpired).toList();
    });
    await _saveItems();
  }

  Future<void> _refreshAdvice({bool force = false}) async {
    if (_settings.apiKey.trim().isEmpty) {
      _showSnack('请先在设置中填写 AI 密钥。');
      return;
    }
    setState(() => _dailyAdvice = force ? '正在刷新今日建议…' : '正在生成今日建议…');
    try {
      final advice = await _qwen.fetchDailyAdvice(_items, _settings);
      await SettingsRepository.saveCachedAdvice(advice);
      if (!mounted) {
        return;
      }
      setState(() => _dailyAdvice = advice);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _dailyAdvice = '生成失败：$error');
    }
  }

  Future<void> _openAiSettings() async {
    final updated = await showDialog<SettingsData>(
      context: context,
      builder: (context) => SettingsDialog(settings: _settings),
    );
    if (updated == null) {
      return;
    }
    await SettingsRepository.save(updated);
    if (!mounted) {
      return;
    }
    setState(() => _settings = updated);
    _showSnack('AI 设置已保存。');
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
      _showSnack('请先在设置中填写 AI 密钥。');
      return;
    }
    if (!mounted) {
      return;
    }
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) => AiAssistantPage(
          items: List<InventoryItem>.from(_items),
          settings: _settings,
          qwenService: _qwen,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.04),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  Future<void> _bulkImport() async {
    if (_settings.apiKey.trim().isEmpty) {
      _showSnack('请先在设置中填写 AI 密钥。');
      return;
    }
    final rawText = await _askForText(
      title: '批量导入',
      hint: '粘贴购物清单、便签内容或自然语言描述',
      confirmText: '开始导入',
    );
    if (rawText == null || rawText.trim().isEmpty) {
      return;
    }
    if (!mounted) {
      return;
    }
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final imported = await _qwen.bulkImport(rawText, _settings);
      if (!mounted) {
        return;
      }
      setState(() {
        _items = [...imported, ..._items];
      });
      await _saveItems();
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
      await showDialog<void>(
        context: context,
        builder: (context) => OutputDialog(
          title: '导入结果',
          content: imported
              .map((item) => '${item.name}\n${item.quantityLabel} · ${item.category}')
              .join('\n\n'),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
      _showSnack('批量导入失败：$error');
    }
  }

  Future<void> _exportData() async {
    final file = await _store.exportItems(_items);
    _showSnack('已导出到 ${file.path}');
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
                onGenerateRecipes: _generateRecipes,
                onBulkImport: _bulkImport,
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
                onEdit: _showItemEditor,
                onDelete: _deleteItem,
                onIncrement: (item) => _adjustQuantity(item, item.defaultStep),
                onDecrement: (item) => _adjustQuantity(item, -item.defaultStep),
              ),
              ShoppingPage(
                shoppingItems: _stats.shoppingList,
                onClearExpired: _clearExpired,
                onExport: _exportData,
              ),
            ],
          );

    return Scaffold(
      appBar: AppBar(
        title: const Text('鲜度管家'),
        actions: [
          IconButton(
            onPressed: _bootstrap,
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
              label: const Text('新增食材'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (value) => setState(() => _tabIndex = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: '总览'),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), label: '库存'),
          NavigationDestination(icon: Icon(Icons.shopping_cart_outlined), label: '补货'),
        ],
      ),
    );
  }
}
