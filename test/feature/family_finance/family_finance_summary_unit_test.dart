import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pamz_khata/core/db/hive/hive_registrar.dart';
import 'package:pamz_khata/core/db/sqlite/app_database.dart';
import 'package:pamz_khata/core/db/sqlite/database_helper.dart';
import 'package:pamz_khata/feature/family_finance/data/repositories/family_finance_hive_repository_impl.dart';
import 'package:pamz_khata/feature/family_finance/data/repositories/family_finance_repository_impl.dart';
import 'package:pamz_khata/feature/family_finance/domain/entities/family_transaction.dart';
import 'package:pamz_khata/feature/family_finance/presentation/providers/family_finance_providers.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../test_helpers/mocks.dart';

void main() {
  setUpAll(registerFallbacks);

  group('FamilyFinanceSummary Calculation & Provider Unit Tests', () {
    late MockFamilyFinanceRepository mockRepo;

    setUp(() {
      mockRepo = MockFamilyFinanceRepository();
    });

    test('1. No transactions -> Income = 0, Expense = 0, Net = 0', () async {
      when(() => mockRepo.getTransactions(type: 'income'))
          .thenAnswer((_) async => right([]));
      when(() => mockRepo.getTransactions(type: 'expense'))
          .thenAnswer((_) async => right([]));

      final container = ProviderContainer(
        overrides: [
          familyFinanceRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );
      addTearDown(container.dispose);

      // Trigger load
      await container.read(incomeListProvider.future);
      await container.read(expenseListProvider.future);

      final summaryAsync = container.read(familyFinanceSummaryProvider);
      expect(summaryAsync, isA<AsyncData<FamilyFinanceSummary>>());

      final summary = summaryAsync.value!;
      expect(summary.totalIncome, 0.0);
      expect(summary.totalExpense, 0.0);
      expect(summary.netBalance, 0.0);
    });

    test('2. Income only -> ₹2,000 + ₹450 -> Total Income = ₹2,450, Expense = ₹0, Net = ₹2,450', () async {
      final now = DateTime(2026, 3, 10);
      final txns = [
        FamilyTransaction(
          id: 'inc-1',
          type: 'income',
          amount: 2000,
          categoryId: 'cat_sal',
          transactionDate: now,
          createdAt: now,
          updatedAt: now,
        ),
        FamilyTransaction(
          id: 'inc-2',
          type: 'income',
          amount: 450,
          categoryId: 'cat_sal',
          transactionDate: now,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      when(() => mockRepo.getTransactions(type: 'income'))
          .thenAnswer((_) async => right(txns));
      when(() => mockRepo.getTransactions(type: 'expense'))
          .thenAnswer((_) async => right([]));

      final container = ProviderContainer(
        overrides: [
          familyFinanceRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );
      addTearDown(container.dispose);

      await container.read(incomeListProvider.future);
      await container.read(expenseListProvider.future);

      final summary = container.read(familyFinanceSummaryProvider).value!;
      expect(summary.totalIncome, 2450.0);
      expect(summary.totalExpense, 0.0);
      expect(summary.netBalance, 2450.0);
    });

    test('3. Expense only -> Expense ₹500 + ₹1,000 -> Total Expense = ₹1,500, Net = -₹1,500', () async {
      final now = DateTime(2026, 3, 10);
      final txns = [
        FamilyTransaction(
          id: 'exp-1',
          type: 'expense',
          amount: 500,
          categoryId: 'cat_groc',
          transactionDate: now,
          createdAt: now,
          updatedAt: now,
        ),
        FamilyTransaction(
          id: 'exp-2',
          type: 'expense',
          amount: 1000,
          categoryId: 'cat_groc',
          transactionDate: now,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      when(() => mockRepo.getTransactions(type: 'income'))
          .thenAnswer((_) async => right([]));
      when(() => mockRepo.getTransactions(type: 'expense'))
          .thenAnswer((_) async => right(txns));

      final container = ProviderContainer(
        overrides: [
          familyFinanceRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );
      addTearDown(container.dispose);

      await container.read(incomeListProvider.future);
      await container.read(expenseListProvider.future);

      final summary = container.read(familyFinanceSummaryProvider).value!;
      expect(summary.totalIncome, 0.0);
      expect(summary.totalExpense, 1500.0);
      expect(summary.netBalance, -1500.0);
    });

    test('4. Mixed transactions -> Income ₹2,450, Expense ₹500 -> Net = ₹1,950', () async {
      final now = DateTime(2026, 3, 10);
      final incTxns = [
        FamilyTransaction(
          id: 'inc-1',
          type: 'income',
          amount: 2450,
          categoryId: 'cat_sal',
          transactionDate: now,
          createdAt: now,
          updatedAt: now,
        ),
      ];
      final expTxns = [
        FamilyTransaction(
          id: 'exp-1',
          type: 'expense',
          amount: 500,
          categoryId: 'cat_groc',
          transactionDate: now,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      when(() => mockRepo.getTransactions(type: 'income'))
          .thenAnswer((_) async => right(incTxns));
      when(() => mockRepo.getTransactions(type: 'expense'))
          .thenAnswer((_) async => right(expTxns));

      final container = ProviderContainer(
        overrides: [
          familyFinanceRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );
      addTearDown(container.dispose);

      await container.read(incomeListProvider.future);
      await container.read(expenseListProvider.future);

      final summary = container.read(familyFinanceSummaryProvider).value!;
      expect(summary.totalIncome, 2450.0);
      expect(summary.totalExpense, 500.0);
      expect(summary.netBalance, 1950.0);
    });

    test('5. Edited transaction -> summary reflects updated amount only once', () async {
      final now = DateTime(2026, 3, 10);
      var currentIncomeTxns = [
        FamilyTransaction(
          id: 'inc-1',
          type: 'income',
          amount: 2000,
          categoryId: 'cat_sal',
          transactionDate: now,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      when(() => mockRepo.getTransactions(type: 'income'))
          .thenAnswer((_) async => right(currentIncomeTxns));
      when(() => mockRepo.getTransactions(type: 'expense'))
          .thenAnswer((_) async => right([]));
      when(() => mockRepo.updateTransaction(any()))
          .thenAnswer((invocation) async {
        final updated = invocation.positionalArguments.first as FamilyTransaction;
        currentIncomeTxns = [updated];
        return right(updated);
      });

      final container = ProviderContainer(
        overrides: [
          familyFinanceRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );
      addTearDown(container.dispose);
      container.listen(familyFinanceSummaryProvider, (_, __) {});

      await container.read(incomeListProvider.future);
      await container.read(expenseListProvider.future);

      var summary = container.read(familyFinanceSummaryProvider).value!;
      expect(summary.totalIncome, 2000.0);
      expect(summary.netBalance, 2000.0);

      // Edit transaction 2000 -> 2500
      final notifier = container.read(familyFinanceNotifierProvider.notifier);
      await notifier.updateTransaction(
        currentIncomeTxns.first.copyWith(amount: 2500),
      );

      // Re-read updated providers
      await container.read(incomeListProvider.future);
      await container.read(expenseListProvider.future);
      summary = container.read(familyFinanceSummaryProvider).value!;
      expect(summary.totalIncome, 2500.0);
      expect(summary.netBalance, 2500.0);
    });

    test('6. Soft-deleted transaction -> deleted record does not contribute to current totals', () async {
      final now = DateTime(2026, 3, 10);
      var currentExpenseTxns = [
        FamilyTransaction(
          id: 'exp-1',
          type: 'expense',
          amount: 500,
          categoryId: 'cat_groc',
          transactionDate: now,
          createdAt: now,
          updatedAt: now,
        ),
        FamilyTransaction(
          id: 'exp-2',
          type: 'expense',
          amount: 1000,
          categoryId: 'cat_groc',
          transactionDate: now,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      when(() => mockRepo.getTransactions(type: 'income'))
          .thenAnswer((_) async => right([]));
      when(() => mockRepo.getTransactions(type: 'expense'))
          .thenAnswer((_) async => right(currentExpenseTxns));
      when(() => mockRepo.deleteTransaction(any()))
          .thenAnswer((invocation) async {
        final id = invocation.positionalArguments.first as String;
        currentExpenseTxns = currentExpenseTxns.where((t) => t.id != id).toList();
        return right(null);
      });

      final container = ProviderContainer(
        overrides: [
          familyFinanceRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );
      addTearDown(container.dispose);
      container.listen(familyFinanceSummaryProvider, (_, __) {});

      await container.read(incomeListProvider.future);
      await container.read(expenseListProvider.future);

      var summary = container.read(familyFinanceSummaryProvider).value!;
      expect(summary.totalExpense, 1500.0);
      expect(summary.netBalance, -1500.0);

      // Delete exp-2
      final notifier = container.read(familyFinanceNotifierProvider.notifier);
      await notifier.deleteTransaction('exp-2');

      await container.read(incomeListProvider.future);
      await container.read(expenseListProvider.future);
      summary = container.read(familyFinanceSummaryProvider).value!;
      expect(summary.totalExpense, 500.0);
      expect(summary.netBalance, -500.0);
    });
  });

  group('Family Finance Repository Summary Parity Tests (SQLite vs Hive)', () {
    // ── SQLite Parity ──
    test('7a. SQLite repository calculates total income, expense, and net correctly across CRUD', () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;

      final sqliteDb = await openDatabase(
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
      final repo = FamilyFinanceRepositoryImpl(DatabaseHelper(AppDatabase.instance));

      final now = DateTime(2026, 3, 1);
      final inc1 = FamilyTransaction(
        id: 'sq-inc-1',
        type: 'income',
        amount: 2000,
        categoryId: 'cat-1',
        transactionDate: now,
        createdAt: now,
        updatedAt: now,
      );
      final inc2 = FamilyTransaction(
        id: 'sq-inc-2',
        type: 'income',
        amount: 450,
        categoryId: 'cat-1',
        transactionDate: now,
        createdAt: now,
        updatedAt: now,
      );
      final exp1 = FamilyTransaction(
        id: 'sq-exp-1',
        type: 'expense',
        amount: 500,
        categoryId: 'cat-2',
        transactionDate: now,
        createdAt: now,
        updatedAt: now,
      );

      await repo.addTransaction(inc1);
      await repo.addTransaction(inc2);
      await repo.addTransaction(exp1);

      final incomeList = (await repo.getTransactions(type: 'income')).getOrElse((_) => []);
      final expenseList = (await repo.getTransactions(type: 'expense')).getOrElse((_) => []);

      final totalIncome = incomeList.fold<double>(0.0, (s, t) => s + t.amount);
      final totalExpense = expenseList.fold<double>(0.0, (s, t) => s + t.amount);
      final netBalance = totalIncome - totalExpense;

      expect(totalIncome, 2450.0);
      expect(totalExpense, 500.0);
      expect(netBalance, 1950.0);

      // Soft delete inc2
      await repo.deleteTransaction(inc2.id);
      final incomeListAfterDel = (await repo.getTransactions(type: 'income')).getOrElse((_) => []);
      final totalIncomeAfterDel = incomeListAfterDel.fold<double>(0.0, (s, t) => s + t.amount);
      expect(totalIncomeAfterDel, 2000.0);
      expect(totalIncomeAfterDel - totalExpense, 1500.0);

      await sqliteDb.close();
    });

    // ── Hive Parity ──
    test('7b. Hive repository calculates total income, expense, and net correctly across CRUD', () async {
      final tempDir = await Directory.systemTemp.createTemp('hive_summary_test_');
      await HiveRegistrar.initialize(tempDir.path);
      const repo = FamilyFinanceHiveRepositoryImpl();

      final now = DateTime(2026, 3, 1);
      final inc1 = FamilyTransaction(
        id: 'hv-inc-1',
        type: 'income',
        amount: 2000,
        categoryId: 'cat-1',
        transactionDate: now,
        createdAt: now,
        updatedAt: now,
      );
      final inc2 = FamilyTransaction(
        id: 'hv-inc-2',
        type: 'income',
        amount: 450,
        categoryId: 'cat-1',
        transactionDate: now,
        createdAt: now,
        updatedAt: now,
      );
      final exp1 = FamilyTransaction(
        id: 'hv-exp-1',
        type: 'expense',
        amount: 500,
        categoryId: 'cat-2',
        transactionDate: now,
        createdAt: now,
        updatedAt: now,
      );

      await repo.addTransaction(inc1);
      await repo.addTransaction(inc2);
      await repo.addTransaction(exp1);

      final incomeList = (await repo.getTransactions(type: 'income')).getOrElse((_) => []);
      final expenseList = (await repo.getTransactions(type: 'expense')).getOrElse((_) => []);

      final totalIncome = incomeList.fold<double>(0.0, (s, t) => s + t.amount);
      final totalExpense = expenseList.fold<double>(0.0, (s, t) => s + t.amount);
      final netBalance = totalIncome - totalExpense;

      expect(totalIncome, 2450.0);
      expect(totalExpense, 500.0);
      expect(netBalance, 1950.0);

      // Soft delete inc2
      await repo.deleteTransaction(inc2.id);
      final incomeListAfterDel = (await repo.getTransactions(type: 'income')).getOrElse((_) => []);
      final totalIncomeAfterDel = incomeListAfterDel.fold<double>(0.0, (s, t) => s + t.amount);
      expect(totalIncomeAfterDel, 2000.0);
      expect(totalIncomeAfterDel - totalExpense, 1500.0);

      await Hive.close();
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });
  });
}
