import 'package:flutter_test/flutter_test.dart';
import 'package:pamz_khata/core/db/sqlite/app_database.dart';
import 'package:pamz_khata/core/db/sqlite/database_helper.dart';
import 'package:pamz_khata/core/error/failure.dart';
import 'package:pamz_khata/feature/family_finance/data/repositories/family_finance_repository_impl.dart';
import 'package:pamz_khata/feature/family_finance/domain/entities/category_budget.dart';
import 'package:pamz_khata/feature/family_finance/domain/entities/family_transaction.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('FamilyFinanceRepositoryImpl (SQLite) Unit Tests', () {
    late Database sqliteDb;
    late DatabaseHelper dbHelper;
    late FamilyFinanceRepositoryImpl repository;

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
              id TEXT PRIMARY KEY,
              category_id TEXT NOT NULL,
              month TEXT NOT NULL,
              limit_amount REAL NOT NULL,
              alert_threshold_percent REAL NOT NULL DEFAULT 80.0,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL,
              is_deleted INTEGER NOT NULL DEFAULT 0
            );
          ''');
          await db.execute('''
            CREATE TABLE monthly_summary (
              id TEXT PRIMARY KEY,
              month TEXT NOT NULL,
              category_id TEXT,
              total_income REAL DEFAULT 0,
              total_expense REAL DEFAULT 0,
              total_udhar_given REAL DEFAULT 0,
              total_udhar_received REAL DEFAULT 0,
              UNIQUE(month, category_id)
            );
          ''');
          await db.execute('''
            CREATE TABLE audit_log (
              id TEXT PRIMARY KEY,
              entity_type TEXT,
              entity_id TEXT,
              action TEXT,
              changed_fields_json TEXT,
              performed_at TEXT
            );
          ''');
        },
      );

      AppDatabase.instance.overrideForTesting(sqliteDb);
      dbHelper = DatabaseHelper(AppDatabase.instance);
      repository = FamilyFinanceRepositoryImpl(dbHelper);

      // Seed an initial category and account
      await sqliteDb.insert('categories', {
        'id': 'cat-exp-1',
        'domain': 'expense',
        'name': 'Groceries',
        'icon_key': '🛒',
        'color_hex': '#FF5722',
        'is_system_preset': 1,
        'sort_order': 1,
        'is_deleted': 0,
      });

      await sqliteDb.insert('categories', {
        'id': 'cat-inc-1',
        'domain': 'income',
        'name': 'Salary',
        'icon_key': '💰',
        'color_hex': '#4CAF50',
        'is_system_preset': 1,
        'sort_order': 1,
        'is_deleted': 0,
      });

      await sqliteDb.insert('accounts', {
        'id': 'acc-1',
        'name': 'Cash in Hand',
        'type': 'cash',
        'is_deleted': 0,
      });
    });

    tearDown(() async {
      await sqliteDb.close();
    });

    final now = DateTime.now();

    // ── Transaction Tests ──

    test('1. addTransaction and getTransactions fetches list with joined metadata', () async {
      final txn = FamilyTransaction(
        id: 'txn-1',
        type: 'expense',
        amount: 1500,
        categoryId: 'cat-exp-1',
        accountId: 'acc-1',
        transactionDate: now,
        notes: 'Supermarket shopping',
        createdAt: now,
        updatedAt: now,
      );

      final addRes = await repository.addTransaction(txn);
      expect(addRes.isRight(), isTrue);

      final listRes = await repository.getTransactions();
      expect(listRes.isRight(), isTrue);
      final list = listRes.getOrElse((_) => []);
      expect(list.length, 1);
      expect(list.first.amount, 1500.0);
      expect(list.first.categoryName, 'Groceries');
      expect(list.first.accountName, 'Cash in Hand');
    });

    test('2. getTransactions filtered by type returns matching records only', () async {
      final expTxn = FamilyTransaction(
        id: 'txn-exp',
        type: 'expense',
        amount: 500,
        categoryId: 'cat-exp-1',
        transactionDate: now,
        createdAt: now,
        updatedAt: now,
      );

      final incTxn = FamilyTransaction(
        id: 'txn-inc',
        type: 'income',
        amount: 25000,
        categoryId: 'cat-inc-1',
        transactionDate: now,
        createdAt: now,
        updatedAt: now,
      );

      await repository.addTransaction(expTxn);
      await repository.addTransaction(incTxn);

      final expList = (await repository.getTransactions(type: 'expense')).getOrElse((_) => []);
      expect(expList.length, 1);
      expect(expList.first.id, 'txn-exp');

      final incList = (await repository.getTransactions(type: 'income')).getOrElse((_) => []);
      expect(incList.length, 1);
      expect(incList.first.id, 'txn-inc');
    });

    test('3. updateTransaction modifies transaction amount and notes', () async {
      final txn = FamilyTransaction(
        id: 'txn-upd',
        type: 'expense',
        amount: 1000,
        categoryId: 'cat-exp-1',
        transactionDate: now,
        notes: 'Old notes',
        createdAt: now,
        updatedAt: now,
      );
      await repository.addTransaction(txn);

      final updated = txn.copyWith(amount: 1200, notes: 'Updated notes');
      final updRes = await repository.updateTransaction(updated);
      expect(updRes.isRight(), isTrue);

      final list = (await repository.getTransactions()).getOrElse((_) => []);
      expect(list.first.amount, 1200.0);
      expect(list.first.notes, 'Updated notes');
    });

    test('4. deleteTransaction soft-deletes transaction', () async {
      final txn = FamilyTransaction(
        id: 'txn-del',
        type: 'expense',
        amount: 200,
        categoryId: 'cat-exp-1',
        transactionDate: now,
        createdAt: now,
        updatedAt: now,
      );
      await repository.addTransaction(txn);

      final delRes = await repository.deleteTransaction('txn-del');
      expect(delRes.isRight(), isTrue);

      final list = (await repository.getTransactions()).getOrElse((_) => []);
      expect(list, isEmpty);
    });

    // ── Category Tests ──

    test('5. createCategory, getCategories, updateCategory, deleteCategory CRUD works', () async {
      const newCat = TransactionCategory(
        id: 'cat-custom',
        domain: 'expense',
        name: 'Dining Out',
        iconKey: '🍽️',
        colorHex: '#E91E63',
        sortOrder: 2,
      );

      final createRes = await repository.createCategory(newCat);
      expect(createRes.isRight(), isTrue);

      final allCats = (await repository.getCategories(domain: 'expense')).getOrElse((_) => []);
      expect(allCats.any((c) => c.name == 'Dining Out'), isTrue);

      // Duplicate check
      final dupRes = await repository.createCategory(newCat);
      expect(dupRes.isLeft(), isTrue);
      expect(dupRes.fold((f) => f, (_) => null), isA<ValidationFailure>());

      // Update
      final updatedCat = newCat.copyWith(name: 'Restaurants & Dining');
      final updRes = await repository.updateCategory(updatedCat);
      expect(updRes.isRight(), isTrue);

      // Delete
      final delRes = await repository.deleteCategory(newCat.id);
      expect(delRes.isRight(), isTrue);

      final afterDel = (await repository.getCategories(domain: 'expense')).getOrElse((_) => []);
      expect(afterDel.any((c) => c.id == newCat.id), isFalse);
    });

    // ── Budget Tests ──

    test('6. createBudget, getBudgets, updateBudget, deleteBudget CRUD and validation works', () async {
      final budget = CategoryBudget(
        id: 'bud-1',
        categoryId: 'cat-exp-1',
        year: 2026,
        month: 5,
        monthlyLimit: 15000,
        thresholdPercentage: 85.0,
        createdAt: now,
        updatedAt: now,
      );

      final createRes = await repository.createBudget(budget);
      expect(createRes.isRight(), isTrue);

      final list = (await repository.getBudgets(year: 2026, month: 5)).getOrElse((_) => []);
      expect(list.length, 1);
      expect(list.first.monthlyLimit, 15000.0);
      expect(list.first.categoryName, 'Groceries');

      // Duplicate budget for same category and month
      final dupRes = await repository.createBudget(budget);
      expect(dupRes.isLeft(), isTrue);

      // Budget for income category rejected
      final incomeBudget = CategoryBudget(
        id: 'bud-inc',
        categoryId: 'cat-inc-1',
        year: 2026,
        month: 5,
        monthlyLimit: 10000,
        createdAt: now,
        updatedAt: now,
      );
      final incRes = await repository.createBudget(incomeBudget);
      expect(incRes.isLeft(), isTrue);

      // Update budget limit
      final updated = budget.copyWith(monthlyLimit: 18000);
      final updRes = await repository.updateBudget(updated);
      expect(updRes.isRight(), isTrue);

      // Delete budget
      final delRes = await repository.deleteBudget(budget.id);
      expect(delRes.isRight(), isTrue);

      final afterList = (await repository.getBudgets(year: 2026, month: 5)).getOrElse((_) => []);
      expect(afterList, isEmpty);
    });

    // ── Account Tests ──

    test('7. getAccounts returns accounts list', () async {
      final listRes = await repository.getAccounts();
      expect(listRes.isRight(), isTrue);
      final list = listRes.getOrElse((_) => []);
      expect(list.length, 1);
      expect(list.first.name, 'Cash in Hand');
      expect(list.first.type, 'cash');
    });

    // ── Budget Calculations & Monthly Totals Tests ──

    test('8. getBudgetCalculations, getTotalIncomeForMonth, getTotalExpenseForMonth compute totals accurately', () async {
      final targetMonth = DateTime(2026, 5, 1);

      // Create budget
      await repository.createBudget(CategoryBudget(
        id: 'bud-calc',
        categoryId: 'cat-exp-1',
        year: 2026,
        month: 5,
        monthlyLimit: 10000,
        thresholdPercentage: 80.0,
        createdAt: now,
        updatedAt: now,
      ));

      // Add income
      await repository.addTransaction(FamilyTransaction(
        id: 'txn-inc-calc',
        type: 'income',
        amount: 40000,
        categoryId: 'cat-inc-1',
        transactionDate: DateTime(2026, 5, 10),
        createdAt: now,
        updatedAt: now,
      ));

      // Add expense (8500 spent against 10000 limit = 85%, exceeds 80% threshold)
      await repository.addTransaction(FamilyTransaction(
        id: 'txn-exp-calc',
        type: 'expense',
        amount: 8500,
        categoryId: 'cat-exp-1',
        transactionDate: DateTime(2026, 5, 12),
        createdAt: now,
        updatedAt: now,
      ));

      final totalIncomeRes = await repository.getTotalIncomeForMonth(targetMonth);
      expect(totalIncomeRes.isRight(), isTrue);
      expect(totalIncomeRes.getOrElse((_) => 0), 40000.0);

      final totalExpenseRes = await repository.getTotalExpenseForMonth(targetMonth);
      expect(totalExpenseRes.isRight(), isTrue);
      expect(totalExpenseRes.getOrElse((_) => 0), 8500.0);

      final calculationsRes = await repository.getBudgetCalculations(2026, 5);
      expect(calculationsRes.isRight(), isTrue);
      final calcs = calculationsRes.getOrElse((_) => []);
      expect(calcs.length, 1);
      expect(calcs.first.actualExpense, 8500.0);
      expect(calcs.first.remainingAmount, 1500.0);
      expect(calcs.first.isThresholdReached, isTrue);
      expect(calcs.first.isExceeded, isFalse);
    });

    // ── Monthly Summary Aggregation Regression Tests (Phase 4.2 / 4.4) ──

    test('9. monthly_summary adjusts accurately on amount update in same month', () async {
      final txn = FamilyTransaction(
        id: 'txn-sum-1',
        type: 'expense',
        amount: 1000,
        categoryId: 'cat-exp-1',
        transactionDate: DateTime(2026, 6, 15),
        createdAt: now,
        updatedAt: now,
      );
      await repository.addTransaction(txn);

      // Verify initial summary
      final initialRows = await sqliteDb.query(
        'monthly_summary',
        where: 'month = ? AND category_id = ?',
        whereArgs: ['2026-06', 'cat-exp-1'],
      );
      expect(initialRows.first['total_expense'], 1000.0);

      // Update amount: 1000 -> 1500
      final updated = txn.copyWith(amount: 1500);
      await repository.updateTransaction(updated);

      final updatedRows = await sqliteDb.query(
        'monthly_summary',
        where: 'month = ? AND category_id = ?',
        whereArgs: ['2026-06', 'cat-exp-1'],
      );
      expect(updatedRows.first['total_expense'], 1500.0);
    });

    test('10. monthly_summary adjusts accurately when transaction moved to another month', () async {
      final txn = FamilyTransaction(
        id: 'txn-month-move',
        type: 'income',
        amount: 20000,
        categoryId: 'cat-inc-1',
        transactionDate: DateTime(2026, 7, 10),
        createdAt: now,
        updatedAt: now,
      );
      await repository.addTransaction(txn);

      // Move from July to August
      final updated = txn.copyWith(transactionDate: DateTime(2026, 8, 10));
      await repository.updateTransaction(updated);

      final julyRows = await sqliteDb.query(
        'monthly_summary',
        where: 'month = ? AND category_id = ?',
        whereArgs: ['2026-07', 'cat-inc-1'],
      );
      expect(julyRows.first['total_income'], 0.0);

      final augustRows = await sqliteDb.query(
        'monthly_summary',
        where: 'month = ? AND category_id = ?',
        whereArgs: ['2026-08', 'cat-inc-1'],
      );
      expect(augustRows.first['total_income'], 20000.0);
    });

    test('11. monthly_summary adjusts on type change (income <-> expense)', () async {
      final txn = FamilyTransaction(
        id: 'txn-type-switch',
        type: 'income',
        amount: 5000,
        categoryId: 'cat-inc-1',
        transactionDate: DateTime(2026, 9, 1),
        createdAt: now,
        updatedAt: now,
      );
      await repository.addTransaction(txn);

      // Switch to expense with expense category
      final updated = txn.copyWith(type: 'expense', categoryId: 'cat-exp-1');
      await repository.updateTransaction(updated);

      final incSummary = await sqliteDb.query(
        'monthly_summary',
        where: 'month = ? AND category_id = ?',
        whereArgs: ['2026-09', 'cat-inc-1'],
      );
      expect(incSummary.first['total_income'], 0.0);

      final expSummary = await sqliteDb.query(
        'monthly_summary',
        where: 'month = ? AND category_id = ?',
        whereArgs: ['2026-09', 'cat-exp-1'],
      );
      expect(expSummary.first['total_expense'], 5000.0);
    });

    test('12. update followed by soft-delete cleanly returns summary to zero without negative values', () async {
      final txn = FamilyTransaction(
        id: 'txn-upd-del',
        type: 'expense',
        amount: 3000,
        categoryId: 'cat-exp-1',
        transactionDate: DateTime(2026, 10, 5),
        createdAt: now,
        updatedAt: now,
      );
      await repository.addTransaction(txn);

      // Update 3000 -> 4500
      await repository.updateTransaction(txn.copyWith(amount: 4500));

      var summary = await sqliteDb.query(
        'monthly_summary',
        where: 'month = ? AND category_id = ?',
        whereArgs: ['2026-10', 'cat-exp-1'],
      );
      expect(summary.first['total_expense'], 4500.0);

      // Soft delete
      await repository.deleteTransaction(txn.id);

      summary = await sqliteDb.query(
        'monthly_summary',
        where: 'month = ? AND category_id = ?',
        whereArgs: ['2026-10', 'cat-exp-1'],
      );
      expect(summary.first['total_expense'], 0.0);
    });
  });
}
