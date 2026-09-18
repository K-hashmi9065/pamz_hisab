import '../../../../core/utils/app_date_utils.dart';
import '../../domain/entities/category_budget.dart';

class CategoryBudgetModel {
  const CategoryBudgetModel({
    required this.id,
    required this.categoryId,
    this.categoryName,
    this.categoryIcon,
    this.categoryColor,
    required this.monthlyLimit,
    this.thresholdPercentage = 80.0,
    required this.year,
    required this.month,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
  });

  final String id;
  final String categoryId;
  final String? categoryName;
  final String? categoryIcon;
  final String? categoryColor;
  final double monthlyLimit;
  final double thresholdPercentage;
  final int year;
  final int month;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

  factory CategoryBudgetModel.fromMap(Map<String, dynamic> map) {
    // Parse year and month from 'month' string "YYYY-MM" or separate columns
    int y = DateTime.now().year;
    int m = DateTime.now().month;

    if (map['year'] is int && map['month_num'] is int) {
      y = map['year'] as int;
      m = map['month_num'] as int;
    } else if (map['month'] is String) {
      final parts = (map['month'] as String).split('-');
      if (parts.length == 2) {
        y = int.tryParse(parts[0]) ?? y;
        m = int.tryParse(parts[1]) ?? m;
      }
    }

    DateTime created = DateTime.now();
    DateTime updated = DateTime.now();
    if (map['created_at'] is String) {
      created = DateTime.tryParse(map['created_at'] as String) ?? created;
    }
    if (map['updated_at'] is String) {
      updated = DateTime.tryParse(map['updated_at'] as String) ?? updated;
    }

    return CategoryBudgetModel(
      id: map['id'] as String,
      categoryId: map['category_id'] as String,
      categoryName: map['category_name'] as String?,
      categoryIcon: map['icon_key'] as String?,
      categoryColor: map['color_hex'] as String?,
      monthlyLimit: (map['limit_amount'] as num?)?.toDouble() ?? 0.0,
      thresholdPercentage:
          (map['alert_threshold_percent'] as num?)?.toDouble() ?? 80.0,
      year: map['year'] as int? ?? y,
      month: map['month_num'] as int? ?? m,
      createdAt: created,
      updatedAt: updated,
      isDeleted: (map['is_deleted'] as int? ?? 0) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    final monthKey = '$year-${month.toString().padLeft(2, '0')}';
    return {
      'id': id,
      'category_id': categoryId,
      'month': monthKey,
      'limit_amount': monthlyLimit,
      'alert_threshold_percent': thresholdPercentage,
      'created_at': AppDateUtils.toIso(createdAt),
      'updated_at': AppDateUtils.toIso(updatedAt),
      'is_deleted': isDeleted ? 1 : 0,
    };
  }

  CategoryBudget toEntity() {
    return CategoryBudget(
      id: id,
      categoryId: categoryId,
      categoryName: categoryName,
      categoryIcon: categoryIcon,
      categoryColor: categoryColor,
      monthlyLimit: monthlyLimit,
      thresholdPercentage: thresholdPercentage,
      year: year,
      month: month,
      createdAt: createdAt,
      updatedAt: updatedAt,
      isDeleted: isDeleted,
    );
  }

  factory CategoryBudgetModel.fromEntity(CategoryBudget entity) {
    return CategoryBudgetModel(
      id: entity.id,
      categoryId: entity.categoryId,
      categoryName: entity.categoryName,
      categoryIcon: entity.categoryIcon,
      categoryColor: entity.categoryColor,
      monthlyLimit: entity.monthlyLimit,
      thresholdPercentage: entity.thresholdPercentage,
      year: entity.year,
      month: entity.month,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      isDeleted: entity.isDeleted,
    );
  }
}
