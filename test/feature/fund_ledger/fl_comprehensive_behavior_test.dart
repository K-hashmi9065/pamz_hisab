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
import 'package:pamz_khata/feature/fund_ledger/presentation/screens/fl_contact_form_screen.dart';
import 'package:pamz_khata/feature/fund_ledger/presentation/widgets/fl_receive_form.dart';
import 'package:pamz_khata/feature/fund_ledger/presentation/widgets/fl_return_form.dart';
import 'package:pamz_khata/feature/fund_ledger/presentation/widgets/fl_utilize_form.dart';

class InMemoryFLContactRepository implements FLContactRepository {
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
    if (idx != -1) {
      items[idx] = items[idx].copyWith(isDeleted: true);
    }
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

class InMemoryFLTransactionRepository implements FLTransactionRepository {
  final List<FLTransaction> txns = [];

  @override
  Future<Either<Failure, void>> insert(FLTransaction transaction) async {
    txns.add(transaction);
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> softDelete(String id) async {
    final idx = txns.indexWhere((t) => t.id == id);
    if (idx != -1) {
      txns[idx] = txns[idx].copyWith(isDeleted: true);
    }
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

Widget buildTestApp(Widget child, {
  required InMemoryFLContactRepository contactRepo,
  required InMemoryFLTransactionRepository txnRepo,
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
        home: child,
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Fund Ledger Comprehensive Behavioral Tests', () {
    late InMemoryFLContactRepository contactRepo;
    late InMemoryFLTransactionRepository txnRepo;

    final testContact = FLContact(
      id: 'cont_1',
      name: 'Tariq Anwer',
      mobileNumber: '9876543210',
      aadhaarNumber: '112233445566',
      project: 'Masjid Renovation',
      createdAt: DateTime(2026, 3, 1),
      updatedAt: DateTime(2026, 3, 1),
    );

    setUp(() {
      contactRepo = InMemoryFLContactRepository();
      txnRepo = InMemoryFLTransactionRepository();
      contactRepo.insert(testContact);
    });

    testWidgets('1. FLReceiveForm Cheque and Draft mode switching & validation', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const Scaffold(body: FLReceiveForm(initialContactId: 'cont_1')),
          contactRepo: contactRepo,
          txnRepo: txnRepo,
        ),
      );
      await tester.pumpAndSettle();

      // Tap Cheque mode
      await tester.tap(find.text('Cheque'));
      await tester.pumpAndSettle();
      expect(find.text('Cheque Number *'), findsOneWidget);

      // Tap Draft mode
      await tester.tap(find.text('Draft'));
      await tester.pumpAndSettle();
      expect(find.text('Draft Number *'), findsOneWidget);

      // Enter amount and draft number
      await tester.enterText(find.byType(TextFormField).first, '25000');
      await tester.enterText(find.byType(TextFormField).at(1), 'DFT-998811');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Record Received Fund'));
      await tester.pumpAndSettle();

      expect(txnRepo.txns.length, equals(1));
      expect(txnRepo.txns.first.amount, equals(25000.0));
      expect(txnRepo.txns.first.paymentMode, equals('Draft'));
      expect(txnRepo.txns.first.paymentReference, equals('DFT-998811'));
    });

    testWidgets('2. FLReturnForm validation: exact available succeeds, over-available fails', (tester) async {
      // Seed received: 10000, utilized: 6000, returned: 3000 -> Available = 7000 (NOT 1000)
      txnRepo.txns.addAll([
        FLTransaction(
          id: 't1',
          contactId: 'cont_1',
          type: FLTransactionType.received,
          amount: 10000.0,
          txnDate: '2026-03-01',
          createdAt: DateTime(2026, 3, 1),
          updatedAt: DateTime(2026, 3, 1),
        ),
        FLTransaction(
          id: 't2',
          contactId: 'cont_1',
          type: FLTransactionType.utilized,
          amount: 6000.0,
          txnDate: '2026-03-02',
          createdAt: DateTime(2026, 3, 2),
          updatedAt: DateTime(2026, 3, 2),
        ),
        FLTransaction(
          id: 't3',
          contactId: 'cont_1',
          type: FLTransactionType.returned,
          amount: 3000.0,
          txnDate: '2026-03-03',
          createdAt: DateTime(2026, 3, 3),
          updatedAt: DateTime(2026, 3, 3),
        ),
      ]);

      await tester.pumpWidget(
        buildTestApp(
          const Scaffold(body: SingleChildScrollView(child: FLReturnForm(initialContactId: 'cont_1'))),
          contactRepo: contactRepo,
          txnRepo: txnRepo,
        ),
      );
      await tester.pumpAndSettle();

      // Available should be 7000 (10000 - 3000)
      // Attempting to return 7500 (> 7000) should be blocked by validation
      await tester.enterText(find.byType(TextFormField).first, '7500');
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Record Returned Fund'));
      await tester.tap(find.text('Record Returned Fund'));
      await tester.pumpAndSettle();

      expect(find.textContaining('cannot exceed available fund'), findsOneWidget);

      // Now enter exactly 7000 (equal to remaining available responsibility)
      await tester.enterText(find.byType(TextFormField).first, '7000');
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Record Returned Fund'));
      await tester.tap(find.text('Record Returned Fund'));
      await tester.pumpAndSettle();

      // Successful return recorded
      expect(txnRepo.txns.where((t) => t.type == FLTransactionType.returned).length, equals(2));
      expect(txnRepo.txns.last.amount, equals(7000.0));
    });

    testWidgets('3. FLUtilizeForm validation: purpose and amount required', (tester) async {
      txnRepo.txns.add(
        FLTransaction(
          id: 't_rec',
          contactId: 'cont_1',
          type: FLTransactionType.received,
          amount: 50000.0,
          txnDate: '2026-03-01',
          createdAt: DateTime(2026, 3, 1),
          updatedAt: DateTime(2026, 3, 1),
        ),
      );

      await tester.pumpWidget(
        buildTestApp(
          const Scaffold(body: SingleChildScrollView(child: FLUtilizeForm(initialContactId: 'cont_1'))),
          contactRepo: contactRepo,
          txnRepo: txnRepo,
        ),
      );
      await tester.pumpAndSettle();

      // Tap submit without purpose or amount
      await tester.ensureVisible(find.text('Record Fund Utilization'));
      await tester.tap(find.text('Record Fund Utilization'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter purpose/title'), findsOneWidget);
      expect(find.text('Please enter amount'), findsOneWidget);

      // Enter valid fields
      await tester.enterText(find.byType(TextFormField).first, 'Cement and Brick Purchase');
      await tester.enterText(find.byType(TextFormField).at(1), '18000');
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Record Fund Utilization'));
      await tester.tap(find.text('Record Fund Utilization'));
      await tester.pumpAndSettle();

      expect(txnRepo.txns.where((t) => t.type == FLTransactionType.utilized).length, equals(1));
      expect(txnRepo.txns.last.title, equals('Cement and Brick Purchase'));
      expect(txnRepo.txns.last.amount, equals(18000.0));
    });

    testWidgets('4. FLContactDetailScreen tabs switching and delete dialog', (tester) async {
      txnRepo.txns.addAll([
        FLTransaction(
          id: 'tx_rec',
          contactId: 'cont_1',
          type: FLTransactionType.received,
          amount: 20000.0,
          txnDate: '2026-03-01',
          createdAt: DateTime(2026, 3, 1),
          updatedAt: DateTime(2026, 3, 1),
        ),
        FLTransaction(
          id: 'tx_ut',
          contactId: 'cont_1',
          type: FLTransactionType.utilized,
          amount: 5000.0,
          title: 'Books',
          txnDate: '2026-03-02',
          createdAt: DateTime(2026, 3, 2),
          updatedAt: DateTime(2026, 3, 2),
        ),
        FLTransaction(
          id: 'tx_ret',
          contactId: 'cont_1',
          type: FLTransactionType.returned,
          amount: 4000.0,
          txnDate: '2026-03-03',
          createdAt: DateTime(2026, 3, 3),
          updatedAt: DateTime(2026, 3, 3),
        ),
      ]);

      await tester.pumpWidget(
        buildTestApp(
          const FLContactDetailScreen(contactId: 'cont_1'),
          contactRepo: contactRepo,
          txnRepo: txnRepo,
        ),
      );
      await tester.pumpAndSettle();

      // Check header info
      expect(find.text('Tariq Anwer'), findsWidgets);
      expect(find.textContaining('9876543210'), findsWidgets);

      // Switch to Received chip
      await tester.tap(find.widgetWithText(ChoiceChip, 'Received'));
      await tester.pumpAndSettle();

      // Switch to Utilized chip
      await tester.tap(find.widgetWithText(ChoiceChip, 'Utilized'));
      await tester.pumpAndSettle();
      expect(find.text('Books'), findsOneWidget);

      // Switch to Returned chip
      await tester.tap(find.widgetWithText(ChoiceChip, 'Returned'));
      await tester.pumpAndSettle();

      // Switch to All chip
      await tester.tap(find.widgetWithText(ChoiceChip, 'All'));
      await tester.pumpAndSettle();

      // Tap Delete contact popup menu item
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete Contact'));
      await tester.pumpAndSettle();

      // Verify confirmation dialog
      expect(find.text('Delete Contact?'), findsOneWidget);

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(contactRepo.items.first.isDeleted, isFalse);
    });

    testWidgets('5. FLContactFormScreen creates new contact with validation', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const FLContactFormScreen(),
          contactRepo: contactRepo,
          txnRepo: txnRepo,
        ),
      );
      await tester.pumpAndSettle();

      // Attempt save without required fields
      await tester.tap(find.text('Create Contact'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a name'), findsOneWidget);
      expect(find.text('Please enter a mobile number'), findsOneWidget);

      // Fill in details
      await tester.enterText(find.byType(TextFormField).first, 'Imran Qureshi');
      await tester.enterText(find.byType(TextFormField).at(1), '9811223344');
      await tester.enterText(find.byType(TextFormField).at(2), '998877665544');
      await tester.enterText(find.byType(TextFormField).at(3), 'Hospital Ward');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Create Contact'));
      await tester.pumpAndSettle();

      expect(contactRepo.items.length, equals(2));
      expect(contactRepo.items.last.name, equals('Imran Qureshi'));
      expect(contactRepo.items.last.mobileNumber, equals('9811223344'));
      expect(contactRepo.items.last.project, equals('Hospital Ward'));
    });
  });
}
