import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/inventory_item.dart';

class InventoryStore {
  Future<File> _dataFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/fridge_inventory.json');
  }

  Future<List<InventoryItem>> loadItems() async {
    final file = await _dataFile();
    if (!await file.exists()) {
      return <InventoryItem>[];
    }
    final raw = await file.readAsString();
    if (raw.trim().isEmpty) {
      return <InventoryItem>[];
    }
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((entry) => InventoryItem.fromJson(entry as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveItems(List<InventoryItem> items) async {
    final file = await _dataFile();
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(items.map((item) => item.toJson()).toList()),
    );
  }

  Future<File> exportItems(List<InventoryItem> items) async {
    final dir = await getApplicationDocumentsDirectory();
    final date = DateTime.now().toIso8601String().split('T').first;
    final file = File('${dir.path}/fridge_inventory_export_$date.json');
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(items.map((item) => item.toJson()).toList()),
    );
    return file;
  }
}
