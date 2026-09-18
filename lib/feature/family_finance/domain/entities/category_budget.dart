/// Entity representing a monthly expense Category Budget (FR-FE-003).
class CategoryBudget {
  const CategoryBudget({
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
  final double thresholdPercentage; // e.g. 80.0%
  final int year;
  final int month; // 1 to 12
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

  String get monthKey => '$year-${month.toString().padLeft(2, '0')}';

  CategoryBudget copyWith({
    String? id,
    String? categoryId,
    String? categoryName,
    String? categoryIcon,
    String? categoryColor,
    double? monthlyLimit,
    double? thresholdPercentage,
    int? year,
    int? month,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
  }) {
    return CategoryBudget(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      categoryIcon: categoryIcon ?? this.categoryIcon,
      categoryColor: categoryColor ?? this.categoryColor,
      monthlyLimit: monthlyLimit ?? this.monthlyLimit,
      thresholdPercentage: thresholdPercentage ?? this.thresholdPercentage,
      year: year ?? this.year,
      month: month ?? this.month,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}

/// Domain calculation model representing actual expense vs budget limits.
class BudgetCalculation {
  const BudgetCalculation({
    required this.budget,
    required this.actualExpense,
    required this.remainingAmount,
    required this.usagePercentage,
    required this.isThresholdReached,
    required this.isExceeded,
  });

  final CategoryBudget budget;
  final double actualExpense;
  final double remainingAmount;
  final double usagePercentage;
  final bool isThresholdReached;
  final bool isExceeded;

  factory BudgetCalculation.calculate({
    required CategoryBudget budget,
    required double actualExpense,
  }) {
    final remaining = budget.monthlyLimit - actualExpense;
    final usage = budget.monthlyLimit > 0
        ? (actualExpense / budget.monthlyLimit) * 100
        : 0.0;
    final thresholdReached = usage >= budget.thresholdPercentage;
    final exceeded = actualExpense > budget.monthlyLimit;

    return BudgetCalculation(
      budget: budget,
      actualExpense: actualExpense,
      remainingAmount: remaining,
      usagePercentage: usage,
      isThresholdReached: thresholdReached,
      isExceeded: exceeded,
    );
  }
}
