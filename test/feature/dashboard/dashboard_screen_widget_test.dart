import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pamz_khata/core/utils/currency_formatter.dart';
import 'package:pamz_khata/feature/contacts/presentation/providers/contact_providers.dart';
import 'package:pamz_khata/feature/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:pamz_khata/feature/direct_udhar/presentation/providers/direct_udhar_providers.dart';
import 'package:pamz_khata/feature/direct_udhar/presentation/widgets/direct_udhar_form_sheet.dart';
import 'package:pamz_khata/feature/family_finance/domain/entities/family_transaction.dart';
import 'package:pamz_khata/feature/family_finance/presentation/providers/family_finance_providers.dart';
import 'package:pamz_khata/feature/family_finance/presentation/widgets/transaction_form_sheet.dart';
import 'package:pamz_khata/shared/widgets/app_bar_widgets.dart';
import 'package:pamz_khata/shared/widgets/app_button.dart';
import 'package:pamz_khata/shared/widgets/app_states.dart';

import '../../test_helpers/fixtures.dart';
import '../../test_helpers/mocks.dart';
import '../../test_helpers/pump_app.dart';

void main() {
  setUpAll(registerFallbacks);

  final testContacts = [buyerFixture, supplierFixture];

  final testIncomeTxn = FamilyTransaction(
    id: 'txn-inc-dash-1',
    type: 'income',
    amount: 50000.0,
    categoryId: 'cat-sal',
    categoryName: 'Salary',
    categoryIcon: '💼',
    accountId: 'acc-bank',
    accountName: 'Bank Account',
    transactionDate: DateTime(2026, 3, 1),
    notes: 'Monthly payout',
    createdAt: DateTime(2026, 3, 1),
    updatedAt: DateTime(2026, 3, 1),
  );

  final testExpenseTxn = FamilyTransaction(
    id: 'txn-exp-dash-1',
    type: 'expense',
    amount: 15000.0,
    categoryId: 'cat-groc',
    categoryName: 'Groceries',
    categoryIcon: '🛒',
    accountId: 'acc-cash',
    accountName: 'Cash',
    transactionDate: DateTime(2026, 3, 2),
    notes: 'Weekly market haul',
    createdAt: DateTime(2026, 3, 2),
    updatedAt: DateTime(2026, 3, 2),
  );

  group('DashboardScreen Widget Tests (GAP-W01)', () {
    late MockDirectUdharRepository mockUdharRepo;
    late MockFamilyFinanceRepository mockFamilyRepo;
    late MockContactRepository mockContactRepo;

    setUp(() {
      mockUdharRepo = MockDirectUdharRepository();
      mockFamilyRepo = MockFamilyFinanceRepository();
      mockContactRepo = MockContactRepository();

      when(() => mockUdharRepo.create(any()))
          .thenAnswer((inv) async => right(inv.positionalArguments.first));
      when(() => mockFamilyRepo.getCategories(domain: any(named: 'domain')))
          .thenAnswer((_) async => right([]));
      when(() => mockFamilyRepo.getAccounts())
          .thenAnswer((_) async => right([]));
      when(() => mockContactRepo.getAll())
          .thenAnswer((_) async => right(testContacts));
    });

    List<Override> buildOverrides({
      double income = 50000.0,
      double expense = 15000.0,
      List<FamilyTransaction>? recentTransactions,
    }) {
      return [
        directUdharRepositoryProvider.overrideWithValue(mockUdharRepo),
        familyFinanceRepositoryProvider.overrideWithValue(mockFamilyRepo),
        contactRepositoryProvider.overrideWithValue(mockContactRepo),
        currentMonthIncomeProvider.overrideWithValue(AsyncValue.data(income)),
        currentMonthExpenseProvider.overrideWithValue(AsyncValue.data(expense)),
        allContactListProvider.overrideWith((ref) async => testContacts),
        allTransactionsProvider.overrideWith(
          (ref) async => recentTransactions ?? [testIncomeTxn, testExpenseTxn],
        ),
      ];
    }

    testWidgets('1. Summary cards render Total Income, Total Expense, Net Savings, and Active Contacts', (tester) async {
      tester.view.physicalSize = const Size(1194, 834);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await pumpApp(
        tester,
        const DashboardScreen(),
        overrides: buildOverrides(income: 50000.0, expense: 15000.0),
      );
      await tester.pumpAndSettle();

      // Header branding
      expect(find.text('PAMZ Hisab'), findsOneWidget);

      // Summary card titles
      expect(find.text('Total Income'), findsOneWidget);
      expect(find.text('Total Expense'), findsOneWidget);
      expect(find.text('Net Savings'), findsOneWidget);
      expect(find.text('Active Contacts'), findsOneWidget);

      // Compact formatted values: ₹50.0K, ₹15.0K, ₹35.0K
      expect(find.text(CurrencyFormatter.formatCompact(50000.0)), findsOneWidget);
      expect(find.text(CurrencyFormatter.formatCompact(15000.0)), findsOneWidget);
      expect(find.text(CurrencyFormatter.formatCompact(35000.0)), findsOneWidget);
      expect(find.text('2'), findsOneWidget); // Active contacts count
    });

    testWidgets('2. Quick Action "+ New Udhar" opens DirectUdharFormSheet modal', (tester) async {
      tester.view.physicalSize = const Size(1194, 834);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await pumpApp(
        tester,
        const DashboardScreen(),
        overrides: buildOverrides(),
      );
      await tester.pumpAndSettle();

      final newUdharBtn = find.widgetWithText(AppButton, '+ New Udhar');
      expect(newUdharBtn, findsOneWidget);
      await tester.ensureVisible(newUdharBtn);
      await tester.tap(newUdharBtn);
      await tester.pumpAndSettle();

      expect(find.byType(DirectUdharFormSheet), findsOneWidget);
      expect(find.text('New Udhar Given (Lent)'), findsOneWidget);
    });

    testWidgets('3. Quick Action "+ Expense" opens TransactionFormSheet in expense mode', (tester) async {
      tester.view.physicalSize = const Size(1194, 834);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await pumpApp(
        tester,
        const DashboardScreen(),
        overrides: buildOverrides(),
      );
      await tester.pumpAndSettle();

      final expenseBtn = find.widgetWithText(AppButton, '+ Expense');
      expect(expenseBtn, findsOneWidget);
      await tester.ensureVisible(expenseBtn);
      await tester.tap(expenseBtn);
      await tester.pumpAndSettle();

      expect(find.byType(TransactionFormSheet), findsOneWidget);
      expect(find.text('Add Expense'), findsOneWidget);
    });

    testWidgets('4. Quick Action "+ Income" opens TransactionFormSheet in income mode', (tester) async {
      tester.view.physicalSize = const Size(1194, 834);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await pumpApp(
        tester,
        const DashboardScreen(),
        overrides: buildOverrides(),
      );
      await tester.pumpAndSettle();

      final incomeBtn = find.widgetWithText(AppButton, '+ Income');
      expect(incomeBtn, findsOneWidget);
      await tester.ensureVisible(incomeBtn);
      await tester.tap(incomeBtn);
      await tester.pumpAndSettle();

      expect(find.byType(TransactionFormSheet), findsOneWidget);
      expect(find.text('Add Income'), findsOneWidget);
    });

    testWidgets('5. Recent activity displays populated transactions with credit/debit formatting', (tester) async {
      tester.view.physicalSize = const Size(1194, 834);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await pumpApp(
        tester,
        const DashboardScreen(),
        overrides: buildOverrides(
          recentTransactions: [testIncomeTxn, testExpenseTxn],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SectionHeader), findsOneWidget);
      expect(find.text('RECENT ACTIVITY'), findsOneWidget);
      expect(find.text('Salary'), findsOneWidget);
      expect(find.text('+₹50,000'), findsOneWidget);
      expect(find.text('Groceries'), findsOneWidget);
      expect(find.text('-₹15,000'), findsOneWidget);
    });

    testWidgets('6. Recent activity displays empty state when no transactions exist', (tester) async {
      tester.view.physicalSize = const Size(1194, 834);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await pumpApp(
        tester,
        const DashboardScreen(),
        overrides: buildOverrides(recentTransactions: []),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SectionHeader), findsOneWidget);
      expect(find.text('RECENT ACTIVITY'), findsOneWidget);
      expect(find.byType(AppEmptyState), findsOneWidget);
      expect(find.text('No recent activity'), findsOneWidget);
      expect(
        find.text('Record your first income, expense, or Udhar loan above'),
        findsOneWidget,
      );
    });
  });
}
