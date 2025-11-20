class Item {
  final String id;
  final String fridgeId;
  final String name;
  final String? barcode;
  final double? quantity;
  final String? unit;
  final DateTime? expiresOn;
  final String? addedBy;
  final DateTime? addedAt;
  final String? notes;

  Item({
    required this.id,
    required this.fridgeId,
    required this.name,
    this.barcode,
    this.quantity,
    this.unit,
    this.expiresOn,
    this.addedBy,
    this.addedAt,
    this.notes,
  });

  factory Item.fromMap(Map<String, dynamic> map) {
    return Item(
      id: map['id'] as String,
      fridgeId: map['fridge_id'] as String,
      name: map['name'] as String,
      barcode: map['barcode'] as String?,
      quantity: map['quantity'] == null
          ? null
          : (map['quantity'] as num).toDouble(),
      unit: map['unit'] as String?,
      expiresOn: map['expires_on'] == null
          ? null
          : DateTime.parse(map['expires_on'] as String),
      addedBy: map['added_by'] as String?,
      addedAt: map['added_at'] == null
          ? null
          : DateTime.parse(map['added_at'] as String),
      notes: map['notes'] as String?,
    );
  }

  /// For inserts/updates
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fridge_id': fridgeId,
      'name': name,
      'barcode': barcode,
      'quantity': quantity,
      'unit': unit,
      'expires_on': expiresOn?.toIso8601String(),
      'added_by': addedBy,
      // don't usually send added_at, let DB default handle it
      'notes': notes,
    };
  }

  Item copyWith({
    String? id,
    String? fridgeId,
    String? name,
    String? barcode,
    double? quantity,
    String? unit,
    DateTime? expiresOn,
    String? addedBy,
    DateTime? addedAt,
    String? notes,
  }) {
    return Item(
      id: id ?? this.id,
      fridgeId: fridgeId ?? this.fridgeId,
      name: name ?? this.name,
      barcode: barcode ?? this.barcode,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      expiresOn: expiresOn ?? this.expiresOn,
      addedBy: addedBy ?? this.addedBy,
      addedAt: addedAt ?? this.addedAt,
      notes: notes ?? this.notes,
    );
  }
}
