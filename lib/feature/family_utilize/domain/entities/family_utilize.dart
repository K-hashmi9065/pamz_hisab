import 'package:flutter/material.dart';

/// Entity representing a Family/Personal utilization of available funds.
class FamilyUtilize {
  const FamilyUtilize({
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
  final String transactionDate; // 'YYYY-MM-DD'
  final String? paymentMode;
  final String? paymentReference;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

  FamilyUtilize copyWith({
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
    return FamilyUtilize(
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

  /// Preset categories for Family Utilization
  static const List<FamilyCategoryPreset> presetCategories = [
    FamilyCategoryPreset(
        name: 'Education', icon: Icons.school_rounded, color: Color(0xFF3F51B5)),
    FamilyCategoryPreset(
        name: 'Electricity', icon: Icons.bolt_rounded, color: Color(0xFFFF9800)),
    FamilyCategoryPreset(
        name: 'Medical',
        icon: Icons.local_hospital_rounded,
        color: Color(0xFFE91E63)),
    FamilyCategoryPreset(
        name: 'Grocery',
        icon: Icons.shopping_cart_rounded,
        color: Color(0xFF4CAF50)),
    FamilyCategoryPreset(
        name: 'House Expense',
        icon: Icons.home_rounded,
        color: Color(0xFF795548)),
    FamilyCategoryPreset(
        name: 'Travel',
        icon: Icons.directions_car_rounded,
        color: Color(0xFF00BCD4)),
    FamilyCategoryPreset(
        name: 'Food',
        icon: Icons.restaurant_rounded,
        color: Color(0xFFFF5722)),
    FamilyCategoryPreset(
        name: 'Maintenance',
        icon: Icons.build_rounded,
        color: Color(0xFF607D8B)),
    FamilyCategoryPreset(
        name: 'Other',
        icon: Icons.category_rounded,
        color: Color(0xFF9E9E9E)),
  ];

  static FamilyCategoryPreset getCategoryPreset(String categoryName) {
    return presetCategories.firstWhere(
      (c) => c.name.toLowerCase() == categoryName.toLowerCase(),
      orElse: () => const FamilyCategoryPreset(
        name: 'Other',
        icon: Icons.category_rounded,
        color: Color(0xFF9E9E9E),
      ),
    );
  }
}

class FamilyCategoryPreset {
  const FamilyCategoryPreset({
    required this.name,
    required this.icon,
    required this.color,
  });

  final String name;
  final IconData icon;
  final Color color;
}
