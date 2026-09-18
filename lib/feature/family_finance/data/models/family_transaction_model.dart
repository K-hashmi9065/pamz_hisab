import '../../../../core/utils/app_date_utils.dart';
import '../../domain/entities/family_transaction.dart';

class FamilyTransactionModel {
  const FamilyTransactionModel({
    required this.id,
    required this.type,
    required this.amount,
    required this.categoryId,
    this.categoryName,
    this.categoryIcon,
    this.categoryColor,
    this.accountId,
    this.accountName,
    this.sourceTag,
    this.receiptPhotoPath,
    required this.transactionDate,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
  });

  final String id;
  final String type;
  final double amount;
  final String categoryId;
  final String? categoryName;
  final String? categoryIcon;
  final String? categoryColor;
  final String? accountId;
  final String? accountName;
  final String? sourceTag;
  final String? receiptPhotoPath;
  final DateTime transactionDate;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

  factory FamilyTransactionModel.fromMap(Map<String, dynamic> map) {
    return FamilyTransactionModel(
      id: map['id'] as String,
      type: map['type'] as String,
      amount: (map['amount'] as num).toDouble(),
      categoryId: map['category_id'] as String,
      categoryName: map['category_name'] as String?,
      categoryIcon: map['icon_key'] as String?,
      categoryColor: map['color_hex'] as String?,
      accountId: map['account_id'] as String?,
      accountName: map['account_name'] as String?,
      sourceTag: map['source_tag'] as String?,
      receiptPhotoPath: map['receipt_photo_path'] as String?,
      transactionDate: DateTime.parse(map['transaction_date'] as String),
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      isDeleted: (map['is_deleted'] as int? ?? 0) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'amount': amount,
      'category_id': categoryId,
      'account_id': accountId,
      'source_tag': sourceTag,
      'receipt_photo_path': receiptPhotoPath,
      'transaction_date': AppDateUtils.toIso(transactionDate),
      'notes': notes,
      'created_at': AppDateUtils.toIso(createdAt),
      'updated_at': AppDateUtils.toIso(updatedAt),
      'is_deleted': isDeleted ? 1 : 0,
    };
  }

  FamilyTransaction toEntity() {
    return FamilyTransaction(
      id: id,
      type: type,
      amount: amount,
      categoryId: categoryId,
      categoryName: categoryName,
      categoryIcon: categoryIcon,
      categoryColor: categoryColor,
      accountId: accountId,
      accountName: accountName,
      sourceTag: sourceTag,
      receiptPhotoPath: receiptPhotoPath,
      transactionDate: transactionDate,
      notes: notes,
      createdAt: createdAt,
      updatedAt: updatedAt,
      isDeleted: isDeleted,
    );
  }

  factory FamilyTransactionModel.fromEntity(FamilyTransaction entity) {
    return FamilyTransactionModel(
      id: entity.id,
      type: entity.type,
      amount: entity.amount,
      categoryId: entity.categoryId,
      categoryName: entity.categoryName,
      categoryIcon: entity.categoryIcon,
      categoryColor: entity.categoryColor,
      accountId: entity.accountId,
      accountName: entity.accountName,
      sourceTag: entity.sourceTag,
      receiptPhotoPath: entity.receiptPhotoPath,
      transactionDate: entity.transactionDate,
      notes: entity.notes,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      isDeleted: entity.isDeleted,
    );
  }
}
