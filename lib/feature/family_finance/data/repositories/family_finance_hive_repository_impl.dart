import 'package:fpdart/fpdart.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/db/hive/hive_registrar.dart';
import '../../../../core/error/error_mapper.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/utils/app_date_utils.dart';
import '../../domain/entities/category_budget.dart';
import '../../domain/entities/family_transaction.dart';
import '../../domain/repositories/family_finance_repository.dart';
import '../models/category_budget_model.dart';
import '../models/family_transaction_model.dart';

/// Hive implementation of FamilyFinanceRepository.
class FamilyFinanceHiveRepositoryImpl implements FamilyFinanceRepository {
  const FamilyFinanceHiveRepositoryImpl();

  @override
  Future<Either<Failure, List<FamilyTransaction>>> getTransactions(
      {String? type}) async {
    try {
      final txnBox = HiveRegistrar.familyTransactionsBox;
      final catBox = HiveRegistrar.categoriesBox;
      final accBox = HiveRegistrar.accountsBox;

      final List<FamilyTransaction> list = [];

      for (final key in txnBox.keys) {
        final data = txnBox.get(key);
        if (data is Map) {
          final map = Map<String, dynamic>.from(data);
          final isDeleted = (map['is_deleted'] as int? ?? 0) == 1;
          if (!isDeleted) {
            if (type == null || map['type'] == type) {
              // Join category
              final catId = map['category_id'] as String?;
              if (catId != null) {
                final catData = catBox.get(catId);
                if (catData is Map) {
                  map['category_name'] = catData['name'];
                  map['icon_key'] = catData['icon_key'];
                  map['color_hex'] = catData['color_hex'];
                }
              }

              // Join account
              final accId = map['account_id'] as String?;
              if (accId != null) {
                final accData = accBox.get(accId);
                if (accData is Map) {
                  map['account_name'] = accData['name'];
                }
              }

              list.add(FamilyTransactionModel.fromMap(map).toEntity());
            }
          }
        }
      }

      list.sort((a, b) {
        final dateCmp = b.transactionDate.compareTo(a.transactionDate);
        if (dateCmp != 0) return dateCmp;
        return b.createdAt.compareTo(a.createdAt);
      });

      return right(list);
    } catch (e, st) {
      return left(ErrorMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, FamilyTransaction>> addTransaction(
      FamilyTransaction transaction) async {
    try {
      final now = DateTime.now();
      final id = transaction.id.isEmpty ? const Uuid().v4() : transaction.id;
      final model = FamilyTransactionModel.fromEntity(
        transaction.copyWith(id: id, createdAt: now, updatedAt: now),
      );

      final box = HiveRegistrar.familyTransactionsBox;
      await box.put(id, model.toMap());

      // Audit Log
      await HiveRegistrar.auditLogBox.put(const Uuid().v4(), {
        'id': const Uuid().v4(),
        'entity_type': 'family_transactions',
        'entity_id': id,
        'action': 'create',
        'changed_fields_json':
            '{"type":"${model.type}","amount":${model.amount},"category_id":"${model.categoryId}"}',
        'performed_at': AppDateUtils.toIso(now),
      });

      // Update monthly summary
      await _upsertSummary(model.transactionDate, model.type, model.categoryId, model.amount);

      // Populate joined names
      String? categoryName;
      String? iconKey;
      String? colorHex;
      final catData = HiveRegistrar.categoriesBox.get(model.categoryId);
      if (catData is Map) {
        categoryName = catData['name'] as String?;
        iconKey = catData['icon_key'] as String?;
        colorHex = catData['color_hex'] as String?;
      }

      String? accountName;
      if (model.accountId != null) {
        final accData = HiveRegistrar.accountsBox.get(model.accountId);
        if (accData is Map) {
          accountName = accData['name'] as String?;
        }
      }

      return right(
        model.toEntity().copyWith(
          categoryName: categoryName,
          categoryIcon: iconKey,
          categoryColor: colorHex,
          accountName: accountName,
        ),
      );
    } catch (e, st) {
      return left(ErrorMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, FamilyTransaction>> updateTransaction(
      FamilyTransaction transaction) async {
    try {
      final now = DateTime.now();
      final model = FamilyTransactionModel.fromEntity(
        transaction.copyWith(updatedAt: now),
      );

      final box = HiveRegistrar.familyTransactionsBox;

      // 1. Fetch previous transaction state to adjust monthly_summary
      final existingData = box.get(transaction.id);
      if (existingData is Map) {
        final prevDateStr = existingData['transaction_date'] as String?;
        final prevDate = prevDateStr != null
            ? DateTime.tryParse(prevDateStr) ?? model.transactionDate
            : model.transactionDate;
        final prevType = existingData['type'] as String? ?? model.type;
        final prevCatId = existingData['category_id'] as String? ?? model.categoryId;
        final prevAmount = (existingData['amount'] as num?)?.toDouble() ?? 0.0;

        // Subtract previous amounts
        await _adjustSummary(prevDate, prevType, prevCatId, -prevAmount);
      }

      // 2. Put updated transaction
      await box.put(transaction.id, model.toMap());

      // 3. Add new amounts to monthly_summary
      await _adjustSummary(model.transactionDate, model.type, model.categoryId, model.amount);

      // 4. Audit Log
      await HiveRegistrar.auditLogBox.put(const Uuid().v4(), {
        'id': const Uuid().v4(),
        'entity_type': 'family_transactions',
        'entity_id': transaction.id,
        'action': 'update',
        'changed_fields_json':
            '{"type":"${model.type}","amount":${model.amount},"category_id":"${model.categoryId}"}',
        'performed_at': AppDateUtils.toIso(now),
      });

      // Populate joined names
      String? categoryName;
      String? iconKey;
      String? colorHex;
      final catData = HiveRegistrar.categoriesBox.get(model.categoryId);
      if (catData is Map) {
        categoryName = catData['name'] as String?;
        iconKey = catData['icon_key'] as String?;
        colorHex = catData['color_hex'] as String?;
      }

      String? accountName;
      if (model.accountId != null) {
        final accData = HiveRegistrar.accountsBox.get(model.accountId);
        if (accData is Map) {
          accountName = accData['name'] as String?;
        }
      }

      return right(
        model.toEntity().copyWith(
          categoryName: categoryName,
          categoryIcon: iconKey,
          categoryColor: colorHex,
          accountName: accountName,
        ),
      );
    } catch (e, st) {
      return left(ErrorMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, void>> deleteTransaction(String id) async {
    try {
      final box = HiveRegistrar.familyTransactionsBox;
      final data = box.get(id);
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        final dateStr = map['transaction_date'] as String?;
        final date = dateStr != null
            ? DateTime.tryParse(dateStr) ?? DateTime.now()
            : DateTime.now();
        final type = map['type'] as String? ?? 'expense';
        final catId = map['category_id'] as String? ?? '';
        final amount = (map['amount'] as num?)?.toDouble() ?? 0.0;

        // Subtract deleted amounts from monthly_summary
        await _adjustSummary(date, type, catId, -amount);

        map['is_deleted'] = 1;
        map['updated_at'] = AppDateUtils.toIso(DateTime.now());
        await box.put(id, map);

        await HiveRegistrar.auditLogBox.put(const Uuid().v4(), {
          'id': const Uuid().v4(),
          'entity_type': 'family_transactions',
          'entity_id': id,
          'action': 'delete',
          'changed_fields_json': null,
          'performed_at': AppDateUtils.toIso(DateTime.now()),
        });
      }
      return right(null);
    } catch (e, st) {
      return left(ErrorMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, List<TransactionCategory>>> getCategories(
      {String? domain}) async {
    try {
      final box = HiveRegistrar.categoriesBox;
      final List<TransactionCategory> list = [];

      for (final key in box.keys) {
        final data = box.get(key);
        if (data is Map) {
          final map = Map<String, dynamic>.from(data);
          final isDeleted = (map['is_deleted'] as int? ?? 0) == 1;
          if (!isDeleted) {
            if (domain == null || map['domain'] == domain) {
              list.add(
                TransactionCategory(
                  id: map['id'] as String,
                  domain: map['domain'] as String,
                  name: map['name'] as String,
                  parentCategoryId: map['parent_category_id'] as String?,
                  iconKey: map['icon_key'] as String?,
                  colorHex: map['color_hex'] as String?,
                  isSystemPreset: (map['is_system_preset'] as int? ?? 0) == 1,
                  sortOrder: map['sort_order'] as int? ?? 0,
                  isDeleted: (map['is_deleted'] as int? ?? 0) == 1,
                ),
              );
            }
          }
        }
      }

      list.sort((a, b) {
        final orderCmp = a.sortOrder.compareTo(b.sortOrder);
        if (orderCmp != 0) return orderCmp;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      return right(list);
    } catch (e, st) {
      return left(ErrorMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, TransactionCategory>> createCategory(
      TransactionCategory category) async {
    try {
      final box = HiveRegistrar.categoriesBox;
      final nameTrimmed = category.name.trim();

      // Check duplicate
      for (final key in box.keys) {
        final data = box.get(key);
        if (data is Map) {
          final isDeleted = (data['is_deleted'] as int? ?? 0) == 1;
          if (!isDeleted && data['domain'] == category.domain) {
            final existingName = (data['name'] as String?)?.trim();
            if (existingName != null &&
                existingName.toLowerCase() == nameTrimmed.toLowerCase()) {
              return left(ValidationFailure(
                message: 'A category named "$nameTrimmed" already exists in ${category.domain}.',
                field: 'name',
              ));
            }
          }
        }
      }

      final now = DateTime.now();
      final id = category.id.isEmpty ? const Uuid().v4() : category.id;
      final savedCategory = category.copyWith(id: id, name: nameTrimmed);

      await box.put(id, {
        'id': id,
        'domain': savedCategory.domain,
        'name': savedCategory.name,
        'parent_category_id': savedCategory.parentCategoryId,
        'icon_key': savedCategory.iconKey,
        'color_hex': savedCategory.colorHex,
        'is_system_preset': savedCategory.isSystemPreset ? 1 : 0,
        'sort_order': savedCategory.sortOrder,
        'is_deleted': 0,
      });

      await HiveRegistrar.auditLogBox.put(const Uuid().v4(), {
        'id': const Uuid().v4(),
        'entity_type': 'categories',
        'entity_id': id,
        'action': 'create',
        'changed_fields_json': '{"name":"${savedCategory.name}","domain":"${savedCategory.domain}"}',
        'performed_at': AppDateUtils.toIso(now),
      });

      return right(savedCategory);
    } catch (e, st) {
      return left(ErrorMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, TransactionCategory>> updateCategory(
      TransactionCategory category) async {
    try {
      final box = HiveRegistrar.categoriesBox;
      final nameTrimmed = category.name.trim();

      // Check duplicate
      for (final key in box.keys) {
        final data = box.get(key);
        if (data is Map) {
          final isDeleted = (data['is_deleted'] as int? ?? 0) == 1;
          final existingId = data['id'] as String?;
          if (!isDeleted && data['domain'] == category.domain && existingId != category.id) {
            final existingName = (data['name'] as String?)?.trim();
            if (existingName != null &&
                existingName.toLowerCase() == nameTrimmed.toLowerCase()) {
              return left(ValidationFailure(
                message: 'Another category named "$nameTrimmed" already exists in ${category.domain}.',
                field: 'name',
              ));
            }
          }
        }
      }

      final now = DateTime.now();
      final updated = category.copyWith(name: nameTrimmed);

      final existingData = box.get(category.id);
      final isPreset = existingData is Map ? (existingData['is_system_preset'] as int? ?? 0) : (category.isSystemPreset ? 1 : 0);

      await box.put(category.id, {
        'id': category.id,
        'domain': updated.domain,
        'name': updated.name,
        'parent_category_id': updated.parentCategoryId,
        'icon_key': updated.iconKey,
        'color_hex': updated.colorHex,
        'is_system_preset': isPreset,
        'sort_order': updated.sortOrder,
        'is_deleted': 0,
      });

      await HiveRegistrar.auditLogBox.put(const Uuid().v4(), {
        'id': const Uuid().v4(),
        'entity_type': 'categories',
        'entity_id': category.id,
        'action': 'update',
        'changed_fields_json': '{"name":"${updated.name}","domain":"${updated.domain}"}',
        'performed_at': AppDateUtils.toIso(now),
      });

      return right(updated);
    } catch (e, st) {
      return left(ErrorMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, void>> deleteCategory(String id) async {
    try {
      final box = HiveRegistrar.categoriesBox;
      final data = box.get(id);
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        map['is_deleted'] = 1;
        await box.put(id, map);

        await HiveRegistrar.auditLogBox.put(const Uuid().v4(), {
          'id': const Uuid().v4(),
          'entity_type': 'categories',
          'entity_id': id,
          'action': 'delete',
          'changed_fields_json': null,
          'performed_at': AppDateUtils.toIso(DateTime.now()),
        });
      }
      return right(null);
    } catch (e, st) {
      return left(ErrorMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, List<CategoryBudget>>> getBudgets(
      {int? year, int? month}) async {
    try {
      final box = HiveRegistrar.budgetsBox;
      final catBox = HiveRegistrar.categoriesBox;
      final List<CategoryBudget> list = [];

      final targetMonthKey = (year != null && month != null)
          ? '$year-${month.toString().padLeft(2, '0')}'
          : null;

      for (final key in box.keys) {
        final data = box.get(key);
        if (data is Map) {
          final map = Map<String, dynamic>.from(data);
          final isDeleted = (map['is_deleted'] as int? ?? 0) == 1;
          if (!isDeleted) {
            final monthStr = map['month'] as String?;
            if (targetMonthKey == null || monthStr == targetMonthKey) {
              final catId = map['category_id'] as String?;
              if (catId != null) {
                final catData = catBox.get(catId);
                if (catData is Map) {
                  map['category_name'] = catData['name'];
                  map['icon_key'] = catData['icon_key'];
                  map['color_hex'] = catData['color_hex'];
                }
              }
              list.add(CategoryBudgetModel.fromMap(map).toEntity());
            }
          }
        }
      }

      list.sort((a, b) {
        final monthCmp = b.monthKey.compareTo(a.monthKey);
        if (monthCmp != 0) return monthCmp;
        return (a.categoryName ?? '').compareTo(b.categoryName ?? '');
      });

      return right(list);
    } catch (e, st) {
      return left(ErrorMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, CategoryBudget>> createBudget(
      CategoryBudget budget) async {
    try {
      final catBox = HiveRegistrar.categoriesBox;
      final catData = catBox.get(budget.categoryId);
      if (catData is! Map ||
          catData['domain'] != 'expense' ||
          (catData['is_deleted'] as int? ?? 0) == 1) {
        return left(const ValidationFailure(
          message: 'Budgets can only be created for active expense categories.',
          field: 'categoryId',
        ));
      }

      final box = HiveRegistrar.budgetsBox;
      final monthKey = budget.monthKey;

      for (final key in box.keys) {
        final data = box.get(key);
        if (data is Map) {
          final isDeleted = (data['is_deleted'] as int? ?? 0) == 1;
          if (!isDeleted &&
              data['category_id'] == budget.categoryId &&
              data['month'] == monthKey) {
            return left(const ValidationFailure(
              message: 'A budget for this category and month already exists.',
              field: 'categoryId',
            ));
          }
        }
      }

      final now = DateTime.now();
      final id = budget.id.isEmpty ? const Uuid().v4() : budget.id;
      final model = CategoryBudgetModel.fromEntity(
        budget.copyWith(id: id, createdAt: now, updatedAt: now),
      );

      await box.put(id, model.toMap());

      await HiveRegistrar.auditLogBox.put(const Uuid().v4(), {
        'id': const Uuid().v4(),
        'entity_type': 'budgets',
        'entity_id': id,
        'action': 'create',
        'changed_fields_json':
            '{"category_id":"${model.categoryId}","month":"${model.toMap()['month']}","limit_amount":${model.monthlyLimit}}',
        'performed_at': AppDateUtils.toIso(now),
      });

      return right(
        model.toEntity().copyWith(
          categoryName: catData['name'] as String?,
          categoryIcon: catData['icon_key'] as String?,
          categoryColor: catData['color_hex'] as String?,
        ),
      );
    } catch (e, st) {
      return left(ErrorMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, CategoryBudget>> updateBudget(
      CategoryBudget budget) async {
    try {
      final box = HiveRegistrar.budgetsBox;
      final monthKey = budget.monthKey;

      for (final key in box.keys) {
        final data = box.get(key);
        if (data is Map) {
          final isDeleted = (data['is_deleted'] as int? ?? 0) == 1;
          final existingId = data['id'] as String?;
          if (!isDeleted &&
              data['category_id'] == budget.categoryId &&
              data['month'] == monthKey &&
              existingId != budget.id) {
            return left(const ValidationFailure(
              message: 'Another budget for this category and month already exists.',
              field: 'categoryId',
            ));
          }
        }
      }

      final now = DateTime.now();
      final model = CategoryBudgetModel.fromEntity(
        budget.copyWith(updatedAt: now),
      );

      await box.put(budget.id, model.toMap());

      await HiveRegistrar.auditLogBox.put(const Uuid().v4(), {
        'id': const Uuid().v4(),
        'entity_type': 'budgets',
        'entity_id': budget.id,
        'action': 'update',
        'changed_fields_json':
            '{"limit_amount":${model.monthlyLimit},"alert_threshold_percent":${model.thresholdPercentage}}',
        'performed_at': AppDateUtils.toIso(now),
      });

      String? catName;
      String? catIcon;
      String? catColor;
      final catData = HiveRegistrar.categoriesBox.get(model.categoryId);
      if (catData is Map) {
        catName = catData['name'] as String?;
        catIcon = catData['icon_key'] as String?;
        catColor = catData['color_hex'] as String?;
      }

      return right(
        model.toEntity().copyWith(
          categoryName: catName,
          categoryIcon: catIcon,
          categoryColor: catColor,
        ),
      );
    } catch (e, st) {
      return left(ErrorMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, void>> deleteBudget(String id) async {
    try {
      final box = HiveRegistrar.budgetsBox;
      final data = box.get(id);
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        map['is_deleted'] = 1;
        map['updated_at'] = AppDateUtils.toIso(DateTime.now());
        await box.put(id, map);

        await HiveRegistrar.auditLogBox.put(const Uuid().v4(), {
          'id': const Uuid().v4(),
          'entity_type': 'budgets',
          'entity_id': id,
          'action': 'delete',
          'changed_fields_json': null,
          'performed_at': AppDateUtils.toIso(DateTime.now()),
        });
      }
      return right(null);
    } catch (e, st) {
      return left(ErrorMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, List<BudgetCalculation>>> getBudgetCalculations(
      int year, int month) async {
    try {
      final budgetsRes = await getBudgets(year: year, month: month);
      if (budgetsRes.isLeft()) return left(budgetsRes.getLeft().toNullable()!);
      final budgets = budgetsRes.getOrElse((_) => []);

      final start = DateTime(year, month, 1);
      final end = DateTime(year, month + 1, 0, 23, 59, 59);

      final txnBox = HiveRegistrar.familyTransactionsBox;
      final expenseMap = <String, double>{};

      for (final key in txnBox.keys) {
        final data = txnBox.get(key);
        if (data is Map) {
          final isDeleted = (data['is_deleted'] as int? ?? 0) == 1;
          final type = data['type'] as String?;
          if (!isDeleted && type == 'expense') {
            final dateStr = data['transaction_date'] as String?;
            if (dateStr != null) {
              final date = DateTime.tryParse(dateStr);
              if (date != null && !date.isBefore(start) && !date.isAfter(end)) {
                final catId = data['category_id'] as String?;
                if (catId != null) {
                  final amt = (data['amount'] as num?)?.toDouble() ?? 0.0;
                  expenseMap[catId] = (expenseMap[catId] ?? 0.0) + amt;
                }
              }
            }
          }
        }
      }

      final calculations = budgets.map((b) {
        final actual = expenseMap[b.categoryId] ?? 0.0;
        return BudgetCalculation.calculate(budget: b, actualExpense: actual);
      }).toList();

      return right(calculations);
    } catch (e, st) {
      return left(ErrorMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, List<Account>>> getAccounts() async {
    try {
      final box = HiveRegistrar.accountsBox;
      final List<Account> list = [];

      for (final key in box.keys) {
        final data = box.get(key);
        if (data is Map) {
          final map = Map<String, dynamic>.from(data);
          final isDeleted = (map['is_deleted'] as int? ?? 0) == 1;
          if (!isDeleted) {
            list.add(
              Account(
                id: map['id'] as String,
                name: map['name'] as String,
                type: map['type'] as String,
                isDeleted: (map['is_deleted'] as int? ?? 0) == 1,
              ),
            );
          }
        }
      }

      return right(list);
    } catch (e, st) {
      return left(ErrorMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, double>> getTotalIncomeForMonth(DateTime month) async {
    try {
      final start = DateTime(month.year, month.month, 1);
      final end = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

      final box = HiveRegistrar.familyTransactionsBox;
      double total = 0.0;

      for (final key in box.keys) {
        final data = box.get(key);
        if (data is Map) {
          final map = Map<String, dynamic>.from(data);
          final isDeleted = (map['is_deleted'] as int? ?? 0) == 1;
          final type = map['type'] as String?;
          if (!isDeleted && type == 'income') {
            final dateStr = map['transaction_date'] as String?;
            if (dateStr != null) {
              final date = DateTime.tryParse(dateStr);
              if (date != null && !date.isBefore(start) && !date.isAfter(end)) {
                total += (map['amount'] as num?)?.toDouble() ?? 0.0;
              }
            }
          }
        }
      }

      return right(total);
    } catch (e, st) {
      return left(ErrorMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, double>> getTotalExpenseForMonth(DateTime month) async {
    try {
      final start = DateTime(month.year, month.month, 1);
      final end = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

      final box = HiveRegistrar.familyTransactionsBox;
      double total = 0.0;

      for (final key in box.keys) {
        final data = box.get(key);
        if (data is Map) {
          final map = Map<String, dynamic>.from(data);
          final isDeleted = (map['is_deleted'] as int? ?? 0) == 1;
          final type = map['type'] as String?;
          if (!isDeleted && type == 'expense') {
            final dateStr = map['transaction_date'] as String?;
            if (dateStr != null) {
              final date = DateTime.tryParse(dateStr);
              if (date != null && !date.isBefore(start) && !date.isAfter(end)) {
                total += (map['amount'] as num?)?.toDouble() ?? 0.0;
              }
            }
          }
        }
      }

      return right(total);
    } catch (e, st) {
      return left(ErrorMapper.map(e, st));
    }
  }

  Future<void> _adjustSummary(
    DateTime date,
    String type,
    String categoryId,
    double delta,
  ) async {
    final month = AppDateUtils.toMonthKey(date);
    final box = HiveRegistrar.monthlySummaryBox;
    final isIncome = type == 'income';

    Map<String, dynamic> summary = {};
    dynamic targetKey;
    for (final key in box.keys) {
      final data = box.get(key);
      if (data is Map && data['month'] == month && data['category_id'] == categoryId) {
        summary = Map<String, dynamic>.from(data);
        targetKey = key;
        break;
      }
    }

    final id = summary['id'] as String? ?? (targetKey?.toString() ?? const Uuid().v4());
    final currentIncome = (summary['total_income'] as num?)?.toDouble() ?? 0.0;
    final currentExpense = (summary['total_expense'] as num?)?.toDouble() ?? 0.0;

    final newIncome = isIncome ? (currentIncome + delta).clamp(0.0, double.infinity) : currentIncome;
    final newExpense = isIncome ? currentExpense : (currentExpense + delta).clamp(0.0, double.infinity);

    await box.put(targetKey ?? id, {
      'id': id,
      'month': month,
      'category_id': categoryId,
      'total_income': newIncome,
      'total_expense': newExpense,
    });
  }

  Future<void> _upsertSummary(
    DateTime date,
    String type,
    String categoryId,
    double amount,
  ) => _adjustSummary(date, type, categoryId, amount);
}
