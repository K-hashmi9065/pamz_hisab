import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pamz_khata/feature/family_finance/domain/entities/category_budget.dart';
import 'package:pamz_khata/feature/family_finance/domain/entities/family_transaction.dart';
import 'package:pamz_khata/feature/family_finance/presentation/providers/budget_providers.dart';
import 'package:pamz_khata/feature/family_finance/presentation/providers/family_finance_providers.dart';
import 'package:pamz_khata/feature/family_finance/presentation/screens/budget_screen.dart';
import 'package:pamz_khata/feature/family_finance/presentation/widgets/budget_form_sheet.dart';
import 'package:pamz_khata/shared/widgets/app_button.dart';

import '../../test_helpers/mocks.dart';
import '../../test_helpers/pump_app.dart';

void main() {
  setUpAll(registerFallbacks);

  // ─── Fixtures ─────────────────────────────────────────────────────────────
  final testExpenseCategories = [
    const TransactionCategory(
      id: 'cat_groceries',
      domain: 'expense',
      name: 'Groceries & Ration',
      iconKey: '🛒',
      colorHex: '#4CAF50',
      isSystemPreset: true,
      sortOrder: 1,
      isDeleted: false,
    ),
    const TransactionCategory(
      id: 'cat_fuel',
      domain: 'expense',
      name: 'Fuel & Transport',
      iconKey: '⛽',
      colorHex: '#FF9800',
      isSystemPreset: true,
      sortOrder: 2,
      isDeleted: false,
    ),
  ];

  final testIncomeCategories = [
    const TransactionCategory(
      id: 'cat_salary',
      domain: 'income',
      name: 'Salary',
      iconKey: '💼',
      colorHex: '#2196F3',
      isSystemPreset: true,
      sortOrder: 1,
      isDeleted: false,
    ),
  ];

  final testBudget1 = CategoryBudget(
    id: 'b-1',
    categoryId: 'cat_groceries',
    categoryName: 'Groceries & Ration',
    categoryIcon: '🛒',
    monthlyLimit: 10000,
    thresholdPercentage: 80,
    year: 2026,
    month: 3,
    createdAt: DateTime(2026, 3, 1),
    updatedAt: DateTime(2026, 3, 1),
  );

  final testCalculation1 = BudgetCalculation.calculate(
    budget: testBudget1,
    actualExpense: 8500, // 85% - threshold reached
  );

  final testBudget2 = CategoryBudget(
    id: 'b-2',
    categoryId: 'cat_fuel',
    categoryName: 'Fuel & Transport',
    categoryIcon: '⛽',
    monthlyLimit: 5000,
    thresholdPercentage: 80,
    year: 2026,
    month: 3,
    createdAt: DateTime(2026, 3, 1),
    updatedAt: DateTime(2026, 3, 1),
  );

  final testCalculation2 = BudgetCalculation.calculate(
    budget: testBudget2,
    actualExpense: 2000, // 40% - normal
  );

  group('BudgetScreen Widget Tests', () {
    late MockFamilyFinanceRepository mockRepo;

    setUp(() {
      mockRepo = MockFamilyFinanceRepository();
      when(() => mockRepo.getCategories(domain: 'expense'))
          .thenAnswer((_) async => right(testExpenseCategories));
      when(() => mockRepo.getCategories(domain: any(named: 'domain')))
          .thenAnswer((_) async => right([...testExpenseCategories, ...testIncomeCategories]));
    });

    List<Override> buildOverrides({
      List<BudgetCalculation>? calculations,
      DateTime? initialMonth,
    }) {
      return [
        familyFinanceRepositoryProvider.overrideWithValue(mockRepo),
        if (initialMonth != null)
          selectedBudgetMonthProvider.overrideWith((ref) => initialMonth),
        if (calculations != null) ...[
          activeBudgetCalculationsProvider.overrideWith(
            (ref) async => calculations,
          ),
          monthlyBudgetCalculationsProvider.overrideWith(
            (ref, _) async => calculations,
          ),
        ],
      ];
    }

    testWidgets('Renders empty state with CTA when no budgets exist', (tester) async {
      await pumpApp(
        tester,
        const BudgetScreen(),
        overrides: buildOverrides(
          calculations: [],
          initialMonth: DateTime(2026, 3, 1),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Month Header
      expect(find.text('March 2026'), findsOneWidget);

      // Verify Empty State Text
      expect(find.text('No category budgets set'), findsOneWidget);
      expect(find.text('Set Category Budget'), findsOneWidget);
    });

    testWidgets('Renders Budget Overview Card with aggregate totals and category list', (tester) async {
      await pumpApp(
        tester,
        const BudgetScreen(),
        overrides: buildOverrides(
          calculations: [testCalculation1, testCalculation2],
          initialMonth: DateTime(2026, 3, 1),
        ),
      );
      await tester.pumpAndSettle();

      // Check Title
      expect(find.text('Budget Tracking'), findsOneWidget);

      // Overview Card Total Budget, Total Spent, Remaining
      expect(find.text('Monthly Budget Overview'), findsOneWidget);
      expect(find.text('Total Budget'), findsOneWidget);
      expect(find.text('Total Spent'), findsOneWidget);
      expect(find.text('Remaining'), findsWidgets);

      // Category Names
      expect(find.text('Groceries & Ration'), findsOneWidget);
      expect(find.text('Fuel & Transport'), findsOneWidget);

      // Spending Details in RichText
      expect(
        find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText().contains('8,500')),
        findsWidgets,
      );
      expect(
        find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText().contains('1,500')),
        findsWidgets,
      );
      expect(
        find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText().contains('2,000')),
        findsWidgets,
      );

      // Threshold Alert Badge for Groceries (85% >= 80%)
      expect(find.textContaining('Spending alert: 85% reached'), findsOneWidget);
    });

    testWidgets('Month navigation changes selected month', (tester) async {
      await pumpApp(
        tester,
        const BudgetScreen(),
        overrides: buildOverrides(
          calculations: [],
          initialMonth: DateTime(2026, 3, 1),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('March 2026'), findsOneWidget);

      // Tap next month chevron
      await tester.tap(find.byIcon(Icons.chevron_right_rounded));
      await tester.pumpAndSettle();

      expect(find.text('April 2026'), findsOneWidget);

      // Tap previous month chevron twice
      await tester.tap(find.byIcon(Icons.chevron_left_rounded));
      await tester.pumpAndSettle();
      expect(find.text('March 2026'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.chevron_left_rounded));
      await tester.pumpAndSettle();
      expect(find.text('February 2026'), findsOneWidget);
    });

    testWidgets('Delete budget shows confirmation dialog and invokes delete', (tester) async {
      when(() => mockRepo.deleteBudget('b-1'))
          .thenAnswer((_) async => right(null));

      await pumpApp(
        tester,
        const BudgetScreen(),
        overrides: buildOverrides(
          calculations: [testCalculation1],
          initialMonth: DateTime(2026, 3, 1),
        ),
      );
      await tester.pumpAndSettle();

      // Find and tap delete button on category card
      final deleteBtn = find.byIcon(Icons.delete_outline_rounded);
      expect(deleteBtn, findsOneWidget);
      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();

      // Verify Confirmation Dialog
      expect(find.text('Delete Budget'), findsOneWidget);
      expect(find.textContaining('Are you sure you want to delete the budget for "Groceries & Ration"'), findsOneWidget);

      // Tap Delete in dialog
      final confirmDelete = find.widgetWithText(AppButton, 'Delete');
      await tester.tap(confirmDelete);
      await tester.pumpAndSettle();

      verify(() => mockRepo.deleteBudget('b-1')).called(1);
    });

    testWidgets('Budget screen does not show spending alert when below threshold', (tester) async {
      final initialCalc = BudgetCalculation.calculate(
        budget: testBudget1,
        actualExpense: 4000,
      );

      await pumpApp(
        tester,
        const BudgetScreen(),
        overrides: buildOverrides(
          calculations: [initialCalc],
          initialMonth: DateTime(2026, 3, 1),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Groceries & Ration'), findsOneWidget);
      expect(find.textContaining('Spending alert:'), findsNothing);
    });

    testWidgets('Budget screen reflects alert badge when threshold is reached', (tester) async {
      final updatedCalc = BudgetCalculation.calculate(
        budget: testBudget1,
        actualExpense: 9000,
      );

      await pumpApp(
        tester,
        const BudgetScreen(),
        overrides: buildOverrides(
          calculations: [updatedCalc],
          initialMonth: DateTime(2026, 3, 1),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Groceries & Ration'), findsOneWidget);
      expect(find.textContaining('Spending alert: 90% reached'), findsOneWidget);
    });
  });

  group('BudgetFormSheet Widget Tests', () {
    late MockFamilyFinanceRepository mockRepo;

    setUp(() {
      mockRepo = MockFamilyFinanceRepository();
      when(() => mockRepo.getCategories(domain: 'expense'))
          .thenAnswer((_) async => right(testExpenseCategories));
      when(() => mockRepo.getCategories(domain: any(named: 'domain')))
          .thenAnswer((_) async => right(testExpenseCategories));
    });

    List<Override> buildOverrides() {
      return [
        familyFinanceRepositoryProvider.overrideWithValue(mockRepo),
        categoriesProvider('expense').overrideWith((ref) => testExpenseCategories),
      ];
    }

    testWidgets('Renders Add Budget mode with fields and validates input', (tester) async {
      await pumpApp(
        tester,
        const BudgetFormSheet(
          initialYear: 2026,
          initialMonth: 3,
        ),
        overrides: buildOverrides(),
      );
      await tester.pumpAndSettle();

      // Check title and fields
      expect(find.text('Set Category Budget'), findsOneWidget);
      expect(find.text('Budget for: March 2026'), findsOneWidget);
      expect(find.text('Expense Category'), findsOneWidget);
      expect(find.text('Monthly Limit (₹)'), findsOneWidget);
      expect(find.text('Alert Threshold (%)'), findsOneWidget);

      // Tap Save without entering amount to trigger validation
      final saveBtn = find.widgetWithText(AppButton, 'Save Budget');
      expect(saveBtn, findsOneWidget);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Verify validation message
      expect(find.text('Please enter monthly limit'), findsOneWidget);
    });

    testWidgets('Submits valid Add Budget and creates budget via notifier', (tester) async {
      when(() => mockRepo.createBudget(any()))
          .thenAnswer((_) async => right(testBudget1));

      await pumpApp(
        tester,
        const BudgetFormSheet(
          initialYear: 2026,
          initialMonth: 3,
        ),
        overrides: buildOverrides(),
      );
      await tester.pumpAndSettle();

      // Enter Monthly Limit
      final limitField = find.byType(TextFormField).first;
      await tester.enterText(limitField, '10000');
      await tester.pumpAndSettle();

      // Tap Save Budget
      final saveBtn = find.widgetWithText(AppButton, 'Save Budget');
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      verify(() => mockRepo.createBudget(any())).called(1);
    });

    testWidgets('Renders Edit Budget mode with pre-filled fields', (tester) async {
      when(() => mockRepo.updateBudget(any()))
          .thenAnswer((_) async => right(testBudget1.copyWith(monthlyLimit: 12000)));

      await pumpApp(
        tester,
        BudgetFormSheet(
          initialYear: 2026,
          initialMonth: 3,
          existingBudget: testBudget1,
        ),
        overrides: buildOverrides(),
      );
      await tester.pumpAndSettle();

      // Verify Edit Title and button
      expect(find.text('Edit Category Budget'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Update Budget'), findsOneWidget);

      // Verify prefilled amount
      expect(find.text('10000'), findsOneWidget);

      // Modify limit to 12000
      final limitField = find.widgetWithText(TextFormField, '10000');
      await tester.enterText(limitField, '12000');
      await tester.pumpAndSettle();

      // Save changes
      await tester.tap(find.widgetWithText(AppButton, 'Update Budget'));
      await tester.pumpAndSettle();

      verify(() => mockRepo.updateBudget(any())).called(1);
    });
  });
}
