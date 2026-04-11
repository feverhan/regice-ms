class InventoryItem {
  InventoryItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.category,
    required this.expiry,
    required this.addedDate,
    required this.minQuantity,
    required this.note,
  });

  final String id;
  final String name;
  final double quantity;
  final String unit;
  final String category;
  final String expiry;
  final DateTime addedDate;
  final double minQuantity;
  final String note;

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      id: (json['id'] ?? '').toString().isEmpty
          ? DateTime.now().microsecondsSinceEpoch.toString()
          : json['id'].toString(),
      name: (json['name'] ?? '').toString().trim(),
      quantity: _parseDouble(json['quantity']),
      unit: ((json['unit'] ?? '件').toString().trim().isEmpty ? '件' : json['unit'].toString().trim()),
      category: ((json['category'] ?? '其他').toString().trim().isEmpty ? '其他' : json['category'].toString().trim()),
      expiry: (json['expiry'] ?? '').toString().trim(),
      addedDate: DateTime.tryParse((json['addedDate'] ?? '').toString()) ?? DateTime.now(),
      minQuantity: _parseDouble(json['minQuantity']),
      note: (json['note'] ?? '').toString().trim(),
    );
  }

  factory InventoryItem.fromForm({
    required InventoryItem? base,
    required String name,
    required String quantityText,
    required String unit,
    required String category,
    required String expiry,
    required String minQuantityText,
    required String note,
  }) {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw Exception('还没有填写食材名称。');
    }
    final quantity = _parseDouble(quantityText);
    if (quantity <= 0) {
      throw Exception('数量需要大于 0。');
    }
    final minQuantity = _parseDouble(minQuantityText);
    if (minQuantity < 0) {
      throw Exception('低库存提醒不能小于 0。');
    }
    final cleanExpiry = expiry.trim();
    if (cleanExpiry.isNotEmpty && DateTime.tryParse(cleanExpiry) == null) {
      throw Exception('到期日请使用 YYYY-MM-DD 格式填写。');
    }
    return InventoryItem(
      id: base?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: cleanName,
      quantity: quantity,
      unit: unit.trim().isEmpty ? '件' : unit.trim(),
      category: category.trim().isEmpty ? '其他' : category.trim(),
      expiry: cleanExpiry,
      addedDate: base?.addedDate ?? DateTime.now(),
      minQuantity: minQuantity,
      note: note.trim(),
    );
  }

  InventoryItem copyWith({double? quantity}) {
    return InventoryItem(
      id: id,
      name: name,
      quantity: quantity ?? this.quantity,
      unit: unit,
      category: category,
      expiry: expiry,
      addedDate: addedDate,
      minQuantity: minQuantity,
      note: note,
    );
  }

  InventoryItem withGeneratedIdentity() {
    return InventoryItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      quantity: quantity,
      unit: unit,
      category: category,
      expiry: expiry,
      addedDate: DateTime.now(),
      minQuantity: minQuantity,
      note: note,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'category': category,
      'expiry': expiry,
      'addedDate': addedDate.toIso8601String(),
      'minQuantity': minQuantity,
      'note': note,
    };
  }

  DateTime get expiryOrMax => DateTime.tryParse(expiry) ?? DateTime(9999, 12, 31);

  bool get isExpired =>
      expiry.isNotEmpty && expiryOrMax.isBefore(DateTime.now().subtract(const Duration(days: 1)));

  bool get isExpiringSoon =>
      expiry.isNotEmpty && !isExpired && expiryOrMax.difference(DateTime.now()).inDays <= 3;

  bool get isLowStock => minQuantity > 0 && quantity <= minQuantity;

  int get statusRank {
    if (isExpired) return 0;
    if (isExpiringSoon) return 1;
    if (isLowStock) return 2;
    return 3;
  }

  double get defaultStep {
    final normalized = unit.toLowerCase();
    if (normalized == 'g' ||
        normalized == 'gram' ||
        normalized == 'ml' ||
        normalized == '克' ||
        normalized == '毫升') {
      return 50;
    }
    if (normalized == 'kg' ||
        normalized == 'l' ||
        normalized == '公斤' ||
        normalized == '千克' ||
        normalized == '升') {
      return 0.5;
    }
    return 1;
  }

  String get quantityLabel => '${formatNumber(quantity)}$unit';
  String get minQuantityLabel => '${formatNumber(minQuantity)}$unit';

  String get statusDescription {
    if (isExpired) {
      return expiry.isEmpty ? '已过期' : '已过期 · $expiry';
    }
    if (isExpiringSoon) {
      return expiry.isEmpty ? '快到期' : '快到期 · 建议在 $expiry 前用完';
    }
    if (isLowStock) {
      return '库存不足';
    }
    return expiry.isEmpty ? '可正常使用' : '建议在 $expiry 前食用';
  }

  static String formatNumber(double value) {
    return value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
  }

  static double _parseDouble(Object? value) {
    return double.tryParse((value ?? '0').toString().trim()) ?? 0;
  }
}
