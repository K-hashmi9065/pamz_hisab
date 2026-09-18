/// Entity representing an income or expense transaction in Family Finance.
class FamilyTransaction {
  const FamilyTransaction({
    required this.id,
    required this.type, // 'income' or 'expense'
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
  final String type; // 'income' | 'expense'
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

  bool get isIncome => type == 'income';
  bool get isExpense => type == 'expense';

  FamilyTransaction copyWith({
    String? id,
    String? type,
    double? amount,
    String? categoryId,
    String? categoryName,
    String? categoryIcon,
    String? categoryColor,
    String? accountId,
    String? accountName,
    String? sourceTag,
    String? receiptPhotoPath,
    DateTime? transactionDate,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
  }) {
    return FamilyTransaction(
      id: id ?? this.id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      categoryIcon: categoryIcon ?? this.categoryIcon,
      categoryColor: categoryColor ?? this.categoryColor,
      accountId: accountId ?? this.accountId,
      accountName: accountName ?? this.accountName,
      sourceTag: sourceTag ?? this.sourceTag,
      receiptPhotoPath: receiptPhotoPath ?? this.receiptPhotoPath,
      transactionDate: transactionDate ?? this.transactionDate,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}

/// Entity representing a Category (preset or custom).
class TransactionCategory {
  const TransactionCategory({
    required this.id,
    required this.domain, // 'income' | 'expense'
    required this.name,
    this.parentCategoryId,
    this.iconKey,
    this.colorHex,
    this.isSystemPreset = false,
    this.sortOrder = 0,
    this.isDeleted = false,
  });

  final String id;
  final String domain;
  final String name;
  final String? parentCategoryId;
  final String? iconKey;
  final String? colorHex;
  final bool isSystemPreset;
  final int sortOrder;
  final bool isDeleted;

  TransactionCategory copyWith({
    String? id,
    String? domain,
    String? name,
    String? parentCategoryId,
    String? iconKey,
    String? colorHex,
    bool? isSystemPreset,
    int? sortOrder,
    bool? isDeleted,
  }) {
    return TransactionCategory(
      id: id ?? this.id,
      domain: domain ?? this.domain,
      name: name ?? this.name,
      parentCategoryId: parentCategoryId ?? this.parentCategoryId,
      iconKey: iconKey ?? this.iconKey,
      colorHex: colorHex ?? this.colorHex,
      isSystemPreset: isSystemPreset ?? this.isSystemPreset,
      sortOrder: sortOrder ?? this.sortOrder,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}

/// Entity representing a payment Account (Cash or Bank).
class Account {
  const Account({
    required this.id,
    required this.name,
    required this.type, // 'cash' | 'bank'
    this.isDeleted = false,
  });

  final String id;
  final String name;
  final String type;
  final bool isDeleted;
}
