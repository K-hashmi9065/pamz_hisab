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
import 'package:pamz_khata/feature/fund_ledger/presentation/screens/fl_contacts_screen.dart';
import 'package:pamz_khata/feature/fund_ledger/presentation/screens/fl_reports_screen.dart';
import 'package:pamz_khata/feature/fund_ledger/presentation/screens/fl_user_guide_screen.dart';
import 'package:pamz_khata/feature/fund_ledger/presentation/widgets/fl_receive_form.dart';
import 'package:pamz_khata/feature/fund_ledger/presentation/widgets/fl_return_form.dart';
import 'package:pamz_khata/feature/fund_ledger/presentation/widgets/fl_transaction_tile.dart';
import 'package:pamz_khata/feature/fund_ledger/presentation/widgets/fl_utilize_form.dart';

class MockFLContactRepo implements FLContactRepository {
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
    if (idx != -1) {
      contacts[idx] = contacts[idx].copyWith(isDeleted: true);
    }
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

class MockFLTransactionRepo implements FLTransactionRepository {
  final List<FLTransaction> txns = [];

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

Widget buildTestWidget(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
    child: ScreenUtilInit(
      designSize: const Size(1194, 834),
      minTextAdapt: true,
      builder: (_, __) => MaterialApp(
        home: child,
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Fund Ledger Deep Branch Coverage Tests', () {
    late MockFLContactRepo contactRepo;
    late MockFLTransactionRepo txnRepo;

    final dummyContact = FLContact(
      id: 'c100',
      name: 'Rashid Khan',
      mobileNumber: '9876500000',
      aadhaarNumber: '123456789012',
      project: 'Education Fund',
      createdAt: DateTime(2026, 3, 1),
      updatedAt: DateTime(2026, 3, 1),
    );

    setUp(() {
      contactRepo = MockFLContactRepo();
      txnRepo = MockFLTransactionRepo();
      contactRepo.insert(dummyContact);
    });

    testWidgets('FLReceiveForm supports UPI, Cheque, and Cash with validation',
        (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          const Scaffold(body: FLReceiveForm(initialContactId: 'c100')),
          overrides: [
            flContactRepositoryProvider.overrideWithValue(contactRepo),
            flTransactionRepositoryProvider.overrideWithValue(txnRepo),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Tap UPI mode
      await tester.tap(find.text('UPI'));
      await tester.pumpAndSettle();
      expect(find.text('UTR Number *'), findsOneWidget);

      // Enter amount & ref
      await tester.enterText(find.byType(TextFormField).first, '15000');
      await tester.enterText(find.byType(TextFormField).at(1), 'UPI-TXN-8877');
      await tester.pumpAndSettle();

      // Tap Save
      await tester.tap(find.text('Record Received Fund'));
      await tester.pumpAndSettle();

      expect(txnRepo.txns.length, 1);
      expect(txnRepo.txns.first.amount, 15000.0);
      expect(txnRepo.txns.first.paymentMode, 'UPI');
      expect(txnRepo.txns.first.paymentReference, 'UPI-TXN-8877');
    });

    testWidgets('FLReturnForm supports UPI and Cash with over-return validation',
        (tester) async {
      // Seed received fund of 5000
      txnRepo.txns.add(
        FLTransaction(
          id: 't_rec_1',
          contactId: 'c100',
          type: FLTransactionType.received,
          amount: 5000,
          txnDate: '2026-03-01',
          createdAt: DateTime(2026, 3, 1),
          updatedAt: DateTime(2026, 3, 1),
        ),
      );

      await tester.pumpWidget(
        buildTestWidget(
          const Scaffold(body: FLReturnForm(initialContactId: 'c100')),
          overrides: [
            flContactRepositoryProvider.overrideWithValue(contactRepo),
            flTransactionRepositoryProvider.overrideWithValue(txnRepo),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Enter over-return amount: 6000 > 5000 available
      await tester.enterText(find.byType(TextFormField).first, '6000');
      await tester.pumpAndSettle();

      // Tap Return
      await tester.tap(find.text('Record Returned Fund'));
      await tester.pumpAndSettle();

      // Validation error shown
      expect(find.textContaining('cannot exceed available fund'), findsOneWidget);

      // Fix amount to 2000 and select UPI
      await tester.enterText(find.byType(TextFormField).first, '2000');
      await tester.tap(find.text('UPI'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(1), 'UPI-REF-9988');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Record Returned Fund'));
      await tester.pumpAndSettle();

      expect(txnRepo.txns.where((t) => t.type == FLTransactionType.returned).length, 1);
    });

    testWidgets('FLUtilizeForm records expense with project and purpose details',
        (tester) async {
      // Seed received fund of 10000
      txnRepo.txns.add(
        FLTransaction(
          id: 't_rec_2',
          contactId: 'c100',
          type: FLTransactionType.received,
          amount: 10000,
          txnDate: '2026-03-01',
          createdAt: DateTime(2026, 3, 1),
          updatedAt: DateTime(2026, 3, 1),
        ),
      );

      await tester.pumpWidget(
        buildTestWidget(
          const Scaffold(body: FLUtilizeForm(initialContactId: 'c100')),
          overrides: [
            flContactRepositoryProvider.overrideWithValue(contactRepo),
            flTransactionRepositoryProvider.overrideWithValue(txnRepo),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Enter purpose (first field), amount (second field)
      await tester.enterText(find.byType(TextFormField).first, 'School Supplies for 50 students');
      await tester.enterText(find.byType(TextFormField).at(1), '3500');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Record Fund Utilization'));
      await tester.pumpAndSettle();

      expect(txnRepo.txns.where((t) => t.type == FLTransactionType.utilized).length, 1);
      final utTxn = txnRepo.txns.firstWhere((t) => t.type == FLTransactionType.utilized);
      expect(utTxn.amount, 3500.0);
      expect(utTxn.title, 'School Supplies for 50 students');
    });

    testWidgets('FLReportsScreen filters by Type and Contact',
        (tester) async {
      txnRepo.txns.addAll([
        FLTransaction(
          id: 't1',
          contactId: 'c100',
          type: FLTransactionType.received,
          amount: 20000,
          txnDate: '2026-03-01',
          createdAt: DateTime(2026, 3, 1),
          updatedAt: DateTime(2026, 3, 1),
        ),
        FLTransaction(
          id: 't2',
          contactId: 'c100',
          type: FLTransactionType.utilized,
          amount: 5000,
          title: 'Books',
          txnDate: '2026-03-02',
          createdAt: DateTime(2026, 3, 2),
          updatedAt: DateTime(2026, 3, 2),
        ),
        FLTransaction(
          id: 't3',
          contactId: 'c100',
          type: FLTransactionType.returned,
          amount: 2000,
          txnDate: '2026-03-03',
          createdAt: DateTime(2026, 3, 3),
          updatedAt: DateTime(2026, 3, 3),
        ),
      ]);

      await tester.pumpWidget(
        buildTestWidget(
          const FLReportsScreen(),
          overrides: [
            flContactRepositoryProvider.overrideWithValue(contactRepo),
            flTransactionRepositoryProvider.overrideWithValue(txnRepo),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Reports & Analytics'), findsOneWidget);
      expect(find.text('Total Received'), findsOneWidget);

      // Tap Received filter chip
      await tester.tap(find.text('Received'));
      await tester.pumpAndSettle();

      // Tap Utilized filter chip
      await tester.tap(find.text('Utilized'));
      await tester.pumpAndSettle();

      // Tap Returned filter chip
      await tester.tap(find.text('Returned'));
      await tester.pumpAndSettle();

      // Tap All Types
      await tester.tap(find.text('All Types'));
      await tester.pumpAndSettle();
    });

    testWidgets('FLContactsScreen filters search query and opens detail',
        (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          const FLContactsScreen(),
          overrides: [
            flContactRepositoryProvider.overrideWithValue(contactRepo),
            flTransactionRepositoryProvider.overrideWithValue(txnRepo),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Contacts'), findsOneWidget);
      expect(find.text('Rashid Khan'), findsOneWidget);

      // Enter search text
      await tester.enterText(find.byType(TextField), 'Rashid');
      await tester.pumpAndSettle();
      expect(find.text('Rashid Khan'), findsOneWidget);

      // Enter non-matching search text
      await tester.enterText(find.byType(TextField), 'Zebra');
      await tester.pumpAndSettle();
      expect(find.text('No matching contacts found'), findsOneWidget);
    });

    testWidgets('FLTransactionTile renders utilized, received, and returned variations',
        (tester) async {
      final rec = FLTransaction(
        id: '1',
        contactId: 'c1',
        type: FLTransactionType.received,
        amount: 2500,
        txnDate: '2026-03-01',
        paymentMode: 'Cash',
        createdAt: DateTime(2026, 3, 1),
        updatedAt: DateTime(2026, 3, 1),
      );
      final ut = FLTransaction(
        id: '2',
        contactId: 'c1',
        type: FLTransactionType.utilized,
        amount: 1200,
        title: 'Medicine Distribution',
        txnDate: '2026-03-02',
        createdAt: DateTime(2026, 3, 2),
        updatedAt: DateTime(2026, 3, 2),
      );
      final ret = FLTransaction(
        id: '3',
        contactId: 'c1',
        type: FLTransactionType.returned,
        amount: 800,
        txnDate: '2026-03-03',
        paymentMode: 'UPI',
        paymentReference: 'UPI-112233',
        createdAt: DateTime(2026, 3, 3),
        updatedAt: DateTime(2026, 3, 3),
      );

      await tester.pumpWidget(
        buildTestWidget(
          Scaffold(
            body: Column(
              children: [
                FLTransactionTile(transaction: rec),
                FLTransactionTile(transaction: ut),
                FLTransactionTile(transaction: ret),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Fund Received'), findsOneWidget);
      expect(find.text('Medicine Distribution'), findsOneWidget);
      expect(find.text('Fund Returned'), findsOneWidget);
    });

    testWidgets('FLUserGuideScreen renders all FAQ and tutorial items',
        (tester) async {
      await tester.pumpWidget(buildTestWidget(const FLUserGuideScreen()));
      await tester.pumpAndSettle();

      expect(find.text('User Guide'), findsWidgets);
      expect(find.textContaining('PAMZ Fund Responsibility Ledger'), findsWidgets);
    });
  });
}
