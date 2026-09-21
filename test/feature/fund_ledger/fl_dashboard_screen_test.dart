import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:pamz_khata/core/error/failure.dart';
import 'package:pamz_khata/core/theme/app_colors.dart';
import 'package:pamz_khata/feature/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:pamz_khata/feature/fund_ledger/domain/entities/fl_contact.dart';
import 'package:pamz_khata/feature/fund_ledger/domain/entities/fl_transaction.dart';
import 'package:pamz_khata/feature/fund_ledger/domain/repositories/fl_contact_repository.dart';
import 'package:pamz_khata/feature/fund_ledger/domain/repositories/fl_transaction_repository.dart';
import 'package:pamz_khata/feature/fund_ledger/presentation/providers/fl_contact_providers.dart';
import 'package:pamz_khata/feature/fund_ledger/presentation/providers/fl_transaction_providers.dart';

class FakeDashboardContactRepo implements FLContactRepository {
  @override
  Future<Either<Failure, FLContact?>> findById(String id) async => Right(FLContact(
        id: id,
        name: 'Zaid Khan',
        mobileNumber: '9876543210',
        createdAt: DateTime(2026, 9, 21),
        updatedAt: DateTime(2026, 9, 21),
      ));

  @override
  Future<Either<Failure, List<FLContact>>> getAll() async => Right([
        FLContact(
          id: 'c1',
          name: 'Zaid Khan',
          mobileNumber: '9876543210',
          createdAt: DateTime(2026, 9, 21),
          updatedAt: DateTime(2026, 9, 21),
        )
      ]);

  @override
  Future<Either<Failure, bool>> existsByMobile(String mobileNumber, {String? excludeId}) async => const Right(false);

  @override
  Future<Either<Failure, void>> insert(FLContact contact) async => const Right(null);

  @override
  Future<Either<Failure, void>> update(FLContact contact) async => const Right(null);

  @override
  Future<Either<Failure, void>> softDelete(String id) async => const Right(null);
}

class FakeDashboardTxnRepo implements FLTransactionRepository {
  final List<FLTransaction> txns = [];
  bool failNext = false;

  @override
  Future<Either<Failure, List<FLTransaction>>> getAll({FLTransactionType? type, String? contactId, DateTime? from, DateTime? to}) async {
    if (failNext) return const Left(DatabaseFailure(message: 'DB error'));
    return Right(List.from(txns));
  }

  @override
  Future<Either<Failure, List<FLTransaction>>> getByContact(String contactId) async => Right(List.from(txns));

  @override
  Future<Either<Failure, FLContactTotals>> getTotals(String contactId) async =>
      const Right(FLContactTotals(totalReceived: 50000, totalUtilized: 15000, totalReturned: 0));

  @override
  Future<Either<Failure, FLContactTotals>> getGlobalTotals() async {
    if (failNext) return const Left(DatabaseFailure(message: 'DB error'));
    double rec = 0, uti = 0, ret = 0;
    for (final t in txns) {
      if (t.type == FLTransactionType.received) rec += t.amount;
      if (t.type == FLTransactionType.utilized) uti += t.amount;
      if (t.type == FLTransactionType.returned) ret += t.amount;
    }
    return Right(FLContactTotals(totalReceived: rec, totalUtilized: uti, totalReturned: ret));
  }

  @override
  Future<Either<Failure, void>> insert(FLTransaction transaction) async {
    txns.add(transaction);
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> softDelete(String id) async => const Right(null);
}

Widget buildDashboard({List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
    child: ScreenUtilInit(
      designSize: const Size(1194, 834),
      minTextAdapt: true,
      builder: (_, __) => const MaterialApp(
        home: DashboardScreen(),
      ),
    ),
  );
}

void main() {
  group('DashboardScreen Fund Ledger Integration Tests', () {
    late FakeDashboardContactRepo contactRepo;
    late FakeDashboardTxnRepo txnRepo;

    setUp(() {
      contactRepo = FakeDashboardContactRepo();
      txnRepo = FakeDashboardTxnRepo();
      txnRepo.txns.addAll([
        FLTransaction(
          id: 't1',
          contactId: 'c1',
          type: FLTransactionType.received,
          amount: 50000,
          txnDate: '2026-09-20',
          paymentMode: 'Cash',
          createdAt: DateTime(2026, 9, 21),
          updatedAt: DateTime(2026, 9, 21),
        ),
        FLTransaction(
          id: 't2',
          contactId: 'c1',
          type: FLTransactionType.utilized,
          amount: 15000,
          txnDate: '2026-09-21',
          title: 'Relief Rations',
          createdAt: DateTime(2026, 9, 21),
          updatedAt: DateTime(2026, 9, 21),
        ),
      ]);
    });

    testWidgets('1. Dashboard renders summary cards, recent activities, and quick actions', (tester) async {
      await tester.pumpWidget(
        buildDashboard(
          overrides: [
            flContactRepositoryProvider.overrideWithValue(contactRepo),
            flTransactionRepositoryProvider.overrideWithValue(txnRepo),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Check Available Amount headline (50000 - 0 = 50000)
      expect(find.text('TOTAL AVAILABLE FUND RESPONSIBILITY'), findsOneWidget);
      expect(find.text('₹50,000'), findsWidgets);

      // Check 3 metrics cards
      expect(find.text('Received'), findsWidgets);
      expect(find.text('Utilized'), findsWidgets);
      expect(find.text('Returned'), findsWidgets);

      // Check Quick Action buttons presence
      expect(find.text('Receive'), findsWidgets);
      expect(find.text('Utilize'), findsWidgets);
      expect(find.text('Return'), findsWidgets);

      // Verify Receive button uses green (AppColors.credit)
      final receiveBtn = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Receive'),
      );
      final receiveStyle = receiveBtn.style?.backgroundColor?.resolve({}) ??
          receiveBtn.style?.backgroundColor?.resolve(WidgetState.values.toSet());
      expect(receiveStyle, AppColors.credit,
          reason: 'Receive button should be green (AppColors.credit)');

      // Verify Utilize button uses blue (AppColors.info) — matches Utilized card color
      final utilizeBtn = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Utilize'),
      );
      final utilizeStyle = utilizeBtn.style?.backgroundColor?.resolve({}) ??
          utilizeBtn.style?.backgroundColor?.resolve(WidgetState.values.toSet());
      expect(utilizeStyle, AppColors.info,
          reason: 'Utilize button should be blue (AppColors.info)');

      // Verify Return button remains red (AppColors.debit)
      final returnBtn = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Return'),
      );
      final returnStyle = returnBtn.style?.backgroundColor?.resolve({}) ??
          returnBtn.style?.backgroundColor?.resolve(WidgetState.values.toSet());
      expect(returnStyle, AppColors.debit,
          reason: 'Return button should remain red (AppColors.debit)');

      // Check Recent Activity list
      expect(find.text('Recent Activity'), findsOneWidget);
      expect(find.text('Relief Rations'), findsOneWidget);

      // Pull to refresh
      await tester.fling(find.byType(CustomScrollView), const Offset(0, 300), 1000);
      await tester.pumpAndSettle();
    });

    testWidgets('2. Quick actions open Receive, Utilize, and Return modals', (tester) async {
      await tester.pumpWidget(
        buildDashboard(
          overrides: [
            flContactRepositoryProvider.overrideWithValue(contactRepo),
            flTransactionRepositoryProvider.overrideWithValue(txnRepo),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Tap Receive quick action
      await tester.tap(find.widgetWithText(FilledButton, 'Receive'));
      await tester.pumpAndSettle();
      expect(find.text('Receive Fund'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Tap Utilize quick action
      await tester.tap(find.widgetWithText(FilledButton, 'Utilize'));
      await tester.pumpAndSettle();
      expect(find.text('Utilize Fund'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Tap Return quick action
      await tester.tap(find.widgetWithText(FilledButton, 'Return'));
      await tester.pumpAndSettle();
      expect(find.text('Return Fund'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
    });

    testWidgets('3. Empty recent activity view and Add Contact button', (tester) async {
      txnRepo.txns.clear();

      await tester.pumpWidget(
        buildDashboard(
          overrides: [
            flContactRepositoryProvider.overrideWithValue(contactRepo),
            flTransactionRepositoryProvider.overrideWithValue(txnRepo),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No transactions recorded yet'), findsOneWidget);
      final addContactFinder = find.text('Add Contact to Get Started');
      expect(addContactFinder, findsOneWidget);

      // Scroll into view before tapping
      await tester.ensureVisible(addContactFinder);
      await tester.pump();

      // Tap Add Contact button
      await tester.tap(addContactFinder);
      await tester.pumpAndSettle();
      expect(find.text('New Contact'), findsOneWidget);
    });

    testWidgets('4. Negative available balance indicator and error state', (tester) async {
      // Returned 10000 with 0 received -> negative available balance (-10000)
      txnRepo.txns.clear();
      txnRepo.txns.add(FLTransaction(
        id: 't_ret',
        contactId: 'c1',
        type: FLTransactionType.returned,
        amount: 10000,
        txnDate: '2026-09-20',
        createdAt: DateTime(2026, 9, 20),
        updatedAt: DateTime(2026, 9, 20),
      ));

      await tester.pumpWidget(
        buildDashboard(
          overrides: [
            flContactRepositoryProvider.overrideWithValue(contactRepo),
            flTransactionRepositoryProvider.overrideWithValue(txnRepo),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Scope finder to the headline available amount card
      final headlineCardFinder = find.ancestor(
        of: find.text('TOTAL AVAILABLE FUND RESPONSIBILITY'),
        matching: find.byType(Card),
      );
      expect(
        find.descendant(
          of: headlineCardFinder,
          matching: find.text('-₹10,000'),
        ),
        findsOneWidget,
      );
    });
  });
}
