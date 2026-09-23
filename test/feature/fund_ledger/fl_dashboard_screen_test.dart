import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:pamz_khata/core/error/failure.dart';
import 'package:pamz_khata/core/utils/currency_formatter.dart';
import 'package:pamz_khata/feature/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:pamz_khata/feature/family_utilize/domain/entities/family_utilize.dart';
import 'package:pamz_khata/feature/family_utilize/domain/repositories/family_utilize_repository.dart';
import 'package:pamz_khata/feature/family_utilize/presentation/providers/family_utilize_providers.dart';
import 'package:pamz_khata/feature/fund_ledger/domain/entities/fl_contact.dart';
import 'package:pamz_khata/feature/fund_ledger/domain/entities/fl_dashboard_summary.dart';
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
      if (t.isDeleted) continue;
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
  Future<Either<Failure, void>> update(FLTransaction transaction) async {
    final idx = txns.indexWhere((t) => t.id == transaction.id);
    if (idx != -1) {
      txns[idx] = transaction;
    }
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> softDelete(String id) async => const Right(null);
}

class FakeDashboardFamilyRepo implements FamilyUtilizeRepository {
  double totalFamily = 0.0;

  @override
  Future<Either<Failure, double>> getTotalFamilyUtilized({DateTime? from, DateTime? to}) async {
    return Right(totalFamily);
  }

  @override
  Future<Either<Failure, List<FamilyUtilize>>> getAll({
    String? category,
    DateTime? from,
    DateTime? to,
    String? searchQuery,
  }) async {
    return const Right([]);
  }

  @override
  Future<Either<Failure, FamilyUtilize?>> getById(String id) async => const Right(null);

  @override
  Future<Either<Failure, void>> insert(FamilyUtilize item) async => const Right(null);

  @override
  Future<Either<Failure, void>> update(FamilyUtilize item) async => const Right(null);

  @override
  Future<Either<Failure, void>> softDelete(String id) async => const Right(null);
}

Widget buildDashboard({
  List<Override> overrides = const [],
  Size screenSize = const Size(1194, 834),
}) {
  return ProviderScope(
    overrides: overrides,
    child: ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      builder: (_, __) => MediaQuery(
        data: MediaQueryData(size: screenSize),
        child: const MaterialApp(
          home: DashboardScreen(),
        ),
      ),
    ),
  );
}

void main() {
  group('DashboardScreen Top 3 Summary Cards and Formulas Integration Tests', () {
    late FakeDashboardContactRepo contactRepo;
    late FakeDashboardTxnRepo txnRepo;
    late FakeDashboardFamilyRepo familyRepo;

    setUp(() {
      contactRepo = FakeDashboardContactRepo();
      txnRepo = FakeDashboardTxnRepo();
      familyRepo = FakeDashboardFamilyRepo();
    });

    test('1. Entity formula validation: FLDashboardSummary calculates available and totalUtilized correctly', () {
      const summary1 = FLDashboardSummary(
        totalReceived: 750000,
        totalReturned: 200000,
        totalContactUtilized: 25000,
        totalFamilyUtilized: 10000,
        recentTransactions: [],
      );

      // Available Balance = 750000 - 200000 - (25000 + 10000) = 515000
      expect(summary1.availableBalance, 515000);
      expect(summary1.totalContactUtilized, 25000);
      // Total Utilized = 25000 + 10000 = 35000
      expect(summary1.totalUtilized, 35000);

      const summary2 = FLDashboardSummary(
        totalReceived: 10000,
        totalReturned: 3000,
        totalContactUtilized: 6000,
        totalFamilyUtilized: 0,
        recentTransactions: [],
      );

      expect(summary2.availableBalance, 1000); // 10000 - 3000 - 6000
      expect(summary2.totalContactUtilized, 6000);
      expect(summary2.totalUtilized, 6000);
    });

    test('2. Indian currency formatting: exact format with no abbreviations', () {
      expect(CurrencyFormatter.formatIndian(540000), '₹5,40,000');
      expect(CurrencyFormatter.formatIndian(25000), '₹25,000');
      expect(CurrencyFormatter.formatIndian(35000), '₹35,000');
      expect(CurrencyFormatter.formatIndian(7000), '₹7,000');
      expect(CurrencyFormatter.formatIndian(0), '₹0');
      expect(CurrencyFormatter.formatIndian(-10000), '-₹10,000');
    });

    testWidgets('3. Renders 3 top summary cards with exact values in wide layout (Desktop / iPad)', (tester) async {
      txnRepo.txns.addAll([
        FLTransaction(
          id: 't1',
          contactId: 'c1',
          type: FLTransactionType.received,
          amount: 750000,
          txnDate: '2026-09-20',
          createdAt: DateTime(2026, 9, 20),
          updatedAt: DateTime(2026, 9, 20),
        ),
        FLTransaction(
          id: 't2',
          contactId: 'c1',
          type: FLTransactionType.returned,
          amount: 200000,
          txnDate: '2026-09-21',
          createdAt: DateTime(2026, 9, 21),
          updatedAt: DateTime(2026, 9, 21),
        ),
        FLTransaction(
          id: 't3',
          contactId: 'c1',
          type: FLTransactionType.utilized,
          amount: 25000,
          txnDate: '2026-09-21',
          title: 'Relief Rations',
          createdAt: DateTime(2026, 9, 21),
          updatedAt: DateTime(2026, 9, 21),
        ),
      ]);
      familyRepo.totalFamily = 10000;

      await tester.binding.setSurfaceSize(const Size(1024, 768));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        buildDashboard(
          screenSize: const Size(1024, 768),
          overrides: [
            flContactRepositoryProvider.overrideWithValue(contactRepo),
            flTransactionRepositoryProvider.overrideWithValue(txnRepo),
            familyUtilizeRepositoryProvider.overrideWithValue(familyRepo),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Top 3 summary cards
      expect(find.text('Available Balance'), findsWidgets);
      expect(find.text('₹5,15,000'), findsWidgets);
      expect(find.text('Received - Returned - Total Utilized'), findsWidgets);

      expect(find.text('Contact Utilized'), findsWidgets);
      expect(find.text('₹25,000'), findsWidgets);
      expect(find.text('Fund Ledger Contacts'), findsWidgets);

      expect(find.text('Total Utilized'), findsWidgets);
      expect(find.text('₹35,000'), findsWidgets);
      expect(find.text('Contact + Family'), findsWidgets);

      // Lower metrics cards remain present
      expect(find.text('Received'), findsWidgets);
      expect(find.text('Returned'), findsWidgets);
      expect(find.text('Family Utilized'), findsWidgets);

      // Quick actions
      expect(find.text('Receive'), findsWidgets);
      expect(find.text('Family Utilize'), findsWidgets);
      expect(find.text('Return'), findsWidgets);
      expect(find.text('Add Contact'), findsWidgets);
    });

    testWidgets('4. Mobile screen layout renders without overflow', (tester) async {
      txnRepo.txns.addAll([
        FLTransaction(
          id: 't1',
          contactId: 'c1',
          type: FLTransactionType.received,
          amount: 10000,
          txnDate: '2026-09-20',
          createdAt: DateTime(2026, 9, 20),
          updatedAt: DateTime(2026, 9, 20),
        ),
        FLTransaction(
          id: 't2',
          contactId: 'c1',
          type: FLTransactionType.returned,
          amount: 3000,
          txnDate: '2026-09-21',
          createdAt: DateTime(2026, 9, 21),
          updatedAt: DateTime(2026, 9, 21),
        ),
        FLTransaction(
          id: 't3',
          contactId: 'c1',
          type: FLTransactionType.utilized,
          amount: 6000,
          txnDate: '2026-09-21',
          createdAt: DateTime(2026, 9, 21),
          updatedAt: DateTime(2026, 9, 21),
        ),
      ]);
      familyRepo.totalFamily = 0;

      await tester.binding.setSurfaceSize(const Size(375, 812));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        buildDashboard(
          screenSize: const Size(375, 812),
          overrides: [
            flContactRepositoryProvider.overrideWithValue(contactRepo),
            flTransactionRepositoryProvider.overrideWithValue(txnRepo),
            familyUtilizeRepositoryProvider.overrideWithValue(familyRepo),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Available balance is ₹1,000 (10000 - 3000 - 6000)
      expect(find.text('₹1,000'), findsWidgets);
      expect(find.text('₹6,000'), findsWidgets); // Contact Utilized and Total Utilized
    });

    testWidgets('5. Quick actions modal interaction and negative balance', (tester) async {
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
            familyUtilizeRepositoryProvider.overrideWithValue(familyRepo),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Negative balance is formatted accurately
      expect(find.text('-₹10,000'), findsOneWidget);

      // Tap Receive quick action
      await tester.tap(find.widgetWithText(FilledButton, 'Receive'));
      await tester.pumpAndSettle();
      expect(find.text('Receive Fund'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Tap Family Utilize quick action
      await tester.tap(find.widgetWithText(FilledButton, 'Family Utilize'));
      await tester.pumpAndSettle();
      expect(find.text('Add Family Utilization'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      // Tap Return quick action
      await tester.tap(find.widgetWithText(FilledButton, 'Return'));
      await tester.pumpAndSettle();
      expect(find.text('Return Fund'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
    });
  });
}
