import '../../domain/entities/family_utilize.dart';

/// Database and storage model for [FamilyUtilize].
class FamilyUtilizeModel {
  const FamilyUtilizeModel({
    required this.id,
    required this.amount,
    required this.category,
    required this.title,
    this.paidTo,
    this.mobileNumber,
    this.description,
    required this.transactionDate,
    this.paymentMode,
    this.paymentReference,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
  });

  final String id;
  final double amount;
  final String category;
  final String title;
  final String? paidTo;
  final String? mobileNumber;
  final String? description;
  final String transactionDate;
  final String? paymentMode;
  final String? paymentReference;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

  factory FamilyUtilizeModel.fromEntity(FamilyUtilize entity) =>
      FamilyUtilizeModel(
        id: entity.id,
        amount: entity.amount,
        category: entity.category,
        title: entity.title,
        paidTo: entity.paidTo,
        mobileNumber: entity.mobileNumber,
        description: entity.description,
        transactionDate: entity.transactionDate,
        paymentMode: entity.paymentMode,
        paymentReference: entity.paymentReference,
        createdAt: entity.createdAt,
        updatedAt: entity.updatedAt,
        isDeleted: entity.isDeleted,
      );

  FamilyUtilize toEntity() => FamilyUtilize(
        id: id,
        amount: amount,
        category: category,
        title: title,
        paidTo: paidTo,
        mobileNumber: mobileNumber,
        description: description,
        transactionDate: transactionDate,
        paymentMode: paymentMode,
        paymentReference: paymentReference,
        createdAt: createdAt,
        updatedAt: updatedAt,
        isDeleted: isDeleted,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'amount': amount,
        'category': category,
        'title': title,
        'paid_to': paidTo,
        'mobile_number': mobileNumber,
        'description': description,
        'transaction_date': transactionDate,
        'payment_mode': paymentMode,
        'payment_reference': paymentReference,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'is_deleted': isDeleted ? 1 : 0,
      };

  factory FamilyUtilizeModel.fromMap(Map<String, dynamic> map) =>
      FamilyUtilizeModel(
        id: map['id'] as String,
        amount: (map['amount'] as num).toDouble(),
        category: map['category'] as String,
        title: map['title'] as String,
        paidTo: map['paid_to'] as String?,
        mobileNumber: map['mobile_number'] as String?,
        description: map['description'] as String?,
        transactionDate: map['transaction_date'] as String,
        paymentMode: map['payment_mode'] as String?,
        paymentReference: map['payment_reference'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
        isDeleted: (map['is_deleted'] as int? ?? 0) == 1,
      );

  FamilyUtilizeModel copyWith({
    String? id,
    double? amount,
    String? category,
    String? title,
    String? paidTo,
    String? mobileNumber,
    String? description,
    String? transactionDate,
    String? paymentMode,
    String? paymentReference,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
  }) {
    return FamilyUtilizeModel(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      title: title ?? this.title,
      paidTo: paidTo ?? this.paidTo,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      description: description ?? this.description,
      transactionDate: transactionDate ?? this.transactionDate,
      paymentMode: paymentMode ?? this.paymentMode,
      paymentReference: paymentReference ?? this.paymentReference,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}
