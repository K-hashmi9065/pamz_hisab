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
import 'package:pamz_khata/feature/fund_ledger/presentation/screens/fl_contact_form_screen.dart';
import 'package:pamz_khata/feature/fund_ledger/presentation/widgets/fl_receive_form.dart';
import 'package:pamz_khata/feature/fund_ledger/presentation/widgets/fl_return_form.dart';
import 'package:pamz_khata/feature/fund_ledger/presentation/widgets/fl_utilize_form.dart';

class FakeFLContactRepo implements FLContactRepository {
  final List<FLContact> contacts = [
    FLContact(
      id: 'c1',
      name: 'Rashid Khan',
      mobileNumber: '9876543210',
      aadhaarNumber: '123456789012',
      project: 'Community Fund',
      createdAt: DateTime(2026, 9, 21),
      updatedAt: DateTime(2026, 9, 21),
    ),
  ];

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
    contacts.removeWhere((c) => c.id == id);
    return const Right(null);
  }

  @override
  Future<Either<Failure, FLContact?>> findById(String id) async {
    return Right(contacts.where((c) => c.id == id).firstOrNull);
  }

  @override
  Future<Either<Failure, List<FLContact>>> getAll() async {
    return Right(List.from(contacts));
  }

  @override
  Future<Either<Failure, bool>> existsByMobile(String mobileNumber, {String? excludeId}) async {
    return Right(contacts.any((c) => c.mobileNumber == mobileNumber && c.id != excludeId));
  }
}

class FakeFLTransactionRepo implements FLTransactionRepository {
  final List<FLTransaction> txns = [];

  @override
  Future<Either<Failure, void>> insert(FLTransaction transaction) async {
    txns.add(transaction);
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> softDelete(String id) async {
    txns.removeWhere((t) => t.id == id);
    return const Right(null);
  }

  @override
  Future<Either<Failure, List<FLTransaction>>> getByContact(String contactId) async {
    return Right(txns.where((t) => t.contactId == contactId).toList());
  }

  @override
  Future<Either<Failure, List<FLTransaction>>> getAll({
    FLTransactionType? type,
    String? contactId,
    DateTime? from,
    DateTime? to,
  }) async {
    return Right(List.from(txns));
  }

  @override
  Future<Either<Failure, FLContactTotals>> getTotals(String contactId) async {
    double rec = 0, uti = 0, ret = 0;
    for (final t in txns.where((t) => t.contactId == contactId)) {
      if (t.type == FLTransactionType.received) rec += t.amount;
      if (t.type == FLTransactionType.utilized) uti += t.amount;
      if (t.type == FLTransactionType.returned) ret += t.amount;
    }
    return Right(FLContactTotals(totalReceived: rec, totalUtilized: uti, totalReturned: ret));
  }

  @override
  Future<Either<Failure, FLContactTotals>> getGlobalTotals() async {
    double rec = 0, uti = 0, ret = 0;
    for (final t in txns) {
      if (t.type == FLTransactionType.received) rec += t.amount;
      if (t.type == FLTransactionType.utilized) uti += t.amount;
      if (t.type == FLTransactionType.returned) ret += t.amount;
    }
    return Right(FLContactTotals(totalReceived: rec, totalUtilized: uti, totalReturned: ret));
  }
}

Widget buildTestableWidget(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
    child: ScreenUtilInit(
      designSize: const Size(1194, 834),
      minTextAdapt: true,
      builder: (_, __) => MaterialApp(
        home: Scaffold(body: child),
      ),
    ),
  );
}

void main() {
  group('FL Forms and Screen Tests', () {
    late FakeFLContactRepo contactRepo;
    late FakeFLTransactionRepo txnRepo;

    setUp(() {
      contactRepo = FakeFLContactRepo();
      txnRepo = FakeFLTransactionRepo();
    });

    testWidgets('FLContactFormScreen creates new contact and validates fields', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          const FLContactFormScreen(),
          overrides: [
            flContactRepositoryProvider.overrideWithValue(contactRepo),
            flTransactionRepositoryProvider.overrideWithValue(txnRepo),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('New Contact'), findsOneWidget);

      // Submit empty to trigger validation
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Please enter a name'), findsOneWidget);

      // Enter valid details
      await tester.enterText(find.byType(TextFormField).at(0), 'Ayaan Ali');
      await tester.enterText(find.byType(TextFormField).at(1), '9123456789');
      await tester.enterText(find.byType(TextFormField).at(2), '111122223333');
      await tester.enterText(find.byType(TextFormField).at(3), 'Relief Mission');

      await tester.tap(find.text('Create Contact'));
      await tester.pumpAndSettle();

      expect(contactRepo.contacts.any((c) => c.name == 'Ayaan Ali'), isTrue);
    });

    testWidgets('FLContactFormScreen edits existing contact', (tester) async {
      final existing = contactRepo.contacts.first;
      await tester.pumpWidget(
        buildTestableWidget(
          FLContactFormScreen(contact: existing),
          overrides: [
            flContactRepositoryProvider.overrideWithValue(contactRepo),
            flTransactionRepositoryProvider.overrideWithValue(txnRepo),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Edit Contact'), findsOneWidget);
      expect(find.text('Rashid Khan'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).at(0), 'Rashid Khan Updated');
      await tester.tap(find.text('Update Contact'));
      await tester.pumpAndSettle();

      expect(contactRepo.contacts.first.name, equals('Rashid Khan Updated'));
    });

    testWidgets('FLReceiveForm submits cash transaction and triggers saved popup', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          const FLReceiveForm(initialContactId: 'c1'),
          overrides: [
            flContactRepositoryProvider.overrideWithValue(contactRepo),
            flTransactionRepositoryProvider.overrideWithValue(txnRepo),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Record Received Fund'), findsWidgets);

      // Enter Amount
      await tester.enterText(find.byType(TextFormField).first, '15000');
      await tester.pumpAndSettle();

      // Tap submit
      await tester.tap(find.text('Record Received Fund').last);
      await tester.pumpAndSettle();

      expect(txnRepo.txns.length, equals(1));
      expect(txnRepo.txns.first.amount, equals(15000));
      expect(find.text('Transaction Saved'), findsOneWidget);
      expect(find.text('Not Now'), findsOneWidget);

      // Dismiss popup
      await tester.tap(find.text('Not Now'));
      await tester.pumpAndSettle();
    });

    testWidgets('FLReceiveForm UPI mode switches and requires UTR reference', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          const FLReceiveForm(initialContactId: 'c1'),
          overrides: [
            flContactRepositoryProvider.overrideWithValue(contactRepo),
            flTransactionRepositoryProvider.overrideWithValue(txnRepo),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Switch to UPI
      await tester.tap(find.text('UPI'));
      await tester.pumpAndSettle();

      // UTR field should appear
      expect(find.text('UTR Number *'), findsOneWidget);

      // Fill amount but leave UTR empty
      await tester.enterText(find.byType(TextFormField).first, '5000');
      await tester.tap(find.text('Record Received Fund').last);
      await tester.pumpAndSettle();

      expect(find.text('Please enter UTR number'), findsOneWidget);

      // Fill UTR and submit
      await tester.enterText(find.widgetWithText(TextFormField, 'UTR Number *'), 'UPI/1234567890');
      await tester.tap(find.text('Record Received Fund').last);
      await tester.pumpAndSettle();

      expect(txnRepo.txns.length, equals(1));
      expect(txnRepo.txns.first.paymentReference, equals('UPI/1234567890'));
    });

    testWidgets('FLUtilizeForm records expense with title validation', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          const FLUtilizeForm(initialContactId: 'c1'),
          overrides: [
            flContactRepositoryProvider.overrideWithValue(contactRepo),
            flTransactionRepositoryProvider.overrideWithValue(txnRepo),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Submit empty
      await tester.ensureVisible(find.text('Record Fund Utilization'));
      await tester.tap(find.text('Record Fund Utilization'));
      await tester.pumpAndSettle();
      expect(find.text('Please enter purpose/title'), findsOneWidget);

      // Fill details
      await tester.enterText(find.byType(TextFormField).at(0), 'Medical Equipment');
      await tester.enterText(find.byType(TextFormField).at(1), '4500');
      await tester.enterText(find.byType(TextFormField).at(2), 'Purchased oxygen cylinders');

      await tester.ensureVisible(find.text('Record Fund Utilization'));
      await tester.tap(find.text('Record Fund Utilization'));
      await tester.pumpAndSettle();

      expect(txnRepo.txns.length, equals(1));
      expect(txnRepo.txns.first.type, equals(FLTransactionType.utilized));
      expect(txnRepo.txns.first.title, equals('Medical Equipment'));
      expect(txnRepo.txns.first.amount, equals(4500));
    });

    testWidgets('FLReturnForm validates Return > Available Amount rejection', (tester) async {
      // Add 10,000 received
      txnRepo.txns.add(FLTransaction(
        id: 't1',
        contactId: 'c1',
        type: FLTransactionType.received,
        amount: 10000,
        txnDate: '2026-09-01',
        paymentMode: 'Cash',
        createdAt: DateTime(2026, 9, 21),
        updatedAt: DateTime(2026, 9, 21),
      ));

      await tester.pumpWidget(
        buildTestableWidget(
          const FLReturnForm(initialContactId: 'c1'),
          overrides: [
            flContactRepositoryProvider.overrideWithValue(contactRepo),
            flTransactionRepositoryProvider.overrideWithValue(txnRepo),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Enter 12,000 (exceeds available 10,000)
      await tester.enterText(find.byType(TextFormField).first, '12000');
      await tester.tap(find.text('Record Returned Fund').last);
      await tester.pumpAndSettle();

      expect(find.textContaining('cannot exceed available fund'), findsOneWidget);

      // Enter 3,000 (valid)
      await tester.enterText(find.byType(TextFormField).first, '3000');
      await tester.ensureVisible(find.text('Record Returned Fund').last);
      await tester.tap(find.text('Record Returned Fund').last);
      await tester.pumpAndSettle();

      expect(txnRepo.txns.length, equals(2));
      expect(txnRepo.txns.last.type, equals(FLTransactionType.returned));
      expect(txnRepo.txns.last.amount, equals(3000));
    });
  });
}
