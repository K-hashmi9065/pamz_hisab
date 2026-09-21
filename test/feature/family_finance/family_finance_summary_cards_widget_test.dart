import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pamz_khata/core/theme/app_colors.dart';
import 'package:pamz_khata/feature/family_finance/domain/entities/family_transaction.dart';
import 'package:pamz_khata/feature/family_finance/presentation/providers/family_finance_providers.dart';
import 'package:pamz_khata/feature/family_finance/presentation/screens/family_finance_screen.dart';
import 'package:pamz_khata/feature/family_finance/presentation/widgets/family_finance_summary_cards.dart';

import '../../test_helpers/mocks.dart';
import '../../test_helpers/pump_app.dart';

void main() {
  setUpAll(registerFallbacks);

  final now = DateTime(2026, 3, 10);

  final testIncome1 = FamilyTransaction(
    id: 'inc-1',
    type: 'income',
    amount: 2000,
    categoryId: 'cat_sal',
    transactionDate: now,
    createdAt: now,
    updatedAt: now,
  );

  final testIncome2 = FamilyTransaction(
    id: 'inc-2',
    type: 'income',
    amount: 450,
    categoryId: 'cat_sal',
    transactionDate: now,
    createdAt: now,
    updatedAt: now,
  );

  final testExpense1 = FamilyTransaction(
    id: 'exp-1',
    type: 'expense',
    amount: 500,
    categoryId: 'cat_groc',
    transactionDate: now,
    createdAt: now,
    updatedAt: now,
  );

  final testExpense2 = FamilyTransaction(
    id: 'exp-2',
    type: 'expense',
    amount: 3000,
    categoryId: 'cat_groc',
    transactionDate: now,
    createdAt: now,
    updatedAt: now,
  );

  group('FamilyFinanceSummaryCards Widget Tests', () {
    late MockFamilyFinanceRepository mockRepo;

    setUp(() {
      mockRepo = MockFamilyFinanceRepository();
      when(() => mockRepo.getCategories(domain: any(named: 'domain')))
          .thenAnswer((_) async => right([]));
      when(() => mockRepo.getAccounts())
          .thenAnswer((_) async => right([]));
    });

    testWidgets('1. All 3 cards render with expected titles and icons', (tester) async {
      await pumpApp(
        tester,
        const Scaffold(body: FamilyFinanceSummaryCards()),
        overrides: [
          familyFinanceRepositoryProvider.overrideWithValue(mockRepo),
          incomeListProvider.overrideWith((ref) async => [testIncome1]),
          expenseListProvider.overrideWith((ref) async => [testExpense1]),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('Total Income'), findsOneWidget);
      expect(find.text('Total Expense'), findsOneWidget);
      expect(find.text('Net Balance'), findsOneWidget);

      expect(find.byIcon(Icons.trending_up_rounded), findsOneWidget);
      expect(find.byIcon(Icons.trending_down_rounded), findsOneWidget);
      expect(find.byIcon(Icons.account_balance_wallet_rounded), findsOneWidget);
    });

    testWidgets('2. Correct exact values render from provider data (₹2,450 | ₹500 | ₹1,950)', (tester) async {
      await pumpApp(
        tester,
        const Scaffold(body: FamilyFinanceSummaryCards()),
        overrides: [
          familyFinanceRepositoryProvider.overrideWithValue(mockRepo),
          incomeListProvider.overrideWith((ref) async => [testIncome1, testIncome2]),
          expenseListProvider.overrideWith((ref) async => [testExpense1]),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('₹2,450'), findsOneWidget);
      expect(find.text('₹500'), findsOneWidget);
      expect(find.text('₹1,950'), findsOneWidget);
    });

    testWidgets('3. Positive Net Balance uses credit/green styling', (tester) async {
      await pumpApp(
        tester,
        const Scaffold(body: FamilyFinanceSummaryCards()),
        overrides: [
          familyFinanceRepositoryProvider.overrideWithValue(mockRepo),
          incomeListProvider.overrideWith((ref) async => [testIncome1, testIncome2]),
          expenseListProvider.overrideWith((ref) async => [testExpense1]),
        ],
      );
      await tester.pumpAndSettle();

      final netTextWidget = tester.widget<Text>(find.text('₹1,950'));
      expect(netTextWidget.style?.color, AppColors.credit);
    });

    testWidgets('4. Negative Net Balance uses debit/red styling', (tester) async {
      await pumpApp(
        tester,
        const Scaffold(body: FamilyFinanceSummaryCards()),
        overrides: [
          familyFinanceRepositoryProvider.overrideWithValue(mockRepo),
          incomeListProvider.overrideWith((ref) async => [testIncome1]), // 2000
          expenseListProvider.overrideWith((ref) async => [testExpense2]), // 3000 -> Net = -1000
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('-₹1,000'), findsOneWidget);
      final netTextWidget = tester.widget<Text>(find.text('-₹1,000'));
      expect(netTextWidget.style?.color, AppColors.debit);
    });

    testWidgets('5. Empty state shows ₹0, ₹0, ₹0', (tester) async {
      await pumpApp(
        tester,
        const Scaffold(body: FamilyFinanceSummaryCards()),
        overrides: [
          familyFinanceRepositoryProvider.overrideWithValue(mockRepo),
          incomeListProvider.overrideWith((ref) async => []),
          expenseListProvider.overrideWith((ref) async => []),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('₹0'), findsNWidgets(3));
    });

    testWidgets('6a. Responsive layout on wide/tablet (1194x834) does not overflow', (tester) async {
      tester.view.physicalSize = const Size(1194, 834);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await pumpApp(
        tester,
        const FamilyFinanceScreen(),
        overrides: [
          familyFinanceRepositoryProvider.overrideWithValue(mockRepo),
          incomeListProvider.overrideWith((ref) async => [testIncome1, testIncome2]),
          expenseListProvider.overrideWith((ref) async => [testExpense1]),
        ],
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Total Income'), findsOneWidget);
      expect(find.text('Total Expense'), findsOneWidget);
      expect(find.text('Net Balance'), findsOneWidget);
      expect(find.text('₹2,450'), findsOneWidget);
    });

    testWidgets('6b. Responsive layout on narrow/mobile (375x667) does not overflow', (tester) async {
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await pumpApp(
        tester,
        const FamilyFinanceScreen(),
        overrides: [
          familyFinanceRepositoryProvider.overrideWithValue(mockRepo),
          incomeListProvider.overrideWith((ref) async => [testIncome1, testIncome2]),
          expenseListProvider.overrideWith((ref) async => [testExpense1]),
        ],
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Total Income'), findsOneWidget);
      expect(find.text('Total Expense'), findsOneWidget);
      expect(find.text('Net Balance'), findsOneWidget);
      expect(find.text('₹2,450'), findsOneWidget);
    });

    testWidgets('7. Reactive updates when provider refreshes with new transaction', (tester) async {
      var currentIncome = [testIncome1]; // ₹2,000

      final container = ProviderContainer(
        overrides: [
          familyFinanceRepositoryProvider.overrideWithValue(mockRepo),
          incomeListProvider.overrideWith((ref) async => currentIncome),
          expenseListProvider.overrideWith((ref) async => [testExpense1]), // ₹500
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: ScreenUtilInit(
            designSize: const Size(1194, 834),
            minTextAdapt: true,
            builder: (_, __) => const MaterialApp(
              home: Scaffold(body: FamilyFinanceSummaryCards()),
              debugShowCheckedModeBanner: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('₹2,000'), findsOneWidget);
      expect(find.text('₹500'), findsOneWidget);
      expect(find.text('₹1,500'), findsOneWidget);

      // Add second income transaction and invalidate provider in container
      currentIncome = [testIncome1, testIncome2]; // ₹2,450
      container.invalidate(incomeListProvider);

      await tester.pumpAndSettle();

      expect(find.text('₹2,450'), findsOneWidget);
      expect(find.text('₹500'), findsOneWidget);
      expect(find.text('₹1,950'), findsOneWidget);
    });
  });
}
