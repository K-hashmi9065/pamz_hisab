/// Fund Ledger Contact — domain entity.
///
/// Business fields are exactly: name, mobileNumber, aadhaarNumber (optional),
/// project (optional). No address, email, company or other fields.
class FLContact {
  const FLContact({
    required this.id,
    required this.name,
    required this.mobileNumber,
    this.aadhaarNumber,
    this.project,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
  });

  final String id;
  final String name;
  final String mobileNumber;

  /// Optional — stored as String, never treated as numeric.
  final String? aadhaarNumber;

  /// Optional free-text project label.
  final String? project;

  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

  FLContact copyWith({
    String? id,
    String? name,
    String? mobileNumber,
    String? aadhaarNumber,
    String? project,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
  }) {
    return FLContact(
      id: id ?? this.id,
      name: name ?? this.name,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      aadhaarNumber: aadhaarNumber ?? this.aadhaarNumber,
      project: project ?? this.project,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FLContact &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'FLContact(id: $id, name: $name, mobile: $mobileNumber)';
}
