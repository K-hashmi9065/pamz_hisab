import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pamz_khata/feature/analytics_reports/data/models/analytics_models.dart';
import 'package:pamz_khata/feature/analytics_reports/presentation/providers/analytics_providers.dart';
import 'package:pamz_khata/feature/family_finance/data/services/receipt_storage_service.dart';
import 'package:pamz_khata/feature/family_finance/domain/entities/family_transaction.dart';
import 'package:pamz_khata/feature/family_finance/presentation/providers/family_finance_providers.dart';
import 'package:pamz_khata/feature/family_finance/presentation/screens/family_finance_screen.dart';
import 'package:pamz_khata/feature/family_finance/presentation/widgets/transaction_form_sheet.dart';
import 'package:pamz_khata/shared/widgets/app_button.dart';

import '../../test_helpers/mocks.dart';
import '../../test_helpers/pump_app.dart';

void main() {
  setUpAll(registerFallbacks);

  final testCategories = [
    const TransactionCategory(
      id: 'cat_sal',
      domain: 'income',
      name: 'Salary',
      iconKey: '💼',
      colorHex: '#4CAF50',
      isSystemPreset: true,
      sortOrder: 1,
      isDeleted: false,
    ),
    const TransactionCategory(
      id: 'cat_groc',
      domain: 'expense',
      name: 'Groceries',
      iconKey: '🛒',
      colorHex: '#FF9800',
      isSystemPreset: true,
      sortOrder: 1,
      isDeleted: false,
    ),
  ];

  final testAccounts = [
    const Account(
      id: 'acc_cash',
      name: 'Cash',
      type: 'cash',
      isDeleted: false,
    ),
    const Account(
      id: 'acc_bank',
      name: 'Bank Account',
      type: 'bank',
      isDeleted: false,
    ),
  ];

  final testIncomeTxn = FamilyTransaction(
    id: 'txn-inc-1',
    type: 'income',
    amount: 50000,
    categoryId: 'cat_sal',
    categoryName: 'Salary',
    categoryIcon: '💼',
    accountId: 'acc_bank',
    accountName: 'Bank Account',
    transactionDate: DateTime(2026, 3, 1),
    notes: 'Monthly payout',
    createdAt: DateTime(2026, 3, 1),
    updatedAt: DateTime(2026, 3, 1),
  );

  final testExpenseTxn = FamilyTransaction(
    id: 'txn-exp-1',
    type: 'expense',
    amount: 4500,
    categoryId: 'cat_groc',
    categoryName: 'Groceries',
    categoryIcon: '🛒',
    accountId: 'acc_cash',
    accountName: 'Cash',
    transactionDate: DateTime(2026, 3, 2),
    notes: 'Supermarket shopping',
    createdAt: DateTime(2026, 3, 2),
    updatedAt: DateTime(2026, 3, 2),
  );

  group('FamilyFinanceScreen Widget Tests', () {
    late MockFamilyFinanceRepository mockRepo;

    setUp(() {
      mockRepo = MockFamilyFinanceRepository();
      when(() => mockRepo.getCategories(domain: any(named: 'domain')))
          .thenAnswer((_) async => right(testCategories));
      when(() => mockRepo.getAccounts())
          .thenAnswer((_) async => right(testAccounts));
    });

    List<Override> buildOverrides({
      List<FamilyTransaction>? incomeList,
      List<FamilyTransaction>? expenseList,
    }) {
      return [
        familyFinanceRepositoryProvider.overrideWithValue(mockRepo),
        incomeListProvider.overrideWith((ref) async => incomeList ?? [testIncomeTxn]),
        expenseListProvider.overrideWith((ref) async => expenseList ?? [testExpenseTxn]),
      ];
    }

    testWidgets('1. Family Finance screen renders tabs and monthly summary', (tester) async {
      await pumpApp(
        tester,
        const FamilyFinanceScreen(),
        overrides: buildOverrides(),
      );
      await tester.pumpAndSettle();

      expect(find.text('Family Finance'), findsOneWidget);
      expect(find.text('Income'), findsWidgets);
      expect(find.text('Expense'), findsWidgets);
      expect(find.text('This Month Income'), findsOneWidget);
      expect(find.text('Salary'), findsOneWidget);
      expect(find.text('+₹50,000'), findsOneWidget);
    });

    testWidgets('2. Tab switching shows expense list with debit styling', (tester) async {
      await pumpApp(
        tester,
        const FamilyFinanceScreen(),
        overrides: buildOverrides(),
      );
      await tester.pumpAndSettle();

      // Tap Expense Tab
      await tester.tap(find.text('Expense').first);
      await tester.pumpAndSettle();

      expect(find.text('This Month Expense'), findsOneWidget);
      expect(find.text('Groceries'), findsOneWidget);
      expect(find.text('-₹4,500'), findsOneWidget);
    });

    testWidgets('3. Empty state renders when transactions list is empty', (tester) async {
      await pumpApp(
        tester,
        const FamilyFinanceScreen(),
        overrides: buildOverrides(incomeList: [], expenseList: []),
      );
      await tester.pumpAndSettle();

      expect(find.text('No income entries yet'), findsOneWidget);
      expect(find.text('Tap + to log your first income entry'), findsOneWidget);
    });

    testWidgets('4. Delete confirmation dialog triggers deletion on confirmation', (tester) async {
      when(() => mockRepo.deleteTransaction(any()))
          .thenAnswer((_) async => right(null));

      await pumpApp(
        tester,
        const FamilyFinanceScreen(),
        overrides: buildOverrides(),
      );
      await tester.pumpAndSettle();

      // Tap Delete icon button
      final deleteBtn = find.byTooltip('Delete').first;
      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();

      expect(find.text('Delete Transaction'), findsOneWidget);
      expect(find.textContaining('Are you sure you want to delete'), findsOneWidget);

      // Tap Confirm Delete
      final confirmBtn = find.widgetWithText(AppButton, 'Delete');
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      verify(() => mockRepo.deleteTransaction(testIncomeTxn.id)).called(1);
    });
  });

  group('TransactionFormSheet Widget Tests', () {
    late MockFamilyFinanceRepository mockRepo;

    setUp(() {
      mockRepo = MockFamilyFinanceRepository();
      when(() => mockRepo.getCategories(domain: any(named: 'domain')))
          .thenAnswer((_) async => right(testCategories));
      when(() => mockRepo.getAccounts())
          .thenAnswer((_) async => right(testAccounts));
    });

    List<Override> buildSheetOverrides() {
      return [
        familyFinanceRepositoryProvider.overrideWithValue(mockRepo),
        receiptStorageServiceProvider.overrideWithValue(
          ReceiptStorageService(baseDirectoryProvider: () async => Directory.systemTemp),
        ),
        categoriesProvider('income').overrideWith((ref) async => [testCategories[0]]),
        categoriesProvider('expense').overrideWith((ref) async => [testCategories[1]]),
        accountsProvider.overrideWith((ref) async => testAccounts),
        analyticsReportProvider.overrideWith((ref) async => AnalyticsReportData(
          horizon: AnalyticsTimeHorizon.monthly,
          startDate: DateTime(2026, 1, 1),
          endDate: DateTime(2026, 12, 31),
          summary: FinancialSummaryData.zero,
          categoryBreakdown: [],
          pnlTrend: [],
          quarterlyBreakdown: [],
          tenYearComparison: [],
        )),
      ];
    }

    testWidgets('5. Renders Add Income form and validates input fields', (tester) async {
      tester.view.physicalSize = const Size(1194, 834);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await pumpApp(
        tester,
        const TransactionFormSheet(initialType: 'income'),
        overrides: buildSheetOverrides(),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add Income'), findsOneWidget);
      final saveBtn = find.widgetWithText(AppButton, 'Save Income');
      expect(saveBtn, findsOneWidget);

      // Attempt to submit empty form
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      expect(find.text('Please enter amount'), findsOneWidget);
    });

    testWidgets('6. Submitting valid Add Expense calls repository addTransaction', (tester) async {
      tester.view.physicalSize = const Size(1194, 834);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      when(() => mockRepo.addTransaction(any()))
          .thenAnswer((invocation) async => right(invocation.positionalArguments.first as FamilyTransaction));

      await pumpApp(
        tester,
        const TransactionFormSheet(initialType: 'expense'),
        overrides: buildSheetOverrides(),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add Expense'), findsOneWidget);

      // Enter amount
      await tester.enterText(find.byType(TextFormField).first, '1200');
      await tester.pumpAndSettle();

      final saveBtn = find.widgetWithText(AppButton, 'Save Expense');
      expect(saveBtn, findsOneWidget);

      // Submit
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      verify(() => mockRepo.addTransaction(any())).called(1);
    });

    testWidgets('7. Pre-populates fields in Edit mode and updates transaction', (tester) async {
      tester.view.physicalSize = const Size(1194, 834);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      when(() => mockRepo.updateTransaction(any()))
          .thenAnswer((invocation) async => right(invocation.positionalArguments.first as FamilyTransaction));

      await pumpApp(
        tester,
        TransactionFormSheet(existingTransaction: testExpenseTxn),
        overrides: buildSheetOverrides(),
      );
      await tester.pumpAndSettle();

      expect(find.text('Edit Expense'), findsOneWidget);
      expect(find.text('4500'), findsOneWidget);
      expect(find.text('Supermarket shopping'), findsOneWidget);

      // Update notes
      await tester.enterText(find.byType(TextFormField).last, 'Updated Groceries');
      await tester.pumpAndSettle();

      // Tap Update Expense
      final updateBtn = find.widgetWithText(AppButton, 'Update Expense');
      expect(updateBtn, findsOneWidget);
      await tester.tap(updateBtn);
      await tester.pumpAndSettle();

      verify(() => mockRepo.updateTransaction(any())).called(1);
    });

    testWidgets('8. Form sheet displays receipt preview, remove button, and clears path when remove tapped (FR-FE-002)', (tester) async {
      tester.view.physicalSize = const Size(1194, 834);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final txnWithReceipt = testExpenseTxn.copyWith(
        receiptPhotoPath: '/var/mobile/receipt_sample.jpg',
      );

      await pumpApp(
        tester,
        TransactionFormSheet(existingTransaction: txnWithReceipt),
        overrides: buildSheetOverrides(),
      );
      await tester.pumpAndSettle();

      final receiptText = find.text('Receipt Photo (Optional)');
      expect(receiptText, findsOneWidget);
      expect(find.text('Receipt attached'), findsOneWidget);
      expect(find.byTooltip('Remove Receipt'), findsOneWidget);
      expect(find.byTooltip('Preview Receipt'), findsOneWidget);

      // Tap Remove Receipt
      await tester.tap(find.byTooltip('Remove Receipt'));
      await tester.pumpAndSettle();

      expect(find.text('Receipt attached'), findsNothing);
      expect(find.text('Attach Receipt Photo'), findsOneWidget);
    });

    testWidgets('9. Submitting edit expense preserves receiptPhotoPath in repository call (FR-FE-002)', (tester) async {
      tester.view.physicalSize = const Size(1194, 834);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final txnWithReceipt = testExpenseTxn.copyWith(
        receiptPhotoPath: '/var/mobile/receipt_sample.jpg',
      );

      when(() => mockRepo.updateTransaction(any()))
          .thenAnswer((invocation) async => right(invocation.positionalArguments.first as FamilyTransaction));

      await pumpApp(
        tester,
        TransactionFormSheet(existingTransaction: txnWithReceipt),
        overrides: buildSheetOverrides(),
      );
      await tester.pumpAndSettle();

      final updateBtn = find.widgetWithText(AppButton, 'Update Expense');
      expect(updateBtn, findsOneWidget);
      await tester.tap(updateBtn);
      await tester.pumpAndSettle();

      final captured = verify(() => mockRepo.updateTransaction(captureAny())).captured;
      expect((captured.first as FamilyTransaction).receiptPhotoPath, '/var/mobile/receipt_sample.jpg');
    });

    testWidgets('10. FamilyFinanceScreen displays receipt icon and opens receipt viewer dialog when receipt attached (FR-FE-002)', (tester) async {
      final txnWithReceipt = testExpenseTxn.copyWith(
        receiptPhotoPath: '/var/mobile/receipt_sample.jpg',
      );

      await pumpApp(
        tester,
        const FamilyFinanceScreen(initialTab: 1),
        overrides: [
          familyFinanceRepositoryProvider.overrideWithValue(mockRepo),
          incomeListProvider.overrideWith((ref) async => [testIncomeTxn]),
          expenseListProvider.overrideWith((ref) async => [txnWithReceipt]),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Receipt attached'), findsOneWidget);
      expect(find.byTooltip('View Receipt'), findsOneWidget);

      // Tap View Receipt icon
      await tester.tap(find.byTooltip('View Receipt'));
      await tester.pumpAndSettle();

      expect(find.text('Receipt: Groceries'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      // Close dialog
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Receipt: Groceries'), findsNothing);
    });
  });
}
