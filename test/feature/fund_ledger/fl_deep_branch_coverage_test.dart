import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:pamz_khata/core/error/failure.dart';
import 'package:pamz_khata/feature/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:pamz_khata/feature/fund_ledger/domain/entities/fl_contact.dart';
import 'package:pamz_khata/feature/fund_ledger/domain/entities/fl_transaction.dart';
import 'package:pamz_khata/feature/fund_ledger/domain/repositories/fl_contact_repository.dart';
import 'package:pamz_khata/feature/fund_ledger/domain/repositories/fl_transaction_repository.dart';
import 'package:pamz_khata/feature/fund_ledger/presentation/providers/fl_contact_providers.dart';
import 'package:pamz_khata/feature/fund_ledger/presentation/providers/fl_transaction_providers.dart';
import 'package:pamz_khata/feature/fund_ledger/presentation/widgets/fl_receive_form.dart';
import 'package:pamz_khata/feature/fund_ledger/presentation/widgets/fl_return_form.dart';
import 'package:pamz_khata/feature/fund_ledger/presentation/widgets/fl_transaction_history.dart';
import 'package:pamz_khata/feature/fund_ledger/presentation/widgets/fl_utilize_form.dart';

class DeepMockFLContactRepo implements FLContactRepository {
  final List<FLContact> items = [];

  @override
  Future<Either<Failure, void>> insert(FLContact contact) async {
    items.add(contact);
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> update(FLContact contact) async {
    final idx = items.indexWhere((c) => c.id == contact.id);
    if (idx != -1) items[idx] = contact;
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> softDelete(String id) async {
    final idx = items.indexWhere((c) => c.id == id);
    if (idx != -1) items[idx] = items[idx].copyWith(isDeleted: true);
    return const Right(null);
  }

  @override
  Future<Either<Failure, FLContact?>> findById(String id) async {
    return Right(items.where((c) => c.id == id && !c.isDeleted).firstOrNull);
  }

  @override
  Future<Either<Failure, List<FLContact>>> getAll() async {
    return Right(items.where((c) => !c.isDeleted).toList());
  }

  @override
  Future<Either<Failure, bool>> existsByMobile(String mobileNumber, {String? excludeId}) async {
    return Right(items.any((c) => c.mobileNumber == mobileNumber && c.id != excludeId && !c.isDeleted));
  }
}

class DeepMockFLTransactionRepo implements FLTransactionRepository {
  final List<FLTransaction> txns = [];

  @override
  Future<Either<Failure, void>> insert(FLTransaction transaction) async {
    txns.add(transaction);
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> update(FLTransaction transaction) async {
    final idx = txns.indexWhere((t) => t.id == transaction.id);
    if (idx != -1) txns[idx] = transaction;
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> softDelete(String id) async {
    final idx = txns.indexWhere((t) => t.id == id);
    if (idx != -1) txns[idx] = txns[idx].copyWith(isDeleted: true);
    return const Right(null);
  }

  @override
  Future<Either<Failure, List<FLTransaction>>> getByContact(String contactId) async {
    return Right(txns.where((t) => t.contactId == contactId && !t.isDeleted).toList());
  }

  @override
  Future<Either<Failure, List<FLTransaction>>> getAll({
    FLTransactionType? type,
    String? contactId,
    DateTime? from,
    DateTime? to,
  }) async {
    var list = txns.where((t) => !t.isDeleted);
    if (type != null) list = list.where((t) => t.type == type);
    if (contactId != null) list = list.where((t) => t.contactId == contactId);
    return Right(list.toList());
  }

  @override
  Future<Either<Failure, FLContactTotals>> getTotals(String contactId) async {
    double rec = 0, uti = 0, ret = 0;
    for (final t in txns.where((t) => t.contactId == contactId && !t.isDeleted)) {
      if (t.type == FLTransactionType.received) rec += t.amount;
      if (t.type == FLTransactionType.utilized) uti += t.amount;
      if (t.type == FLTransactionType.returned) ret += t.amount;
    }
    return Right(FLContactTotals(totalReceived: rec, totalUtilized: uti, totalReturned: ret));
  }

  @override
  Future<Either<Failure, FLContactTotals>> getGlobalTotals() async {
    double rec = 0, uti = 0, ret = 0;
    for (final t in txns.where((t) => !t.isDeleted)) {
      if (t.type == FLTransactionType.received) rec += t.amount;
      if (t.type == FLTransactionType.utilized) uti += t.amount;
      if (t.type == FLTransactionType.returned) ret += t.amount;
    }
    return Right(FLContactTotals(totalReceived: rec, totalUtilized: uti, totalReturned: ret));
  }
}

Widget buildTestScaffold(Widget child, {
  required DeepMockFLContactRepo contactRepo,
  required DeepMockFLTransactionRepo txnRepo,
}) {
  return ProviderScope(
    overrides: [
      flContactRepositoryProvider.overrideWithValue(contactRepo),
      flTransactionRepositoryProvider.overrideWithValue(txnRepo),
    ],
    child: ScreenUtilInit(
      designSize: const Size(800, 1200),
      minTextAdapt: true,
      builder: (_, __) => MaterialApp(
        home: Scaffold(body: child),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Fund Ledger Deep Branch Coverage Suite', () {
    late DeepMockFLContactRepo contactRepo;
    late DeepMockFLTransactionRepo txnRepo;

    final c1 = FLContact(
      id: 'c1',
      name: 'Salim Ahmed',
      mobileNumber: '9876512340',
      project: 'Community Center',
      createdAt: DateTime(2026, 3, 1),
      updatedAt: DateTime(2026, 3, 1),
    );

    setUp(() {
      contactRepo = DeepMockFLContactRepo();
      txnRepo = DeepMockFLTransactionRepo();
      contactRepo.insert(c1);
    });

    testWidgets('1. FLReceiveForm modal open, contact selector dropdown and note field', (tester) async {
      await tester.pumpWidget(
        buildTestScaffold(
          Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => FLReceiveForm.show(ctx),
              child: const Text('Open Receive Modal'),
            ),
          ),
          contactRepo: contactRepo,
          txnRepo: txnRepo,
        ),
      );
      await tester.pumpAndSettle();

      // Open modal
      await tester.tap(find.text('Open Receive Modal'));
      await tester.pumpAndSettle();

      // Verify modal elements
      expect(find.text('Record Received Fund'), findsWidgets);

      // Select contact from dropdown
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salim Ahmed (9876512340)').last);
      await tester.pumpAndSettle();

      // Enter amount & note
      await tester.enterText(find.byType(TextFormField).first, '30000');
      await tester.enterText(find.byType(TextFormField).at(1), 'Received in cash at office');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Record Received Fund').last);
      await tester.pumpAndSettle();

      expect(txnRepo.txns.length, 1);
      expect(txnRepo.txns.first.amount, 30000.0);
      expect(txnRepo.txns.first.note, 'Received in cash at office');
    });

    testWidgets('2. FLReturnForm modal open, payment mode toggle and post-save dialog', (tester) async {
      txnRepo.txns.add(
        FLTransaction(
          id: 't_rec',
          contactId: 'c1',
          type: FLTransactionType.received,
          amount: 50000.0,
          txnDate: '2026-03-01',
          createdAt: DateTime(2026, 3, 1),
          updatedAt: DateTime(2026, 3, 1),
        ),
      );

      await tester.pumpWidget(
        buildTestScaffold(
          Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => FLReturnForm.show(ctx, contactId: 'c1'),
              child: const Text('Open Return Modal'),
            ),
          ),
          contactRepo: contactRepo,
          txnRepo: txnRepo,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Return Modal'));
      await tester.pumpAndSettle();

      expect(find.text('Record Returned Fund'), findsWidgets);

      // Select UPI mode
      await tester.tap(find.text('UPI'));
      await tester.pumpAndSettle();
      expect(find.text('UTR Number *'), findsOneWidget);

      // Switch back to Cash mode (clears reference requirement)
      await tester.tap(find.text('Cash'));
      await tester.pumpAndSettle();
      expect(find.text('UTR Number *'), findsNothing);

      // Enter return amount
      await tester.enterText(find.byType(TextFormField).first, '12000');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Record Returned Fund').last);
      await tester.pumpAndSettle();

      expect(txnRepo.txns.where((t) => t.type == FLTransactionType.returned).length, 1);
    });

    testWidgets('3. FLUtilizeForm modal open with optional recipient and description fields', (tester) async {
      await tester.pumpWidget(
        buildTestScaffold(
          Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => FLUtilizeForm.show(ctx, contactId: 'c1'),
              child: const Text('Open Utilize Modal'),
            ),
          ),
          contactRepo: contactRepo,
          txnRepo: txnRepo,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Utilize Modal'));
      await tester.pumpAndSettle();

      expect(find.text('Record Fund Utilization'), findsWidgets);

      // Enter Purpose, Amount, and Optional Recipient
      await tester.enterText(find.byType(TextFormField).at(0), 'Medical Equipment');
      await tester.enterText(find.byType(TextFormField).at(1), '9500');
      await tester.enterText(find.byType(TextFormField).at(2), 'Dr. Sharma');
      await tester.enterText(find.byType(TextFormField).at(3), '9812345678');
      await tester.enterText(find.byType(TextFormField).at(4), 'Invoice #ME-102');
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Record Fund Utilization').last);
      await tester.tap(find.text('Record Fund Utilization').last);
      await tester.pumpAndSettle();

      expect(txnRepo.txns.where((t) => t.type == FLTransactionType.utilized).length, 1);
      final ut = txnRepo.txns.firstWhere((t) => t.type == FLTransactionType.utilized);
      expect(ut.title, 'Medical Equipment');
      expect(ut.amount, 9500.0);
    });

    testWidgets('4. DashboardScreen quick action triggers and navigation', (tester) async {
      txnRepo.txns.addAll([
        FLTransaction(
          id: 'tx1',
          contactId: 'c1',
          type: FLTransactionType.received,
          amount: 20000,
          txnDate: '2026-03-01',
          createdAt: DateTime(2026, 3, 1),
          updatedAt: DateTime(2026, 3, 1),
        ),
      ]);

      await tester.pumpWidget(
        buildTestScaffold(
          const DashboardScreen(),
          contactRepo: contactRepo,
          txnRepo: txnRepo,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('PAMZ Fund Responsibility Ledger'), findsOneWidget);
      expect(find.text('TOTAL AVAILABLE FUND RESPONSIBILITY'), findsOneWidget);
      expect(find.text('Quick Actions'), findsOneWidget);
      expect(find.text('Recent Activity'), findsOneWidget);

      // Tap Receive Quick Action
      await tester.tap(find.text('Receive'));
      await tester.pumpAndSettle();
      expect(find.text('Record Received Fund'), findsWidgets);
    });

    testWidgets('5. FLTransactionHistory delete transaction confirmation and soft-delete', (tester) async {
      final txn = FLTransaction(
        id: 'txn_del_1',
        contactId: 'c1',
        type: FLTransactionType.received,
        amount: 8000.0,
        txnDate: '2026-03-01',
        createdAt: DateTime(2026, 3, 1),
        updatedAt: DateTime(2026, 3, 1),
      );
      txnRepo.txns.add(txn);

      await tester.pumpWidget(
        buildTestScaffold(
          const FLTransactionHistory(contactId: 'c1'),
          contactRepo: contactRepo,
          txnRepo: txnRepo,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Fund Received'), findsOneWidget);

      // Tap delete button on transaction tile
      final deleteBtn = find.byIcon(Icons.delete_outline_rounded);
      expect(deleteBtn, findsOneWidget);
      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();

      // Confirm deletion dialog
      expect(find.text('Delete Transaction?'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(txnRepo.txns.first.isDeleted, isTrue);
    });
  });
}
