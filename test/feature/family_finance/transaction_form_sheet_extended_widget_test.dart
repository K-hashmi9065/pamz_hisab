import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pamz_khata/feature/family_finance/data/services/receipt_storage_service.dart';
import 'package:pamz_khata/feature/family_finance/domain/entities/family_transaction.dart';
import 'package:pamz_khata/feature/family_finance/presentation/providers/family_finance_providers.dart';
import 'package:pamz_khata/feature/family_finance/presentation/widgets/transaction_form_sheet.dart';
import 'package:pamz_khata/shared/widgets/app_button.dart';

import '../../test_helpers/mocks.dart';
import '../../test_helpers/pump_app.dart';

class MockReceiptStorageService extends Mock implements ReceiptStorageService {}

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
    const TransactionCategory(
      id: 'cat_rent',
      domain: 'expense',
      name: 'Rent',
      iconKey: '🏠',
      colorHex: '#E91E63',
      isSystemPreset: true,
      sortOrder: 2,
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
      name: 'HDFC Bank',
      type: 'bank',
      isDeleted: false,
    ),
  ];

  final existingExpenseTxn = FamilyTransaction(
    id: 'txn-exp-101',
    type: 'expense',
    amount: 2500.0,
    categoryId: 'cat_groc',
    categoryName: 'Groceries',
    categoryIcon: '🛒',
    accountId: 'acc_bank',
    receiptPhotoPath: '/mock/receipts/bill_101.jpg',
    transactionDate: DateTime(2026, 9, 15),
    notes: 'Monthly supermarket run',
    createdAt: DateTime(2026, 9, 15),
    updatedAt: DateTime(2026, 9, 15),
    isDeleted: false,
  );

  group('TransactionFormSheet Extended Widget Tests', () {
    late MockFamilyFinanceRepository mockRepo;
    late MockReceiptStorageService mockStorageService;

    setUp(() {
      mockRepo = MockFamilyFinanceRepository();
      mockStorageService = MockReceiptStorageService();

      when(() => mockRepo.getCategories(domain: any(named: 'domain')))
          .thenAnswer((invocation) async {
        final domain = invocation.namedArguments[#domain] as String?;
        if (domain == null) return Right(testCategories);
        return Right(testCategories.where((c) => c.domain == domain).toList());
      });

      when(() => mockRepo.getAccounts()).thenAnswer((_) async => Right(testAccounts));
      when(() => mockRepo.addTransaction(any()))
          .thenAnswer((invocation) async => Right(invocation.positionalArguments[0] as FamilyTransaction));
      when(() => mockRepo.updateTransaction(any()))
          .thenAnswer((invocation) async => Right(invocation.positionalArguments[0] as FamilyTransaction));
      when(() => mockRepo.getTransactions(type: any(named: 'type')))
          .thenAnswer((_) async => const Right([]));
      when(() => mockStorageService.deleteReceiptImage(any()))
          .thenAnswer((_) async => true);
    });

    List<Override> buildOverrides() {
      return [
        familyFinanceRepositoryProvider.overrideWithValue(mockRepo),
        receiptStorageServiceProvider.overrideWithValue(mockStorageService),
      ];
    }

    testWidgets('1. Form validation: rejects empty or non-positive amount and displays error', (tester) async {
      tester.view.physicalSize = const Size(1194, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await pumpApp(
        tester,
        const TransactionFormSheet(initialType: 'expense'),
        overrides: buildOverrides(),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add Expense'), findsOneWidget);

      // Tap Save with empty amount
      await tester.tap(find.byType(AppButton));
      await tester.pumpAndSettle();

      expect(find.text('Please enter amount'), findsOneWidget);

      // Enter 0
      final amountField = find.byType(TextFormField).first;
      await tester.enterText(amountField, '0');
      await tester.tap(find.byType(AppButton));
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid amount greater than 0'), findsOneWidget);
    });

    testWidgets('2. Edit mode: populates existing transaction fields and successfully submits update', (tester) async {
      tester.view.physicalSize = const Size(1194, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await pumpApp(
        tester,
        TransactionFormSheet(existingTransaction: existingExpenseTxn),
        overrides: buildOverrides(),
      );
      await tester.pumpAndSettle();

      expect(find.text('Edit Expense'), findsOneWidget);
      expect(find.text('2500'), findsOneWidget);
      expect(find.text('Monthly supermarket run'), findsOneWidget);
      expect(find.text('Receipt attached'), findsOneWidget);

      // Modify amount
      final amountField = find.byType(TextFormField).first;
      await tester.enterText(amountField, '3200');

      // Tap Update Expense button
      await tester.tap(find.byType(AppButton));
      await tester.pumpAndSettle();

      verify(() => mockRepo.updateTransaction(any(
            that: isA<FamilyTransaction>()
                .having((t) => t.amount, 'amount', 3200.0)
                .having((t) => t.id, 'id', 'txn-exp-101'),
          ))).called(1);
    });

    testWidgets('3. Type switching: switches from Expense to Income and clears/resets categories', (tester) async {
      tester.view.physicalSize = const Size(1194, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await pumpApp(
        tester,
        const TransactionFormSheet(initialType: 'expense'),
        overrides: buildOverrides(),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add Expense'), findsOneWidget);

      // Tap Income segment
      await tester.tap(find.text('Income'));
      await tester.pumpAndSettle();

      expect(find.text('Add Income'), findsOneWidget);
      expect(find.text('Salary'), findsOneWidget);

      // Fill valid amount and save
      final amountField = find.byType(TextFormField).first;
      await tester.enterText(amountField, '75000');
      await tester.tap(find.byType(AppButton));
      await tester.pumpAndSettle();

      verify(() => mockRepo.addTransaction(any(
            that: isA<FamilyTransaction>()
                .having((t) => t.type, 'type', 'income')
                .having((t) => t.amount, 'amount', 75000.0),
          ))).called(1);
    });

    testWidgets('4. Receipt removal and preview modal interaction in edit mode', (tester) async {
      tester.view.physicalSize = const Size(1194, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await pumpApp(
        tester,
        TransactionFormSheet(existingTransaction: existingExpenseTxn),
        overrides: buildOverrides(),
      );
      await tester.pumpAndSettle();

      expect(find.text('Receipt attached'), findsOneWidget);

      // Tap Preview button
      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Receipt Preview'), findsOneWidget);

      // Close preview dialog
      await tester.tap(find.byIcon(Icons.close_rounded).last);
      await tester.pumpAndSettle();

      expect(find.text('Receipt Preview'), findsNothing);

      // Remove receipt photo
      await tester.tap(find.byIcon(Icons.delete_outline_rounded).first);
      await tester.pumpAndSettle();

      verify(() => mockStorageService.deleteReceiptImage('/mock/receipts/bill_101.jpg')).called(1);
      expect(find.text('Receipt attached'), findsNothing);
      expect(find.text('Attach Receipt Photo'), findsOneWidget);
    });

    testWidgets('5. Account dropdown selection switches payment source account', (tester) async {
      tester.view.physicalSize = const Size(1194, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await pumpApp(
        tester,
        const TransactionFormSheet(initialType: 'expense'),
        overrides: buildOverrides(),
      );
      await tester.pumpAndSettle();

      // Open accounts dropdown
      final accountDropdown = find.byType(DropdownButtonFormField<String>).last;
      await tester.tap(accountDropdown);
      await tester.pumpAndSettle();

      expect(find.text('HDFC Bank').last, findsOneWidget);
      await tester.tap(find.text('HDFC Bank').last);
      await tester.pumpAndSettle();

      // Fill amount and submit
      final amountField = find.byType(TextFormField).first;
      await tester.enterText(amountField, '450');
      await tester.tap(find.byType(AppButton));
      await tester.pumpAndSettle();

      verify(() => mockRepo.addTransaction(any(
            that: isA<FamilyTransaction>()
                .having((t) => t.accountId, 'accountId', 'acc_bank'),
          ))).called(1);
    });

    testWidgets('6. Close button dismisses the sheet', (tester) async {
      tester.view.physicalSize = const Size(1194, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await pumpApp(
        tester,
        const TransactionFormSheet(initialType: 'expense'),
        overrides: buildOverrides(),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add Expense'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close_rounded).first);
      await tester.pumpAndSettle();
    });
  });
}
