/// Authoritative transaction types for the Fund Ledger.
///
/// Use these enum values everywhere — do NOT scatter raw strings.
enum FLTransactionType {
  received,
  utilized,
  returned;

  /// Serializes to the DB column value.
  String get dbValue => name; // 'received' | 'utilized' | 'returned'

  /// Parses from a DB column string. Throws if unknown.
  static FLTransactionType fromDb(String value) {
    return FLTransactionType.values.firstWhere(
      (t) => t.dbValue == value,
      orElse: () => throw ArgumentError('Unknown FLTransactionType: $value'),
    );
  }

  /// Human-readable label for UI display.
  String get label {
    switch (this) {
      case FLTransactionType.received:
        return 'Received';
      case FLTransactionType.utilized:
        return 'Utilized';
      case FLTransactionType.returned:
        return 'Returned';
    }
  }
}

/// A single Fund Ledger transaction entry.
///
/// - [paymentMode] and [paymentReference] apply to received/returned only.
/// - [title] and [description] apply to utilized transactions.
/// - [note] is an optional general note for any type.
class FLTransaction {
  const FLTransaction({
    required this.id,
    required this.contactId,
    required this.type,
    required this.amount,
    required this.txnDate,
    this.txnTime,
    this.paymentMode,
    this.paymentReference,
    this.title,
    this.description,
    this.note,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
  });

  final String id;
  final String contactId;
  final FLTransactionType type;
  final double amount;

  /// ISO date string: 'yyyy-MM-dd'
  final String txnDate;

  /// Optional time string: 'HH:mm'
  final String? txnTime;

  // Received / Returned fields
  final String? paymentMode;
  final String? paymentReference;

  // Utilized fields
  final String? title;
  final String? description;

  // General optional note
  final String? note;

  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

  FLTransaction copyWith({
    String? id,
    String? contactId,
    FLTransactionType? type,
    double? amount,
    String? txnDate,
    String? txnTime,
    String? paymentMode,
    String? paymentReference,
    String? title,
    String? description,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
  }) {
    return FLTransaction(
      id: id ?? this.id,
      contactId: contactId ?? this.contactId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      txnDate: txnDate ?? this.txnDate,
      txnTime: txnTime ?? this.txnTime,
      paymentMode: paymentMode ?? this.paymentMode,
      paymentReference: paymentReference ?? this.paymentReference,
      title: title ?? this.title,
      description: description ?? this.description,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FLTransaction &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'FLTransaction(id: $id, type: $type, amount: $amount, contactId: $contactId)';
}
