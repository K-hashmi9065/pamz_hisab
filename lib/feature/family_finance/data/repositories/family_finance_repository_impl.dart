import 'package:fpdart/fpdart.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/db/sqlite/database_helper.dart';
import '../../../../core/error/error_mapper.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/utils/app_date_utils.dart';
import '../../domain/entities/category_budget.dart';
import '../../domain/entities/family_transaction.dart';
import '../../domain/repositories/family_finance_repository.dart';
import '../models/category_budget_model.dart';
import '../models/family_transaction_model.dart';

class FamilyFinanceRepositoryImpl implements FamilyFinanceRepository {
  const FamilyFinanceRepositoryImpl(this._db);
  final DatabaseHelper _db;

  static const _txnTable = 'family_transactions';
  static const _categoriesTable = 'categories';
  static const _accountsTable = 'accounts';
  static const _budgetsTable = 'budgets';
  static const _summaryTable = 'monthly_summary';
  static const _auditTable = 'audit_log';

  @override
  Future<Either<Failure, List<FamilyTransaction>>> getTransactions(
      {String? type}) async {
    try {
      final whereClause = type != null
          ? 'ft.is_deleted = 0 AND ft.type = ?'
          : 'ft.is_deleted = 0';
      final whereArgs = type != null ? [type] : <dynamic>[];

      final rows = await _db.rawQuery('''
        SELECT ft.*, 
               c.name AS category_name, 
               c.icon_key, 
               c.color_hex, 
               a.name AS account_name
        FROM $_txnTable ft
        LEFT JOIN $_categoriesTable c ON ft.category_id = c.id
        LEFT JOIN $_accountsTable a ON ft.account_id = a.id
        WHERE $whereClause
        ORDER BY ft.transaction_date DESC, ft.created_at DESC
      ''', whereArgs);

      final list = rows
          .map((r) => FamilyTransactionModel.fromMap(r).toEntity())
          .toList();
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

      await _db.runInTransaction((txn) async {
        await txn.insert(_txnTable, model.toMap());

        // Audit log
        await txn.insert(_auditTable, {
          'id': const Uuid().v4(),
          'entity_type': 'family_transactions',
          'entity_id': id,
          'action': 'create',
          'changed_fields_json':
              '{"type":"${model.type}","amount":${model.amount},"category_id":"${model.categoryId}"}',
          'performed_at': AppDateUtils.toIso(now),
        });

        // Update monthly_summary
        final monthKey = AppDateUtils.toMonthKey(model.transactionDate);
        final isIncome = model.type == 'income';
        await txn.rawInsert('''
          INSERT INTO $_summaryTable (id, month, category_id, total_income, total_expense)
          VALUES (?, ?, ?, ?, ?)
          ON CONFLICT(month, category_id) DO UPDATE SET
            total_income = total_income + excluded.total_income,
            total_expense = total_expense + excluded.total_expense
        ''', [
          const Uuid().v4(),
          monthKey,
          model.categoryId,
          isIncome ? model.amount : 0,
          isIncome ? 0 : model.amount,
        ]);
      });

      return right(model.toEntity());
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

      await _db.runInTransaction((txn) async {
        // 1. Fetch previous transaction state to adjust monthly_summary
        final prevRows = await txn.query(
          _txnTable,
          where: 'id = ?',
          whereArgs: [transaction.id],
          limit: 1,
        );
        if (prevRows.isNotEmpty) {
          final prevMap = prevRows.first;
          final prevDate = DateTime.tryParse(prevMap['transaction_date'] as String? ?? '') ?? model.transactionDate;
          final prevMonthKey = AppDateUtils.toMonthKey(prevDate);
          final prevCatId = prevMap['category_id'] as String;
          final prevAmount = (prevMap['amount'] as num).toDouble();
          final prevIsIncome = prevMap['type'] == 'income';

          // Subtract previous amounts from summary
          await txn.rawUpdate('''
            UPDATE $_summaryTable
            SET total_income = MAX(0, total_income - ?),
                total_expense = MAX(0, total_expense - ?)
            WHERE month = ? AND category_id = ?
          ''', [
            prevIsIncome ? prevAmount : 0.0,
            prevIsIncome ? 0.0 : prevAmount,
            prevMonthKey,
            prevCatId,
          ]);
        }

        // 2. Update transaction
        await txn.update(
          _txnTable,
          model.toMap(),
          where: 'id = ?',
          whereArgs: [transaction.id],
        );

        // 3. Add new amounts to monthly_summary
        final newMonthKey = AppDateUtils.toMonthKey(model.transactionDate);
        final isIncome = model.type == 'income';
        await txn.rawInsert('''
          INSERT INTO $_summaryTable (id, month, category_id, total_income, total_expense)
          VALUES (?, ?, ?, ?, ?)
          ON CONFLICT(month, category_id) DO UPDATE SET
            total_income = total_income + excluded.total_income,
            total_expense = total_expense + excluded.total_expense
        ''', [
          const Uuid().v4(),
          newMonthKey,
          model.categoryId,
          isIncome ? model.amount : 0.0,
          isIncome ? 0.0 : model.amount,
        ]);

        // 4. Audit log
        await txn.insert(_auditTable, {
          'id': const Uuid().v4(),
          'entity_type': 'family_transactions',
          'entity_id': transaction.id,
          'action': 'update',
          'changed_fields_json':
              '{"type":"${model.type}","amount":${model.amount},"category_id":"${model.categoryId}"}',
          'performed_at': AppDateUtils.toIso(now),
        });
      });

      return right(model.toEntity());
    } catch (e, st) {
      return left(ErrorMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, void>> deleteTransaction(String id) async {
    try {
      final now = DateTime.now();
      await _db.runInTransaction((txn) async {
        // 1. Fetch previous transaction state to adjust monthly_summary
        final prevRows = await txn.query(
          _txnTable,
          where: 'id = ?',
          whereArgs: [id],
          limit: 1,
        );
        if (prevRows.isNotEmpty) {
          final prevMap = prevRows.first;
          final prevDate = DateTime.tryParse(prevMap['transaction_date'] as String? ?? '') ?? now;
          final prevMonthKey = AppDateUtils.toMonthKey(prevDate);
          final prevCatId = prevMap['category_id'] as String;
          final prevAmount = (prevMap['amount'] as num).toDouble();
          final prevIsIncome = prevMap['type'] == 'income';

          // Subtract deleted amounts from summary
          await txn.rawUpdate('''
            UPDATE $_summaryTable
            SET total_income = MAX(0, total_income - ?),
                total_expense = MAX(0, total_expense - ?)
            WHERE month = ? AND category_id = ?
          ''', [
            prevIsIncome ? prevAmount : 0.0,
            prevIsIncome ? 0.0 : prevAmount,
            prevMonthKey,
            prevCatId,
          ]);
        }

        // 2. Soft-delete transaction
        await txn.update(
          _txnTable,
          {'is_deleted': 1, 'updated_at': AppDateUtils.toIso(now)},
          where: 'id = ?',
          whereArgs: [id],
        );

        // 3. Audit log
        await txn.insert(_auditTable, {
          'id': const Uuid().v4(),
          'entity_type': 'family_transactions',
          'entity_id': id,
          'action': 'delete',
          'changed_fields_json': null,
          'performed_at': AppDateUtils.toIso(now),
        });
      });
      return right(null);
    } catch (e, st) {
      return left(ErrorMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, List<TransactionCategory>>> getCategories(
      {String? domain}) async {
    try {
      final rows = await _db.query(
        _categoriesTable,
        where: domain != null
            ? 'domain = ? AND is_deleted = 0'
            : 'is_deleted = 0',
        whereArgs: domain != null ? [domain] : null,
        orderBy: 'sort_order ASC, name ASC',
      );
      final categories = rows
          .map(
            (r) => TransactionCategory(
              id: r['id'] as String,
              domain: r['domain'] as String,
              name: r['name'] as String,
              parentCategoryId: r['parent_category_id'] as String?,
              iconKey: r['icon_key'] as String?,
              colorHex: r['color_hex'] as String?,
              isSystemPreset: (r['is_system_preset'] as int? ?? 0) == 1,
              sortOrder: r['sort_order'] as int? ?? 0,
              isDeleted: (r['is_deleted'] as int? ?? 0) == 1,
            ),
          )
          .toList();
      return right(categories);
    } catch (e, st) {
      return left(ErrorMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, TransactionCategory>> createCategory(
      TransactionCategory category) async {
    try {
      final nameTrimmed = category.name.trim();
      final existing = await _db.rawQuery(
        'SELECT id FROM $_categoriesTable WHERE domain = ? AND LOWER(name) = LOWER(?) AND is_deleted = 0',
        [category.domain, nameTrimmed],
      );
      if (existing.isNotEmpty) {
        return left(ValidationFailure(
          message: 'A category named "$nameTrimmed" already exists in ${category.domain}.',
          field: 'name',
        ));
      }

      final now = DateTime.now();
      final id = category.id.isEmpty ? const Uuid().v4() : category.id;
      final savedCategory = category.copyWith(id: id, name: nameTrimmed);

      await _db.runInTransaction((txn) async {
        await txn.insert(_categoriesTable, {
          'id': savedCategory.id,
          'domain': savedCategory.domain,
          'name': savedCategory.name,
          'parent_category_id': savedCategory.parentCategoryId,
          'icon_key': savedCategory.iconKey,
          'color_hex': savedCategory.colorHex,
          'is_system_preset': savedCategory.isSystemPreset ? 1 : 0,
          'sort_order': savedCategory.sortOrder,
          'is_deleted': 0,
        });

        await txn.insert(_auditTable, {
          'id': const Uuid().v4(),
          'entity_type': 'categories',
          'entity_id': id,
          'action': 'create',
          'changed_fields_json': '{"name":"${savedCategory.name}","domain":"${savedCategory.domain}"}',
          'performed_at': AppDateUtils.toIso(now),
        });
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
      final nameTrimmed = category.name.trim();
      final existing = await _db.rawQuery(
        'SELECT id FROM $_categoriesTable WHERE domain = ? AND LOWER(name) = LOWER(?) AND id != ? AND is_deleted = 0',
        [category.domain, nameTrimmed, category.id],
      );
      if (existing.isNotEmpty) {
        return left(ValidationFailure(
          message: 'Another category named "$nameTrimmed" already exists in ${category.domain}.',
          field: 'name',
        ));
      }

      final now = DateTime.now();
      final updated = category.copyWith(name: nameTrimmed);

      await _db.runInTransaction((txn) async {
        await txn.update(
          _categoriesTable,
          {
            'domain': updated.domain,
            'name': updated.name,
            'parent_category_id': updated.parentCategoryId,
            'icon_key': updated.iconKey,
            'color_hex': updated.colorHex,
            'sort_order': updated.sortOrder,
          },
          where: 'id = ?',
          whereArgs: [category.id],
        );

        await txn.insert(_auditTable, {
          'id': const Uuid().v4(),
          'entity_type': 'categories',
          'entity_id': category.id,
          'action': 'update',
          'changed_fields_json': '{"name":"${updated.name}","domain":"${updated.domain}"}',
          'performed_at': AppDateUtils.toIso(now),
        });
      });

      return right(updated);
    } catch (e, st) {
      return left(ErrorMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, void>> deleteCategory(String id) async {
    try {
      final now = DateTime.now();
      await _db.runInTransaction((txn) async {
        await txn.update(
          _categoriesTable,
          {'is_deleted': 1},
          where: 'id = ?',
          whereArgs: [id],
        );

        await txn.insert(_auditTable, {
          'id': const Uuid().v4(),
          'entity_type': 'categories',
          'entity_id': id,
          'action': 'delete',
          'changed_fields_json': null,
          'performed_at': AppDateUtils.toIso(now),
        });
      });
      return right(null);
    } catch (e, st) {
      return left(ErrorMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, List<CategoryBudget>>> getBudgets(
      {int? year, int? month}) async {
    try {
      final String whereClause;
      final List<dynamic> whereArgs;

      if (year != null && month != null) {
        final monthKey = '$year-${month.toString().padLeft(2, '0')}';
        whereClause = 'b.is_deleted = 0 AND b.month = ?';
        whereArgs = [monthKey];
      } else {
        whereClause = 'b.is_deleted = 0';
        whereArgs = [];
      }

      final rows = await _db.rawQuery('''
        SELECT b.*,
               c.name AS category_name,
               c.icon_key,
               c.color_hex
        FROM $_budgetsTable b
        LEFT JOIN $_categoriesTable c ON b.category_id = c.id
        WHERE $whereClause
        ORDER BY b.month DESC, c.name ASC
      ''', whereArgs);

      final list = rows
          .map((r) => CategoryBudgetModel.fromMap(r).toEntity())
          .toList();
      return right(list);
    } catch (e, st) {
      return left(ErrorMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, CategoryBudget>> createBudget(
      CategoryBudget budget) async {
    try {
      // 1. Verify category is expense category
      final catRows = await _db.rawQuery(
        'SELECT domain FROM $_categoriesTable WHERE id = ? AND is_deleted = 0',
        [budget.categoryId],
      );
      if (catRows.isEmpty || catRows.first['domain'] != 'expense') {
        return left(const ValidationFailure(
          message: 'Budgets can only be created for active expense categories.',
          field: 'categoryId',
        ));
      }

      // 2. Prevent duplicate active budget for same category + monthKey
      final monthKey = budget.monthKey;
      final existing = await _db.rawQuery(
        'SELECT id FROM $_budgetsTable WHERE category_id = ? AND month = ? AND is_deleted = 0',
        [budget.categoryId, monthKey],
      );
      if (existing.isNotEmpty) {
        return left(const ValidationFailure(
          message: 'A budget for this category and month already exists.',
          field: 'categoryId',
        ));
      }

      final now = DateTime.now();
      final id = budget.id.isEmpty ? const Uuid().v4() : budget.id;
      final model = CategoryBudgetModel.fromEntity(
        budget.copyWith(id: id, createdAt: now, updatedAt: now),
      );

      await _db.runInTransaction((txn) async {
        await txn.insert(_budgetsTable, model.toMap());

        // Audit log
        await txn.insert(_auditTable, {
          'id': const Uuid().v4(),
          'entity_type': 'budgets',
          'entity_id': id,
          'action': 'create',
          'changed_fields_json':
              '{"category_id":"${model.categoryId}","month":"${model.toMap()['month']}","limit_amount":${model.monthlyLimit}}',
          'performed_at': AppDateUtils.toIso(now),
        });
      });

      return right(model.toEntity());
    } catch (e, st) {
      return left(ErrorMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, CategoryBudget>> updateBudget(
      CategoryBudget budget) async {
    try {
      final monthKey = budget.monthKey;
      final existing = await _db.rawQuery(
        'SELECT id FROM $_budgetsTable WHERE category_id = ? AND month = ? AND id != ? AND is_deleted = 0',
        [budget.categoryId, monthKey, budget.id],
      );
      if (existing.isNotEmpty) {
        return left(const ValidationFailure(
          message: 'Another budget for this category and month already exists.',
          field: 'categoryId',
        ));
      }

      final now = DateTime.now();
      final model = CategoryBudgetModel.fromEntity(
        budget.copyWith(updatedAt: now),
      );

      await _db.runInTransaction((txn) async {
        await txn.update(
          _budgetsTable,
          model.toMap(),
          where: 'id = ?',
          whereArgs: [budget.id],
        );

        // Audit log
        await txn.insert(_auditTable, {
          'id': const Uuid().v4(),
          'entity_type': 'budgets',
          'entity_id': budget.id,
          'action': 'update',
          'changed_fields_json':
              '{"limit_amount":${model.monthlyLimit},"alert_threshold_percent":${model.thresholdPercentage}}',
          'performed_at': AppDateUtils.toIso(now),
        });
      });

      return right(model.toEntity());
    } catch (e, st) {
      return left(ErrorMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, void>> deleteBudget(String id) async {
    try {
      final now = DateTime.now();
      await _db.runInTransaction((txn) async {
        await txn.update(
          _budgetsTable,
          {'is_deleted': 1, 'updated_at': AppDateUtils.toIso(now)},
          where: 'id = ?',
          whereArgs: [id],
        );

        await txn.insert(_auditTable, {
          'id': const Uuid().v4(),
          'entity_type': 'budgets',
          'entity_id': id,
          'action': 'delete',
          'changed_fields_json': null,
          'performed_at': AppDateUtils.toIso(now),
        });
      });
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

      final rows = await _db.rawQuery('''
        SELECT category_id, COALESCE(SUM(amount), 0) AS total_spent
        FROM $_txnTable
        WHERE type = 'expense' AND is_deleted = 0
          AND transaction_date >= ? AND transaction_date <= ?
        GROUP BY category_id
      ''', [AppDateUtils.toIso(start), AppDateUtils.toIso(end)]);

      final expenseMap = <String, double>{};
      for (final r in rows) {
        expenseMap[r['category_id'] as String] =
            (r['total_spent'] as num).toDouble();
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
      final rows = await _db.query(
        _accountsTable,
        where: 'is_deleted = 0',
      );
      final accounts = rows
          .map(
            (r) => Account(
              id: r['id'] as String,
              name: r['name'] as String,
              type: r['type'] as String,
              isDeleted: (r['is_deleted'] as int? ?? 0) == 1,
            ),
          )
          .toList();
      return right(accounts);
    } catch (e, st) {
      return left(ErrorMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, double>> getTotalIncomeForMonth(DateTime month) async {
    try {
      final start = DateTime(month.year, month.month, 1);
      final end = DateTime(month.year, month.month + 1, 0, 23, 59, 59);
      final rows = await _db.rawQuery('''
        SELECT COALESCE(SUM(amount), 0) AS total
        FROM $_txnTable
        WHERE type = 'income' AND is_deleted = 0
          AND transaction_date >= ? AND transaction_date <= ?
      ''', [AppDateUtils.toIso(start), AppDateUtils.toIso(end)]);

      return right((rows.first['total'] as num).toDouble());
    } catch (e, st) {
      return left(ErrorMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, double>> getTotalExpenseForMonth(DateTime month) async {
    try {
      final start = DateTime(month.year, month.month, 1);
      final end = DateTime(month.year, month.month + 1, 0, 23, 59, 59);
      final rows = await _db.rawQuery('''
        SELECT COALESCE(SUM(amount), 0) AS total
        FROM $_txnTable
        WHERE type = 'expense' AND is_deleted = 0
          AND transaction_date >= ? AND transaction_date <= ?
      ''', [AppDateUtils.toIso(start), AppDateUtils.toIso(end)]);

      return right((rows.first['total'] as num).toDouble());
    } catch (e, st) {
      return left(ErrorMapper.map(e, st));
    }
  }
}
