import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:pamz_khata/core/error/failure.dart';
import 'package:pamz_khata/feature/fund_ledger/domain/entities/fl_contact.dart';
import 'package:pamz_khata/feature/fund_ledger/domain/entities/fl_transaction.dart';
import 'package:pamz_khata/feature/fund_ledger/domain/repositories/fl_contact_repository.dart';
import 'package:pamz_khata/feature/fund_ledger/domain/repositories/fl_transaction_repository.dart';
import 'package:pamz_khata/feature/fund_ledger/presentation/providers/fl_contact_providers.dart';
import 'package:pamz_khata/feature/fund_ledger/presentation/providers/fl_transaction_providers.dart';
import 'package:pamz_khata/feature/fund_ledger/presentation/screens/fl_contact_detail_screen.dart';
import 'package:pamz_khata/feature/fund_ledger/presentation/screens/fl_contacts_screen.dart';
import 'package:pamz_khata/feature/fund_ledger/presentation/screens/fl_reports_screen.dart';
import 'package:pamz_khata/feature/fund_ledger/presentation/widgets/fl_receive_form.dart';
import 'package:pamz_khata/feature/fund_ledger/presentation/widgets/fl_return_form.dart';

class MockFLContactRepoFull implements FLContactRepository {
  final List<FLContact> contacts = [];

  @override
  Future<Either<Failure, void>> insert(FLContact contact) async {
    contacts.add(contact);
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> update(FLContact contact) async {
    final idx = contacts.indexWhere((c) => c.id == contact.id);
    if (idx != -1) contacts[idx] = contact;
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> softDelete(String id) async {
    final idx = contacts.indexWhere((c) => c.id == id);
    if (idx != -1) contacts[idx] = contacts[idx].copyWith(isDeleted: true);
    return const Right(null);
  }

  @override
  Future<Either<Failure, FLContact?>> findById(String id) async {
    return Right(contacts.where((c) => c.id == id && !c.isDeleted).firstOrNull);
  }

  @override
  Future<Either<Failure, List<FLContact>>> getAll() async {
    return Right(contacts.where((c) => !c.isDeleted).toList());
  }

  @override
  Future<Either<Failure, bool>> existsByMobile(String mobileNumber, {String? excludeId}) async {
    return Right(contacts.any((c) => c.mobileNumber == mobileNumber && c.id != excludeId && !c.isDeleted));
  }
}

class MockFLTransactionRepoFull implements FLTransactionRepository {
  final List<FLTransaction> txns = [];
  bool failNext = false;

  @override
  Future<Either<Failure, void>> insert(FLTransaction transaction) async {
    if (failNext) return const Left(DatabaseFailure(message: 'DB insert failed'));
    txns.add(transaction);
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> update(FLTransaction transaction) async {
    if (failNext) return const Left(DatabaseFailure(message: 'DB update failed'));
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

Widget buildHarness(Widget child, {
  required MockFLContactRepoFull contactRepo,
  required MockFLTransactionRepoFull txnRepo,
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

  group('Fund Ledger Deep UI & Branch Coverage Suite', () {
    late MockFLContactRepoFull contactRepo;
    late MockFLTransactionRepoFull txnRepo;

    final contact1 = FLContact(
      id: 'c101',
      name: 'Ibrahim Qureshi',
      mobileNumber: '9988776655',
      aadhaarNumber: '123456789012',
      project: 'Hospital Wing',
      createdAt: DateTime(2026, 3, 1),
      updatedAt: DateTime(2026, 3, 1),
    );

    setUp(() {
      contactRepo = MockFLContactRepoFull();
      txnRepo = MockFLTransactionRepoFull();
      contactRepo.contacts.add(contact1);
    });

    testWidgets('1. FLReceiveForm Cheque mode validation and Share PDF dialog flow', (tester) async {
      await tester.pumpWidget(
        buildHarness(
          Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => FLReceiveForm.show(ctx, contactId: 'c101'),
              child: const Text('Open Modal'),
            ),
          ),
          contactRepo: contactRepo,
          txnRepo: txnRepo,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      // Switch to Cheque mode
      await tester.tap(find.text('Cheque'));
      await tester.pumpAndSettle();
      expect(find.text('Cheque Number *'), findsOneWidget);

      // Enter amount and cheque ref
      await tester.enterText(find.byType(TextFormField).first, '45000');
      await tester.enterText(find.byType(TextFormField).at(1), 'CHQ-987654');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Record Received Fund').last);
      await tester.pumpAndSettle();

      // Verify Transaction Saved Dialog pops up
      expect(find.text('Transaction Saved'), findsOneWidget);
      expect(find.text('Share Statement PDF'), findsOneWidget);

      // Tap Share Statement PDF in dialog
      await tester.tap(find.text('Share Statement PDF'));
      await tester.pumpAndSettle();

      expect(txnRepo.txns.length, 1);
      expect(txnRepo.txns.first.paymentMode, 'Cheque');
      expect(txnRepo.txns.first.paymentReference, 'CHQ-987654');
    });

    testWidgets('2. FLReceiveForm Draft mode and failure path', (tester) async {
      txnRepo.failNext = true;

      await tester.pumpWidget(
        buildHarness(
          Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => FLReceiveForm.show(ctx, contactId: 'c101'),
              child: const Text('Open Modal'),
            ),
          ),
          contactRepo: contactRepo,
          txnRepo: txnRepo,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      // Switch to Draft mode
      await tester.tap(find.text('Draft'));
      await tester.pumpAndSettle();
      expect(find.text('Draft Number *'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).first, '15000');
      await tester.enterText(find.byType(TextFormField).at(1), 'DFT-112233');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Record Received Fund').last);
      await tester.pumpAndSettle();

      expect(find.text('Failed to record fund receive'), findsOneWidget);
    });

    testWidgets('3. FLReturnForm exact available, greater than available error, and Not Now dialog action', (tester) async {
      txnRepo.txns.add(
        FLTransaction(
          id: 'rec_1',
          contactId: 'c101',
          type: FLTransactionType.received,
          amount: 25000.0,
          txnDate: '2026-03-01',
          createdAt: DateTime(2026, 3, 1),
          updatedAt: DateTime(2026, 3, 1),
        ),
      );

      await tester.pumpWidget(
        buildHarness(
          Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => FLReturnForm.show(ctx, contactId: 'c101'),
              child: const Text('Open Return'),
            ),
          ),
          contactRepo: contactRepo,
          txnRepo: txnRepo,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Return'));
      await tester.pumpAndSettle();

      // Try return amount > available (30000 > 25000)
      await tester.enterText(find.byType(TextFormField).first, '30000');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Record Returned Fund').last);
      await tester.pumpAndSettle();

      // Validation error shown
      expect(find.textContaining('cannot exceed available fund'), findsOneWidget);

      // Now enter valid return amount (25000)
      await tester.enterText(find.byType(TextFormField).first, '25000');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Record Returned Fund').last);
      await tester.pumpAndSettle();

      // Dialog appears
      expect(find.text('Transaction Saved'), findsOneWidget);
      await tester.tap(find.text('Not Now'));
      await tester.pumpAndSettle();

      expect(txnRepo.txns.where((t) => t.type == FLTransactionType.returned).length, 1);
    });

    testWidgets('4. FLReportsScreen filter chips, date filters, and contact selection', (tester) async {
      txnRepo.txns.addAll([
        FLTransaction(
          id: 't1',
          contactId: 'c101',
          type: FLTransactionType.received,
          amount: 20000.0,
          txnDate: '2026-03-01',
          createdAt: DateTime(2026, 3, 1),
          updatedAt: DateTime(2026, 3, 1),
        ),
        FLTransaction(
          id: 't2',
          contactId: 'c101',
          type: FLTransactionType.utilized,
          amount: 5000.0,
          txnDate: '2026-03-02',
          createdAt: DateTime(2026, 3, 2),
          updatedAt: DateTime(2026, 3, 2),
        ),
        FLTransaction(
          id: 't3',
          contactId: 'c101',
          type: FLTransactionType.returned,
          amount: 3000.0,
          txnDate: '2026-03-03',
          createdAt: DateTime(2026, 3, 3),
          updatedAt: DateTime(2026, 3, 3),
        ),
      ]);

      await tester.pumpWidget(
        buildHarness(
          const FLReportsScreen(),
          contactRepo: contactRepo,
          txnRepo: txnRepo,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Reports & Analytics'), findsOneWidget);

      // Tap 'Received' chip
      await tester.tap(find.text('Received').first);
      await tester.pumpAndSettle();

      // Tap 'Utilized' chip
      await tester.tap(find.text('Utilized').first);
      await tester.pumpAndSettle();

      // Tap 'Returned' chip
      await tester.tap(find.text('Returned').first);
      await tester.pumpAndSettle();

      // Tap 'All Types' chip
      await tester.tap(find.text('All Types').first);
      await tester.pumpAndSettle();

      // Test contact filter dropdown
      expect(find.byType(DropdownButtonFormField<String?>), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<String?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ibrahim Qureshi').last);
      await tester.pumpAndSettle();

      // Switch back to All Contacts
      await tester.tap(find.byType(DropdownButtonFormField<String?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('All Contacts').last);
      await tester.pumpAndSettle();

      // Pull to refresh
      await tester.fling(find.byType(CustomScrollView), const Offset(0, 300), 1000);
      await tester.pumpAndSettle();

      // Test empty transactions state
      txnRepo.txns.clear();
      // Re-trigger rebuild
      await tester.tap(find.text('Received').first);
      await tester.pumpAndSettle();
      expect(find.text('No transactions match this filter'), findsOneWidget);
    });

    testWidgets('5. FLContactsScreen search filter and contact navigation', (tester) async {
      await tester.pumpWidget(
        buildHarness(
          const FLContactsScreen(),
          contactRepo: contactRepo,
          txnRepo: txnRepo,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Contacts'), findsWidgets);
      expect(find.text('Ibrahim Qureshi'), findsOneWidget);

      // Search matching
      await tester.enterText(find.byType(TextField).first, 'Ibrahim');
      await tester.pumpAndSettle();
      expect(find.text('Ibrahim Qureshi'), findsOneWidget);

      // Search non-matching
      await tester.enterText(find.byType(TextField).first, 'NonExistingPerson');
      await tester.pumpAndSettle();
      expect(find.text('No matching contacts found'), findsOneWidget);
    });

    testWidgets('6. FLContactDetailScreen header and action triggers', (tester) async {
      txnRepo.txns.addAll([
        FLTransaction(
          id: 't1',
          contactId: 'c101',
          type: FLTransactionType.received,
          amount: 50000.0,
          txnDate: '2026-03-01',
          createdAt: DateTime(2026, 3, 1),
          updatedAt: DateTime(2026, 3, 1),
        ),
        FLTransaction(
          id: 't2',
          contactId: 'c101',
          type: FLTransactionType.returned,
          amount: 15000.0,
          txnDate: '2026-03-02',
          createdAt: DateTime(2026, 3, 2),
          updatedAt: DateTime(2026, 3, 2),
        ),
      ]);

      await tester.pumpWidget(
        buildHarness(
          const FLContactDetailScreen(contactId: 'c101'),
          contactRepo: contactRepo,
          txnRepo: txnRepo,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ibrahim Qureshi'), findsWidgets);
      // Available = 50000 - 15000 = 35000
      expect(find.text('₹35,000'), findsWidgets);
    });
  });
}
