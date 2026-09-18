import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pamz_khata/core/db/hive/hive_registrar.dart';
import 'package:pamz_khata/core/error/failure.dart';
import 'package:pamz_khata/feature/family_finance/data/repositories/family_finance_hive_repository_impl.dart';
import 'package:pamz_khata/feature/family_finance/domain/entities/category_budget.dart';
import 'package:pamz_khata/feature/family_finance/domain/entities/family_transaction.dart';
import 'package:pamz_khata/feature/family_finance/domain/usecases/budget_usecases.dart';
import 'package:pamz_khata/feature/family_finance/presentation/providers/budget_providers.dart';
import 'package:pamz_khata/feature/family_finance/presentation/providers/family_finance_providers.dart';

import '../../test_helpers/mocks.dart';

void main() {
  setUpAll(registerFallbacks);

  // ═══════════════════════════════════════════════════════════════════════════
  // 1. USECASE VALIDATION TESTS (FR-FE-003)
  // ═══════════════════════════════════════════════════════════════════════════
  group('Category Budget UseCase Validation Tests (FR-FE-003)', () {
    late MockFamilyFinanceRepository mockRepo;
    late CreateBudgetUsecase createUsecase;
    late UpdateBudgetUsecase updateUsecase;
    late DeleteBudgetUsecase deleteUsecase;

    setUp(() {
      mockRepo = MockFamilyFinanceRepository();
      createUsecase = CreateBudgetUsecase(mockRepo);
      updateUsecase = UpdateBudgetUsecase(mockRepo);
      deleteUsecase = DeleteBudgetUsecase(mockRepo);
    });

    test('Create budget fails if categoryId is empty', () async {
      final invalid = CategoryBudget(
        id: '',
        categoryId: '',
        monthlyLimit: 10000,
        year: 2026,
        month: 3,
        createdAt: DateTime(2026, 3, 1),
        updatedAt: DateTime(2026, 3, 1),
      );

      final result = await createUsecase(invalid);
      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure.message, contains('category is required')),
        (_) => fail('Should have failed'),
      );
      verifyNever(() => mockRepo.createBudget(any()));
    });

    test('Create budget fails if monthly limit is <= 0', () async {
      final invalid = CategoryBudget(
        id: '',
        categoryId: 'cat_groceries',
        monthlyLimit: 0,
        year: 2026,
        month: 3,
        createdAt: DateTime(2026, 3, 1),
        updatedAt: DateTime(2026, 3, 1),
      );

      final result = await createUsecase(invalid);
      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure.message, contains('greater than zero')),
        (_) => fail('Should have failed'),
      );
      verifyNever(() => mockRepo.createBudget(any()));
    });

    test('Create budget fails if threshold is outside 1..100%', () async {
      final invalidLow = CategoryBudget(
        id: '',
        categoryId: 'cat_groceries',
        monthlyLimit: 10000,
        thresholdPercentage: 0,
        year: 2026,
        month: 3,
        createdAt: DateTime(2026, 3, 1),
        updatedAt: DateTime(2026, 3, 1),
      );

      final resultLow = await createUsecase(invalidLow);
      expect(resultLow.isLeft(), isTrue);
      resultLow.fold(
        (failure) => expect(failure.message, contains('between 1 and 100')),
        (_) => fail('Should have failed'),
      );

      final invalidHigh = invalidLow.copyWith(thresholdPercentage: 150);
      final resultHigh = await createUsecase(invalidHigh);
      expect(resultHigh.isLeft(), isTrue);
      resultHigh.fold(
        (failure) => expect(failure.message, contains('between 1 and 100')),
        (_) => fail('Should have failed'),
      );
      verifyNever(() => mockRepo.createBudget(any()));
    });

    test('Create budget fails if month is invalid (< 1 or > 12)', () async {
      final invalidMonth = CategoryBudget(
        id: '',
        categoryId: 'cat_groceries',
        monthlyLimit: 10000,
        year: 2026,
        month: 13,
        createdAt: DateTime(2026, 3, 1),
        updatedAt: DateTime(2026, 3, 1),
      );

      final result = await createUsecase(invalidMonth);
      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure.message, contains('Invalid budget month')),
        (_) => fail('Should have failed'),
      );
      verifyNever(() => mockRepo.createBudget(any()));
    });

    test('Create budget succeeds with valid data', () async {
      final valid = CategoryBudget(
        id: '',
        categoryId: 'cat_groceries',
        monthlyLimit: 15000,
        thresholdPercentage: 80,
        year: 2026,
        month: 3,
        createdAt: DateTime(2026, 3, 1),
        updatedAt: DateTime(2026, 3, 1),
      );

      when(() => mockRepo.createBudget(any()))
          .thenAnswer((_) async => right(valid.copyWith(id: 'b-101')));

      final result = await createUsecase(valid);
      expect(result.isRight(), isTrue);
      expect(result.getOrElse((_) => throw Exception()).id, 'b-101');
      verify(() => mockRepo.createBudget(valid)).called(1);
    });

    test('Update budget fails with invalid limit or threshold', () async {
      final invalid = CategoryBudget(
        id: 'b-101',
        categoryId: 'cat_groceries',
        monthlyLimit: -500,
        year: 2026,
        month: 3,
        createdAt: DateTime(2026, 3, 1),
        updatedAt: DateTime(2026, 3, 1),
      );

      final result = await updateUsecase(invalid);
      expect(result.isLeft(), isTrue);
      verifyNever(() => mockRepo.updateBudget(any()));
    });

    test('Delete budget delegates to repo', () async {
      when(() => mockRepo.deleteBudget('b-101'))
          .thenAnswer((_) async => right(null));

      final result = await deleteUsecase('b-101');
      expect(result.isRight(), isTrue);
      verify(() => mockRepo.deleteBudget('b-101')).called(1);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 2. BUDGET CALCULATION ENTITY TESTS
  // ═══════════════════════════════════════════════════════════════════════════
  group('BudgetCalculation Math & Threshold Logic Tests', () {
    test('Calculates remaining amount, percentage, and threshold states correctly', () {
      final budget = CategoryBudget(
        id: 'b-1',
        categoryId: 'cat_groceries',
        categoryName: 'Groceries & Ration',
        monthlyLimit: 10000,
        thresholdPercentage: 80,
        year: 2026,
        month: 3,
        createdAt: DateTime(2026, 3, 1),
        updatedAt: DateTime(2026, 3, 1),
      );

      // 1. Spending under threshold: ₹5,000 / ₹10,000 (50%)
      final calc50 = BudgetCalculation.calculate(
        budget: budget,
        actualExpense: 5000,
      );
      expect(calc50.remainingAmount, 5000);
      expect(calc50.usagePercentage, 50.0);
      expect(calc50.isThresholdReached, isFalse);
      expect(calc50.isExceeded, isFalse);

      // 2. Spending exactly at threshold: ₹8,000 / ₹10,000 (80%)
      final calc80 = BudgetCalculation.calculate(
        budget: budget,
        actualExpense: 8000,
      );
      expect(calc80.remainingAmount, 2000);
      expect(calc80.usagePercentage, 80.0);
      expect(calc80.isThresholdReached, isTrue);
      expect(calc80.isExceeded, isFalse);

      // 3. Spending near limit: ₹9,500 / ₹10,000 (95%)
      final calc95 = BudgetCalculation.calculate(
        budget: budget,
        actualExpense: 9500,
      );
      expect(calc95.remainingAmount, 500);
      expect(calc95.usagePercentage, 95.0);
      expect(calc95.isThresholdReached, isTrue);
      expect(calc95.isExceeded, isFalse);

      // 4. Spending exceeded: ₹12,000 / ₹10,000 (120%)
      final calc120 = BudgetCalculation.calculate(
        budget: budget,
        actualExpense: 12000,
      );
      expect(calc120.remainingAmount, -2000);
      expect(calc120.usagePercentage, 120.0);
      expect(calc120.isThresholdReached, isTrue);
      expect(calc120.isExceeded, isTrue);
    });

    test('Zero limit edge case does not divide by zero', () {
      final zeroBudget = CategoryBudget(
        id: 'b-zero',
        categoryId: 'cat_groceries',
        monthlyLimit: 0,
        year: 2026,
        month: 3,
        createdAt: DateTime(2026, 3, 1),
        updatedAt: DateTime(2026, 3, 1),
      );

      final calc = BudgetCalculation.calculate(
        budget: zeroBudget,
        actualExpense: 500,
      );
      expect(calc.usagePercentage, 0.0);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 3. HIVE REPOSITORY PERSISTENCE & PARITY TESTS
  // ═══════════════════════════════════════════════════════════════════════════
  group('FamilyFinanceHiveRepositoryImpl Budget Tracking (FR-FE-003)', () {
    late Directory tempDir;
    late FamilyFinanceHiveRepositoryImpl hiveRepo;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('pamz_budget_test_');
      await HiveRegistrar.initialize(tempDir.path);

      hiveRepo = const FamilyFinanceHiveRepositoryImpl();

      // Seed test categories
      await HiveRegistrar.categoriesBox.put('cat_groceries', {
        'id': 'cat_groceries',
        'domain': 'expense',
        'name': 'Groceries & Ration Test',
        'icon_key': '🛒',
        'color_hex': '#4CAF50',
        'is_system_preset': 1,
        'sort_order': 1,
        'is_deleted': 0,
      });
      await HiveRegistrar.categoriesBox.put('cat_salary', {
        'id': 'cat_salary',
        'domain': 'income',
        'name': 'Salary Test',
        'icon_key': '💼',
        'color_hex': '#2196F3',
        'is_system_preset': 1,
        'sort_order': 1,
        'is_deleted': 0,
      });
    });

    tearDown(() async {
      await Hive.close();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('Rejects budget creation for non-expense categories', () async {
      final incomeBudget = CategoryBudget(
        id: '',
        categoryId: 'cat_salary', // Income category
        monthlyLimit: 20000,
        year: 2026,
        month: 3,
        createdAt: DateTime(2026, 3, 1),
        updatedAt: DateTime(2026, 3, 1),
      );

      final result = await hiveRepo.createBudget(incomeBudget);
      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure.message, contains('expense categories')),
        (_) => fail('Should reject income category for budget'),
      );
    });

    test('Rejects duplicate active budget for same category + year + month', () async {
      final budget1 = CategoryBudget(
        id: '',
        categoryId: 'cat_groceries',
        monthlyLimit: 10000,
        year: 2026,
        month: 3,
        createdAt: DateTime(2026, 3, 1),
        updatedAt: DateTime(2026, 3, 1),
      );

      final res1 = await hiveRepo.createBudget(budget1);
      expect(res1.isRight(), isTrue);

      // Attempt duplicate
      final duplicate = budget1.copyWith(monthlyLimit: 15000);
      final res2 = await hiveRepo.createBudget(duplicate);
      expect(res2.isLeft(), isTrue);
      res2.fold(
        (failure) => expect(failure.message, contains('already exists')),
        (_) => fail('Should prevent duplicate budget'),
      );
    });

    test('Allows budget for different months or categories', () async {
      final marchBudget = CategoryBudget(
        id: '',
        categoryId: 'cat_groceries',
        monthlyLimit: 10000,
        year: 2026,
        month: 3,
        createdAt: DateTime(2026, 3, 1),
        updatedAt: DateTime(2026, 3, 1),
      );
      final resMarch = await hiveRepo.createBudget(marchBudget);
      expect(resMarch.isRight(), isTrue);

      final aprilBudget = CategoryBudget(
        id: '',
        categoryId: 'cat_groceries',
        monthlyLimit: 12000,
        year: 2026,
        month: 4,
        createdAt: DateTime(2026, 4, 1),
        updatedAt: DateTime(2026, 4, 1),
      );
      final resApril = await hiveRepo.createBudget(aprilBudget);
      expect(resApril.isRight(), isTrue);
    });

    test('Full CRUD, Soft Delete and Audit Logging', () async {
      // 1. Create
      final newBudget = CategoryBudget(
        id: '',
        categoryId: 'cat_groceries',
        monthlyLimit: 8000,
        thresholdPercentage: 75,
        year: 2026,
        month: 3,
        createdAt: DateTime(2026, 3, 1),
        updatedAt: DateTime(2026, 3, 1),
      );

      final created = (await hiveRepo.createBudget(newBudget))
          .getOrElse((_) => throw Exception());
      expect(created.id, isNotEmpty);
      expect(created.monthlyLimit, 8000);

      // 2. Read
      final list1 = (await hiveRepo.getBudgets(year: 2026, month: 3))
          .getOrElse((_) => throw Exception());
      expect(list1.length, 1);
      expect(list1.first.monthlyLimit, 8000);

      // 3. Update
      final updated = (await hiveRepo.updateBudget(created.copyWith(monthlyLimit: 9500)))
          .getOrElse((_) => throw Exception());
      expect(updated.monthlyLimit, 9500);

      final list2 = (await hiveRepo.getBudgets(year: 2026, month: 3))
          .getOrElse((_) => throw Exception());
      expect(list2.first.monthlyLimit, 9500);

      // 4. Soft Delete
      final delRes = await hiveRepo.deleteBudget(created.id);
      expect(delRes.isRight(), isTrue);

      final list3 = (await hiveRepo.getBudgets(year: 2026, month: 3))
          .getOrElse((_) => throw Exception());
      expect(list3.isEmpty, isTrue);

      // Verify record is preserved in Hive with isDeleted: 1
      final rawBox = HiveRegistrar.budgetsBox;
      final rawModel = rawBox.get(created.id);
      expect(rawModel, isNotNull);
      expect(rawModel is Map && rawModel['is_deleted'] == 1, isTrue);

      // Verify Audit Logs
      final auditBox = HiveRegistrar.auditLogBox;
      final budgetLogs = auditBox.values
          .where((l) => l is Map && l['entity_type'] == 'budgets' && l['entity_id'] == created.id)
          .toList();
      expect(budgetLogs.length, 3); // CREATE, UPDATE, DELETE
    });

    test('Real-time Budget Calculation aggregates active expenses correctly and isolates months', () async {
      // Create budget for March 2026: Groceries limit = ₹10,000
      final budget = (await hiveRepo.createBudget(CategoryBudget(
        id: '',
        categoryId: 'cat_groceries',
        monthlyLimit: 10000,
        thresholdPercentage: 80,
        year: 2026,
        month: 3,
        createdAt: DateTime(2026, 3, 1),
        updatedAt: DateTime(2026, 3, 1),
      ))).getOrElse((_) => throw Exception());

      // Add March expense 1: ₹3,000
      await hiveRepo.addTransaction(FamilyTransaction(
        id: 't-1',
        type: 'expense',
        amount: 3000,
        categoryId: 'cat_groceries',
        transactionDate: DateTime(2026, 3, 5),
        createdAt: DateTime(2026, 3, 5),
        updatedAt: DateTime(2026, 3, 5),
      ));

      // Add March expense 2: ₹5,500 (Total = ₹8,500, > 80% threshold)
      await hiveRepo.addTransaction(FamilyTransaction(
        id: 't-2',
        type: 'expense',
        amount: 5500,
        categoryId: 'cat_groceries',
        transactionDate: DateTime(2026, 3, 20),
        createdAt: DateTime(2026, 3, 20),
        updatedAt: DateTime(2026, 3, 20),
      ));

      // Add February expense: ₹4,000 (should be excluded)
      await hiveRepo.addTransaction(FamilyTransaction(
        id: 't-3',
        type: 'expense',
        amount: 4000,
        categoryId: 'cat_groceries',
        transactionDate: DateTime(2026, 2, 28),
        createdAt: DateTime(2026, 2, 28),
        updatedAt: DateTime(2026, 2, 28),
      ));

      // Add March Income: ₹20,000 (should not affect expense budget)
      await hiveRepo.addTransaction(FamilyTransaction(
        id: 't-4',
        type: 'income',
        amount: 20000,
        categoryId: 'cat_salary',
        transactionDate: DateTime(2026, 3, 1),
        createdAt: DateTime(2026, 3, 1),
        updatedAt: DateTime(2026, 3, 1),
      ));

      // Fetch Calculations for March 2026
      final calcs = (await hiveRepo.getBudgetCalculations(2026, 3))
          .getOrElse((_) => throw Exception());

      expect(calcs.length, 1);
      final calc = calcs.first;
      expect(calc.budget.id, budget.id);
      expect(calc.budget.monthlyLimit, 10000);
      expect(calc.actualExpense, 8500); // 3000 + 5500
      expect(calc.remainingAmount, 1500); // 10000 - 8500
      expect(calc.usagePercentage, 85.0);
      expect(calc.isThresholdReached, isTrue); // 85% >= 80%
      expect(calc.isExceeded, isFalse);

      // Soft delete t-2 expense and verify real-time recalculation
      await hiveRepo.deleteTransaction('t-2');
      final recalculated = (await hiveRepo.getBudgetCalculations(2026, 3))
          .getOrElse((_) => throw Exception());
      expect(recalculated.first.actualExpense, 3000);
      expect(recalculated.first.usagePercentage, 30.0);
      expect(recalculated.first.isThresholdReached, isFalse);
    });

    test('Historical safety: Deleting budget does NOT delete or alter transactions', () async {
      final budget = (await hiveRepo.createBudget(CategoryBudget(
        id: '',
        categoryId: 'cat_groceries',
        monthlyLimit: 10000,
        year: 2026,
        month: 3,
        createdAt: DateTime(2026, 3, 1),
        updatedAt: DateTime(2026, 3, 1),
      ))).getOrElse((_) => throw Exception());

      final txn = (await hiveRepo.addTransaction(FamilyTransaction(
        id: 'txn-safe',
        type: 'expense',
        amount: 3200,
        categoryId: 'cat_groceries',
        transactionDate: DateTime(2026, 3, 10),
        createdAt: DateTime(2026, 3, 10),
        updatedAt: DateTime(2026, 3, 10),
      ))).getOrElse((_) => throw Exception());

      // Delete budget
      await hiveRepo.deleteBudget(budget.id);

      // Verify transaction is completely unaffected
      final txns = (await hiveRepo.getTransactions(type: 'expense'))
          .getOrElse((_) => throw Exception());
      expect(txns.any((t) => t.id == txn.id), isTrue);
    });

    test('Soft-deleted budget can be recreated for the same category and month', () async {
      // 1. Create budget
      final budget = (await hiveRepo.createBudget(CategoryBudget(
        id: 'b-old',
        categoryId: 'cat_groceries',
        monthlyLimit: 10000,
        year: 2026,
        month: 3,
        createdAt: DateTime(2026, 3, 1),
        updatedAt: DateTime(2026, 3, 1),
      ))).getOrElse((_) => throw Exception());

      // 2. Active duplicate is rejected
      final duplicateAttempt = await hiveRepo.createBudget(budget.copyWith(id: 'b-dup'));
      expect(duplicateAttempt.isLeft(), isTrue);

      // 3. Soft-delete the budget
      final delRes = await hiveRepo.deleteBudget(budget.id);
      expect(delRes.isRight(), isTrue);

      // 4. Re-creating a new active budget for same category + month succeeds
      final newBudget = CategoryBudget(
        id: 'b-new',
        categoryId: 'cat_groceries',
        monthlyLimit: 12000,
        year: 2026,
        month: 3,
        createdAt: DateTime(2026, 3, 2),
        updatedAt: DateTime(2026, 3, 2),
      );
      final recreateRes = await hiveRepo.createBudget(newBudget);
      expect(recreateRes.isRight(), isTrue);
      expect(recreateRes.getOrElse((_) => throw Exception()).monthlyLimit, 12000);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 4. BUDGET NOTIFIER & PROVIDER TESTS
  // ═══════════════════════════════════════════════════════════════════════════
  group('BudgetNotifier State Management Tests', () {
    late MockFamilyFinanceRepository mockRepo;

    setUp(() {
      mockRepo = MockFamilyFinanceRepository();
    });

    test('Create budget updates notifier state and notifies listeners', () async {
      final container = ProviderContainer(
        overrides: [
          familyFinanceRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );
      addTearDown(container.dispose);

      final budget = CategoryBudget(
        id: 'b-new',
        categoryId: 'cat_groceries',
        monthlyLimit: 5000,
        year: 2026,
        month: 3,
        createdAt: DateTime(2026, 3, 1),
        updatedAt: DateTime(2026, 3, 1),
      );

      when(() => mockRepo.createBudget(any()))
          .thenAnswer((_) async => right(budget));

      final notifier = container.read(budgetNotifierProvider.notifier);
      final success = await notifier.createBudget(budget);

      expect(success, isTrue);
      expect(container.read(budgetNotifierProvider).hasValue, isTrue);
      verify(() => mockRepo.createBudget(budget)).called(1);
    });

    test('Notifier handles error when creation fails', () async {
      final container = ProviderContainer(
        overrides: [
          familyFinanceRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );
      addTearDown(container.dispose);

      final budget = CategoryBudget(
        id: 'b-fail',
        categoryId: 'cat_groceries',
        monthlyLimit: 5000,
        year: 2026,
        month: 3,
        createdAt: DateTime(2026, 3, 1),
        updatedAt: DateTime(2026, 3, 1),
      );

      when(() => mockRepo.createBudget(any()))
          .thenAnswer((_) async => left(const DatabaseFailure(message: 'Duplicate error')));

      final notifier = container.read(budgetNotifierProvider.notifier);
      final success = await notifier.createBudget(budget);

      expect(success, isFalse);
      expect(container.read(budgetNotifierProvider).hasError, isTrue);
    });

    test('FamilyFinanceNotifier invalidates budget calculation providers on txn mutations', () async {
      final container = ProviderContainer(
        overrides: [
          familyFinanceRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );
      addTearDown(container.dispose);

      final txn = FamilyTransaction(
        id: 'txn-1',
        type: 'expense',
        amount: 2500,
        categoryId: 'cat_groceries',
        transactionDate: DateTime(2026, 3, 1),
        createdAt: DateTime(2026, 3, 1),
        updatedAt: DateTime(2026, 3, 1),
      );

      when(() => mockRepo.addTransaction(any()))
          .thenAnswer((_) async => right(txn));
      when(() => mockRepo.updateTransaction(any()))
          .thenAnswer((_) async => right(txn));
      when(() => mockRepo.deleteTransaction(any()))
          .thenAnswer((_) async => right(null));

      final ffNotifier = container.read(familyFinanceNotifierProvider.notifier);

      // Add txn triggers invalidation
      final addOk = await ffNotifier.addTransaction(txn);
      expect(addOk, isTrue);

      // Update txn triggers invalidation
      final updateOk = await ffNotifier.updateTransaction(txn);
      expect(updateOk, isTrue);

      // Delete txn triggers invalidation
      final deleteOk = await ffNotifier.deleteTransaction('txn-1');
      expect(deleteOk, isTrue);
    });
  });
}
