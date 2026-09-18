import 'package:flutter_test/flutter_test.dart';
import 'package:pamz_khata/core/db/sqlite/app_database.dart';
import 'package:pamz_khata/core/db/sqlite/database_helper.dart';
import 'package:pamz_khata/feature/family_finance/data/repositories/family_finance_repository_impl.dart';
import 'package:pamz_khata/feature/family_finance/domain/entities/category_budget.dart';
import 'package:pamz_khata/feature/family_finance/domain/entities/family_transaction.dart';
import 'package:pamz_khata/feature/family_finance/domain/usecases/budget_usecases.dart';
import 'package:pamz_khata/feature/family_finance/domain/usecases/family_finance_usecases.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('GAP-INT02 — Family Finance + Budget Propagation Cross-Layer Integration Tests', () {
    late Database sqliteDb;
    late DatabaseHelper dbHelper;
    late FamilyFinanceRepositoryImpl repo;
    late CreateCategoryUsecase createCategoryUsecase;
    late AddFamilyTransactionUsecase addTxnUsecase;
    late UpdateFamilyTransactionUsecase updateTxnUsecase;
    late DeleteFamilyTransactionUsecase deleteTxnUsecase;
    late CreateBudgetUsecase createBudgetUsecase;
    late GetBudgetCalculationsUsecase getBudgetCalculationsUsecase;

    setUp(() async {
      sqliteDb = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE categories (
              id TEXT PRIMARY KEY,
              domain TEXT NOT NULL,
              name TEXT NOT NULL,
              parent_category_id TEXT,
              icon_key TEXT,
              color_hex TEXT,
              is_system_preset INTEGER DEFAULT 0,
              sort_order INTEGER DEFAULT 0,
              is_deleted INTEGER DEFAULT 0
            );
          ''');
          await db.execute('''
            CREATE TABLE accounts (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              type TEXT NOT NULL,
              is_deleted INTEGER DEFAULT 0
            );
          ''');
          await db.execute('''
            CREATE TABLE family_transactions (
              id TEXT PRIMARY KEY,
              type TEXT NOT NULL,
              amount REAL NOT NULL,
              category_id TEXT NOT NULL,
              account_id TEXT,
              source_tag TEXT,
              receipt_photo_path TEXT,
              transaction_date TEXT NOT NULL,
              notes TEXT,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL,
              is_deleted INTEGER DEFAULT 0
            );
          ''');
          await db.execute('''
            CREATE TABLE budgets (
              id                      TEXT PRIMARY KEY,
              category_id             TEXT NOT NULL,
              month                   TEXT NOT NULL,
              limit_amount            REAL NOT NULL,
              alert_threshold_percent REAL NOT NULL DEFAULT 80.0,
              created_at              TEXT NOT NULL,
              updated_at              TEXT NOT NULL,
              is_deleted              INTEGER NOT NULL DEFAULT 0
            );
          ''');
          await db.execute('''
            CREATE UNIQUE INDEX idx_budget_category_month
              ON budgets(category_id, month) WHERE is_deleted = 0;
          ''');
          await db.execute('''
            CREATE TABLE monthly_summary (
              id                   TEXT PRIMARY KEY,
              month                TEXT NOT NULL,
              category_id          TEXT,
              total_income         REAL DEFAULT 0,
              total_expense        REAL DEFAULT 0,
              total_udhar_given    REAL DEFAULT 0,
              total_udhar_received REAL DEFAULT 0
            );
          ''');
          await db.execute('''
            CREATE UNIQUE INDEX idx_summary_month_category
              ON monthly_summary(month, category_id);
          ''');
          await db.execute('''
            CREATE TABLE audit_log (
              id                  TEXT PRIMARY KEY,
              entity_type         TEXT NOT NULL,
              entity_id           TEXT NOT NULL,
              action              TEXT NOT NULL,
              changed_fields_json TEXT,
              performed_at        TEXT NOT NULL
            );
          ''');
        },
      );

      AppDatabase.instance.overrideForTesting(sqliteDb);
      dbHelper = DatabaseHelper(AppDatabase.instance);
      repo = FamilyFinanceRepositoryImpl(dbHelper);

      createCategoryUsecase = CreateCategoryUsecase(repo);
      addTxnUsecase = AddFamilyTransactionUsecase(repo);
      updateTxnUsecase = UpdateFamilyTransactionUsecase(repo);
      deleteTxnUsecase = DeleteFamilyTransactionUsecase(repo);
      createBudgetUsecase = CreateBudgetUsecase(repo);
      getBudgetCalculationsUsecase = GetBudgetCalculationsUsecase(repo);
    });

    tearDown(() async {
      await AppDatabase.instance.close();
    });

    test('Complete Family Finance & Budget Lifecycle: Category -> Budget -> Expense Entry -> 85% Threshold Alert -> Update -> Delete', () async {
      const budgetYear = 2026;
      const budgetMonth = 3;

      // ───────────────────────────────────────────────────────────────────────
      // 1. Setup Expense Category: Groceries & Ration
      // ───────────────────────────────────────────────────────────────────────
      const category = TransactionCategory(
        id: 'cat-groceries',
        domain: 'expense',
        name: 'Groceries & Ration',
        iconKey: '🛒',
        colorHex: '#4CAF50',
      );

      final catResult = await createCategoryUsecase(category);
      expect(catResult.isRight(), isTrue);

      final queriedCategoriesRes = await repo.getCategories(domain: 'expense');
      expect(queriedCategoriesRes.isRight(), isTrue);
      final categories = queriedCategoriesRes.getOrElse((_) => []);
      expect(categories.any((c) => c.id == 'cat-groceries' && c.name == 'Groceries & Ration'), isTrue);

      // ───────────────────────────────────────────────────────────────────────
      // 2. Create Monthly Budget (Limit: ₹10,000, Alert Threshold: 80%)
      // ───────────────────────────────────────────────────────────────────────
      final budgetInput = CategoryBudget(
        id: 'budget-int-001',
        categoryId: 'cat-groceries',
        monthlyLimit: 10000.0,
        thresholdPercentage: 80.0,
        year: budgetYear,
        month: budgetMonth,
        createdAt: DateTime(2026, 3, 1),
        updatedAt: DateTime(2026, 3, 1),
      );

      final budgetResult = await createBudgetUsecase(budgetInput);
      expect(budgetResult.isRight(), isTrue);

      // Verify budget in SQLite
      final queriedBudgetsRes = await repo.getBudgets(year: budgetYear, month: budgetMonth);
      expect(queriedBudgetsRes.isRight(), isTrue);
      final budgets = queriedBudgetsRes.getOrElse((_) => []);
      expect(budgets.length, 1);
      expect(budgets.first.monthlyLimit, 10000.0);
      expect(budgets.first.thresholdPercentage, 80.0);

      // Initial budget calculation: 0 spent, 0% usage, threshold not reached
      final initialCalcRes = await getBudgetCalculationsUsecase(budgetYear, budgetMonth);
      expect(initialCalcRes.isRight(), isTrue);
      final initialCalcs = initialCalcRes.getOrElse((_) => []);
      expect(initialCalcs.length, 1);
      expect(initialCalcs.first.actualExpense, 0.0);
      expect(initialCalcs.first.remainingAmount, 10000.0);
      expect(initialCalcs.first.usagePercentage, 0.0);
      expect(initialCalcs.first.isThresholdReached, isFalse);
      expect(initialCalcs.first.isExceeded, isFalse);

      // ───────────────────────────────────────────────────────────────────────
      // 3. Add Expense: ₹8,500 (85% of limit -> should trigger threshold alert)
      // ───────────────────────────────────────────────────────────────────────
      final expenseTxn = FamilyTransaction(
        id: 'txn-int-exp-1',
        type: 'expense',
        amount: 8500.0,
        categoryId: 'cat-groceries',
        transactionDate: DateTime(2026, 3, 5, 11, 0),
        notes: 'Monthly food grain supplies',
        createdAt: DateTime(2026, 3, 5, 11, 0),
        updatedAt: DateTime(2026, 3, 5, 11, 0),
      );

      final addResult = await addTxnUsecase(expenseTxn);
      expect(addResult.isRight(), isTrue);

      // Verify transaction persisted in SQLite
      final transactionsRes = await repo.getTransactions(type: 'expense');
      expect(transactionsRes.isRight(), isTrue);
      final transactions = transactionsRes.getOrElse((_) => []);
      expect(transactions.length, 1);
      expect(transactions.first.amount, 8500.0);
      expect(transactions.first.categoryName, 'Groceries & Ration');

      // Verify monthly total expense in SQLite
      final expenseTotalRes = await repo.getTotalExpenseForMonth(DateTime(budgetYear, budgetMonth, 1));
      expect(expenseTotalRes.isRight(), isTrue);
      expect(expenseTotalRes.getOrElse((_) => -1.0), 8500.0);

      // ───────────────────────────────────────────────────────────────────────
      // 4. Verify Budget Calculation reflects 85% and threshold warning
      // ───────────────────────────────────────────────────────────────────────
      final calcAfterExpenseRes = await getBudgetCalculationsUsecase(budgetYear, budgetMonth);
      expect(calcAfterExpenseRes.isRight(), isTrue);
      final calcsAfterExpense = calcAfterExpenseRes.getOrElse((_) => []);
      expect(calcsAfterExpense.length, 1);

      final calc1 = calcsAfterExpense.first;
      expect(calc1.actualExpense, 8500.0);
      expect(calc1.remainingAmount, 1500.0);
      expect(calc1.usagePercentage, 85.0);
      expect(calc1.isThresholdReached, isTrue); // 85% >= 80% threshold
      expect(calc1.isExceeded, isFalse);

      // ───────────────────────────────────────────────────────────────────────
      // 5. Edit Transaction: Lower amount to ₹5,000 (50% usage -> threshold clears)
      // ───────────────────────────────────────────────────────────────────────
      final updatedTxn = expenseTxn.copyWith(
        amount: 5000.0,
        notes: 'Adjusted monthly supplies invoice',
      );

      final updateResult = await updateTxnUsecase(updatedTxn);
      expect(updateResult.isRight(), isTrue);

      // Verify updated monthly total in SQLite
      final expenseTotalAfterUpdateRes = await repo.getTotalExpenseForMonth(DateTime(budgetYear, budgetMonth, 1));
      expect(expenseTotalAfterUpdateRes.isRight(), isTrue);
      expect(expenseTotalAfterUpdateRes.getOrElse((_) => -1.0), 5000.0);

      // Verify recalculation reflects 50%
      final calcAfterUpdateRes = await getBudgetCalculationsUsecase(budgetYear, budgetMonth);
      final calc2 = calcAfterUpdateRes.getOrElse((_) => []).first;
      expect(calc2.actualExpense, 5000.0);
      expect(calc2.remainingAmount, 5000.0);
      expect(calc2.usagePercentage, 50.0);
      expect(calc2.isThresholdReached, isFalse); // 50% < 80%

      // ───────────────────────────────────────────────────────────────────────
      // 6. Delete Transaction: Soft delete restores budget and summary to 0
      // ───────────────────────────────────────────────────────────────────────
      final deleteResult = await deleteTxnUsecase('txn-int-exp-1');
      expect(deleteResult.isRight(), isTrue);

      // Active transactions in SQLite must now be empty
      final activeTxnsRes = await repo.getTransactions(type: 'expense');
      expect(activeTxnsRes.getOrElse((_) => []).isEmpty, isTrue);

      // Monthly total expense must reflect 0
      final expenseTotalAfterDeleteRes = await repo.getTotalExpenseForMonth(DateTime(budgetYear, budgetMonth, 1));
      expect(expenseTotalAfterDeleteRes.isRight(), isTrue);
      expect(expenseTotalAfterDeleteRes.getOrElse((_) => -1.0), 0.0);

      // Budget calculation returns to 0
      final calcAfterDeleteRes = await getBudgetCalculationsUsecase(budgetYear, budgetMonth);
      final calc3 = calcAfterDeleteRes.getOrElse((_) => []).first;
      expect(calc3.actualExpense, 0.0);
      expect(calc3.remainingAmount, 10000.0);
      expect(calc3.usagePercentage, 0.0);
      expect(calc3.isThresholdReached, isFalse);
    });
  });
}
