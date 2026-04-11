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
      unit: ((json['unit'] ?? 'item').toString().trim().isEmpty ? 'item' : json['unit'].toString().trim()),
      category: ((json['category'] ?? 'Other').toString().trim().isEmpty ? 'Other' : json['category'].toString().trim()),
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
      throw Exception('Name is required.');
    }
    final quantity = _parseDouble(quantityText);
    if (quantity <= 0) {
      throw Exception('Quantity must be greater than zero.');
    }
    final minQuantity = _parseDouble(minQuantityText);
    if (minQuantity < 0) {
      throw Exception('Threshold cannot be negative.');
    }
    final cleanExpiry = expiry.trim();
    if (cleanExpiry.isNotEmpty && DateTime.tryParse(cleanExpiry) == null) {
      throw Exception('Expiry must use YYYY-MM-DD.');
    }
    return InventoryItem(
      id: base?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: cleanName,
      quantity: quantity,
      unit: unit.trim().isEmpty ? 'item' : unit.trim(),
      category: category.trim().isEmpty ? 'Other' : category.trim(),
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
    if (normalized == 'g' || normalized == 'gram' || normalized == 'ml') {
      return 50;
    }
    if (normalized == 'kg' || normalized == 'l') {
      return 0.5;
    }
    return 1;
  }

  String get quantityLabel => '${formatNumber(quantity)} $unit';
  String get minQuantityLabel => '${formatNumber(minQuantity)} $unit';

  String get statusDescription {
    if (isExpired) {
      return expiry.isEmpty ? 'Expired' : 'Expired on $expiry';
    }
    if (isExpiringSoon) {
      return 'Due soon${expiry.isEmpty ? '' : ' | $expiry'}';
    }
    if (isLowStock) {
      return 'Low stock';
    }
    return expiry.isEmpty ? 'Normal' : 'Normal | Expires $expiry';
  }

  static String formatNumber(double value) {
    return value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
  }

  static double _parseDouble(Object? value) {
    return double.tryParse((value ?? '0').toString().trim()) ?? 0;
  }
}
