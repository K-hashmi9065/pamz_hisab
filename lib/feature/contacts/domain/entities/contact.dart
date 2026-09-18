/// Contact domain entity representing a Buyer (Grahak) or Supplier (Bypari).
class Contact {
  const Contact({
    required this.id,
    required this.type,
    required this.name,
    required this.mobileNumber,
    this.address,
    this.villageTola,
    this.shopLocation,
    this.creditLimit = 0,
    this.dueDateAlertEnabled = false,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
  });

  final String id;
  final ContactType type;
  final String name;
  final String mobileNumber;
  final String? address;
  final String? villageTola;
  final String? shopLocation;
  final double creditLimit;
  final bool dueDateAlertEnabled;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

  bool get isBuyer => type == ContactType.buyer;
  bool get isSupplier => type == ContactType.supplier;

  Contact copyWith({
    String? id,
    ContactType? type,
    String? name,
    String? mobileNumber,
    String? address,
    String? villageTola,
    String? shopLocation,
    double? creditLimit,
    bool? dueDateAlertEnabled,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
  }) {
    return Contact(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      address: address ?? this.address,
      villageTola: villageTola ?? this.villageTola,
      shopLocation: shopLocation ?? this.shopLocation,
      creditLimit: creditLimit ?? this.creditLimit,
      dueDateAlertEnabled: dueDateAlertEnabled ?? this.dueDateAlertEnabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Contact &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Contact(id: $id, type: $type, name: $name, mobileNumber: $mobileNumber)';
}

enum ContactType {
  buyer,
  supplier,
}
