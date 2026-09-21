import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:pamz_khata/core/error/failure.dart';
import 'package:pamz_khata/feature/fund_ledger/data/services/fl_share_service.dart';
import 'package:pamz_khata/feature/fund_ledger/domain/entities/fl_contact.dart';
import 'package:pamz_khata/feature/fund_ledger/domain/entities/fl_share_statement.dart';
import 'package:pamz_khata/feature/fund_ledger/domain/entities/fl_transaction.dart';
import 'package:pamz_khata/feature/fund_ledger/domain/repositories/fl_contact_repository.dart';
import 'package:pamz_khata/feature/fund_ledger/domain/repositories/fl_transaction_repository.dart';
import 'package:pamz_khata/feature/fund_ledger/presentation/providers/fl_contact_providers.dart';
import 'package:pamz_khata/feature/fund_ledger/presentation/providers/fl_transaction_providers.dart';
import 'package:pamz_khata/feature/fund_ledger/presentation/widgets/fl_receive_form.dart';
import 'package:pamz_khata/feature/fund_ledger/presentation/widgets/fl_return_form.dart';
import 'package:pamz_khata/feature/fund_ledger/presentation/widgets/fl_utilize_form.dart';

class _FakeFLContactRepo implements FLContactRepository {
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

class _FakeFLTransactionRepo implements FLTransactionRepository {
  final List<FLTransaction> txns = [];
  bool failNext = false;

  @override
  Future<Either<Failure, void>> insert(FLTransaction transaction) async {
    if (failNext) return const Left(DatabaseFailure(message: 'DB insert failed'));
    txns.add(transaction);
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

class _FakeFLShareService extends FLShareService {
  _FakeFLShareService() : super();
  bool shareCalled = false;
  FLShareStatement? lastStatement;

  @override
  Future<bool> shareStatement(FLShareStatement statement) async {
    shareCalled = true;
    lastStatement = statement;
    return true;
  }
}

Widget _buildHarness(Widget child, {
  required _FakeFLContactRepo contactRepo,
  required _FakeFLTransactionRepo txnRepo,
  required _FakeFLShareService shareService,
}) {
  return ProviderScope(
    overrides: [
      flContactRepositoryProvider.overrideWithValue(contactRepo),
      flTransactionRepositoryProvider.overrideWithValue(txnRepo),
      flShareServiceProvider.overrideWithValue(shareService),
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

  late _FakeFLContactRepo contactRepo;
  late _FakeFLTransactionRepo txnRepo;
  late _FakeFLShareService shareService;

  final testContact = FLContact(
    id: 'c101',
    name: 'Mustafa Ali',
    mobileNumber: '9876543210',
    aadhaarNumber: '111122223333',
    project: 'Disaster Relief',
    createdAt: DateTime(2026, 9, 21),
    updatedAt: DateTime(2026, 9, 21),
  );

  setUp(() {
    contactRepo = _FakeFLContactRepo();
    txnRepo = _FakeFLTransactionRepo();
    shareService = _FakeFLShareService();
    contactRepo.contacts.add(testContact);
  });

  group('FLReturnForm Comprehensive Tests', () {
    testWidgets('1. Contact dropdown selection when initialContactId is null', (tester) async {
      // Add received transaction so contact has available balance
      txnRepo.txns.add(FLTransaction(
        id: 'rec1',
        contactId: 'c101',
        type: FLTransactionType.received,
        amount: 50000,
        txnDate: '2026-09-20',
        createdAt: DateTime(2026, 9, 20),
        updatedAt: DateTime(2026, 9, 20),
      ));

      await tester.pumpWidget(
        _buildHarness(
          Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => FLReturnForm.show(ctx),
              child: const Text('Open Modal'),
            ),
          ),
          contactRepo: contactRepo,
          txnRepo: txnRepo,
          shareService: shareService,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      // Submit without selecting contact
      await tester.ensureVisible(find.text('Record Returned Fund').last);
      await tester.tap(find.text('Record Returned Fund').last);
      await tester.pumpAndSettle();
      expect(find.text('Please select a contact'), findsOneWidget);

      // Select contact from dropdown
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mustafa Ali (9876543210)').last);
      await tester.pumpAndSettle();

      // Available balance indicator should appear
      expect(find.text('Max Available to Return:'), findsOneWidget);
    });

    testWidgets('2. Cheque and Draft payment mode selection & validation', (tester) async {
      txnRepo.txns.add(FLTransaction(
        id: 'rec1',
        contactId: 'c101',
        type: FLTransactionType.received,
        amount: 50000,
        txnDate: '2026-09-20',
        createdAt: DateTime(2026, 9, 20),
        updatedAt: DateTime(2026, 9, 20),
      ));

      await tester.pumpWidget(
        _buildHarness(
          Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => FLReturnForm.show(ctx, contactId: 'c101'),
              child: const Text('Open Modal'),
            ),
          ),
          contactRepo: contactRepo,
          txnRepo: txnRepo,
          shareService: shareService,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      // Enter amount
      await tester.enterText(find.widgetWithText(TextFormField, 'Return Amount (₹) *'), '10000');

      // Switch to Cheque
      await tester.tap(find.text('Cheque'));
      await tester.pumpAndSettle();
      expect(find.text('Cheque Number *'), findsOneWidget);

      // Submit without cheque number
      await tester.ensureVisible(find.text('Record Returned Fund').last);
      await tester.tap(find.text('Record Returned Fund').last);
      await tester.pumpAndSettle();
      expect(find.text('Please enter Cheque number'), findsOneWidget);

      // Switch to Draft
      await tester.tap(find.text('Draft'));
      await tester.pumpAndSettle();
      expect(find.text('Draft Number *'), findsOneWidget);

      // Submit without draft number
      await tester.ensureVisible(find.text('Record Returned Fund').last);
      await tester.tap(find.text('Record Returned Fund').last);
      await tester.pumpAndSettle();
      expect(find.text('Please enter Draft number'), findsOneWidget);

      // Fill draft number and note, then submit
      await tester.enterText(find.widgetWithText(TextFormField, 'Draft Number *'), 'DFT-9988');
      await tester.enterText(find.widgetWithText(TextFormField, 'Note (Optional)'), 'Refund of excess fund');
      await tester.ensureVisible(find.text('Record Returned Fund').last);
      await tester.tap(find.text('Record Returned Fund').last);
      await tester.pumpAndSettle();

      expect(txnRepo.txns.where((t) => t.type == FLTransactionType.returned).length, 1);
      expect(txnRepo.txns.last.paymentMode, 'Draft');
      expect(txnRepo.txns.last.paymentReference, 'DFT-9988');
      expect(txnRepo.txns.last.note, 'Refund of excess fund');

      // Share Statement PDF from dialog
      expect(find.text('Transaction Saved'), findsOneWidget);
      await tester.tap(find.text('Share Statement PDF'));
      await tester.pumpAndSettle();
      expect(shareService.shareCalled, isTrue);
      expect(shareService.lastStatement?.contactName, 'Mustafa Ali');
    });

    testWidgets('3. Date & Time pickers interaction and close button', (tester) async {
      await tester.pumpWidget(
        _buildHarness(
          Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => FLReturnForm.show(ctx, contactId: 'c101'),
              child: const Text('Open Modal'),
            ),
          ),
          contactRepo: contactRepo,
          txnRepo: txnRepo,
          shareService: shareService,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      // Open Date Picker and select OK
      await tester.tap(find.byIcon(Icons.calendar_today));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Open Time Picker and select OK
      await tester.tap(find.byIcon(Icons.access_time));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Close modal using close button
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.text('Return Fund'), findsNothing);
    });

    testWidgets('4. Amount zero/negative validation and DB failure handling', (tester) async {
      txnRepo.failNext = true;
      txnRepo.txns.add(FLTransaction(
        id: 'rec1',
        contactId: 'c101',
        type: FLTransactionType.received,
        amount: 50000,
        txnDate: '2026-09-20',
        createdAt: DateTime(2026, 9, 20),
        updatedAt: DateTime(2026, 9, 20),
      ));

      await tester.pumpWidget(
        _buildHarness(
          Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => FLReturnForm.show(ctx, contactId: 'c101'),
              child: const Text('Open Modal'),
            ),
          ),
          contactRepo: contactRepo,
          txnRepo: txnRepo,
          shareService: shareService,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      // Test zero amount
      await tester.enterText(find.widgetWithText(TextFormField, 'Return Amount (₹) *'), '0');
      await tester.ensureVisible(find.text('Record Returned Fund').last);
      await tester.tap(find.text('Record Returned Fund').last);
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid amount greater than 0'), findsOneWidget);

      // Enter valid amount but repo fails
      await tester.enterText(find.widgetWithText(TextFormField, 'Return Amount (₹) *'), '5000');
      await tester.ensureVisible(find.text('Record Returned Fund').last);
      await tester.tap(find.text('Record Returned Fund').last);
      await tester.pumpAndSettle();
      expect(find.text('Failed to record fund return'), findsOneWidget);
    });
  });

  group('FLReceiveForm Comprehensive Tests', () {
    testWidgets('1. Contact dropdown selection when initialContactId is null', (tester) async {
      await tester.pumpWidget(
        _buildHarness(
          Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => FLReceiveForm.show(ctx),
              child: const Text('Open Modal'),
            ),
          ),
          contactRepo: contactRepo,
          txnRepo: txnRepo,
          shareService: shareService,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      // Submit without contact
      await tester.ensureVisible(find.text('Record Received Fund').last);
      await tester.tap(find.text('Record Received Fund').last);
      await tester.pumpAndSettle();
      expect(find.text('Please select a contact'), findsOneWidget);

      // Select contact
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mustafa Ali (9876543210)').last);
      await tester.pumpAndSettle();

      expect(find.text('Mustafa Ali (9876543210)'), findsOneWidget);
    });

    testWidgets('2. Draft payment mode, Date & Time pickers, and Share PDF flow', (tester) async {
      await tester.pumpWidget(
        _buildHarness(
          Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => FLReceiveForm.show(ctx, contactId: 'c101'),
              child: const Text('Open Modal'),
            ),
          ),
          contactRepo: contactRepo,
          txnRepo: txnRepo,
          shareService: shareService,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      // Open Date Picker and select OK
      await tester.tap(find.byIcon(Icons.calendar_today));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Open Time Picker and select OK
      await tester.tap(find.byIcon(Icons.access_time));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Switch to Draft
      await tester.tap(find.text('Draft'));
      await tester.pumpAndSettle();
      expect(find.text('Draft Number *'), findsOneWidget);

      // Empty amount & draft validation
      await tester.ensureVisible(find.text('Record Received Fund').last);
      await tester.tap(find.text('Record Received Fund').last);
      await tester.pumpAndSettle();
      expect(find.text('Please enter amount'), findsOneWidget);
      expect(find.text('Please enter Draft number'), findsOneWidget);

      // Enter details
      await tester.enterText(find.widgetWithText(TextFormField, 'Amount (₹) *'), '75000');
      await tester.enterText(find.widgetWithText(TextFormField, 'Draft Number *'), 'DFT-5544');
      await tester.enterText(find.widgetWithText(TextFormField, 'Note (Optional)'), 'Received via Draft');
      await tester.ensureVisible(find.text('Record Received Fund').last);
      await tester.tap(find.text('Record Received Fund').last);
      await tester.pumpAndSettle();

      expect(txnRepo.txns.length, 1);
      expect(txnRepo.txns.first.paymentMode, 'Draft');
      expect(txnRepo.txns.first.paymentReference, 'DFT-5544');

      // Share Statement from dialog
      expect(find.text('Transaction Saved'), findsOneWidget);
      await tester.tap(find.text('Share Statement PDF'));
      await tester.pumpAndSettle();
      expect(shareService.shareCalled, isTrue);
    });

    testWidgets('3. Close button dismisses modal and DB failure snackbar', (tester) async {
      txnRepo.failNext = true;

      await tester.pumpWidget(
        _buildHarness(
          Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => FLReceiveForm.show(ctx, contactId: 'c101'),
              child: const Text('Open Modal'),
            ),
          ),
          contactRepo: contactRepo,
          txnRepo: txnRepo,
          shareService: shareService,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      // Enter amount and submit (fails due to failNext)
      await tester.enterText(find.widgetWithText(TextFormField, 'Amount (₹) *'), '20000');
      await tester.ensureVisible(find.text('Record Received Fund').last);
      await tester.tap(find.text('Record Received Fund').last);
      await tester.pumpAndSettle();
      expect(find.text('Failed to record fund receive'), findsOneWidget);

      // Close modal
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.text('Receive Fund'), findsNothing);
    });
  });

  group('FLUtilizeForm Comprehensive Tests', () {
    testWidgets('1. Contact dropdown selection, Purpose validation, and Phone input', (tester) async {
      await tester.pumpWidget(
        _buildHarness(
          Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => FLUtilizeForm.show(ctx),
              child: const Text('Open Modal'),
            ),
          ),
          contactRepo: contactRepo,
          txnRepo: txnRepo,
          shareService: shareService,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      // Submit without contact
      await tester.ensureVisible(find.text('Record Fund Utilization'));
      await tester.tap(find.text('Record Fund Utilization'));
      await tester.pumpAndSettle();
      expect(find.text('Please select a contact'), findsOneWidget);

      // Select contact
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mustafa Ali (9876543210)').last);
      await tester.pumpAndSettle();

      // Submit without title and amount
      await tester.ensureVisible(find.text('Record Fund Utilization'));
      await tester.tap(find.text('Record Fund Utilization'));
      await tester.pumpAndSettle();
      expect(find.text('Please enter purpose/title'), findsOneWidget);
      expect(find.text('Please enter amount'), findsOneWidget);

      // Open Date Picker and select OK
      await tester.tap(find.byIcon(Icons.calendar_today));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Open Time Picker and select OK
      await tester.tap(find.byIcon(Icons.access_time));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Fill all fields
      await tester.enterText(find.widgetWithText(TextFormField, 'Purpose / Title *'), 'Grocery Distribution');
      await tester.enterText(find.widgetWithText(TextFormField, 'Amount (₹) *'), '18500');
      await tester.enterText(find.widgetWithText(TextFormField, 'Recipient / Vendor Mobile (Optional)'), '9811223344');
      await tester.enterText(find.widgetWithText(TextFormField, 'Description (Optional)'), 'Bought rations for 50 families');
      await tester.enterText(find.widgetWithText(TextFormField, 'Note (Optional)'), 'Receipt attached in file');

      await tester.ensureVisible(find.text('Record Fund Utilization'));
      await tester.tap(find.text('Record Fund Utilization'));
      await tester.pumpAndSettle();

      expect(txnRepo.txns.length, 1);
      expect(txnRepo.txns.first.type, FLTransactionType.utilized);
      expect(txnRepo.txns.first.title, 'Grocery Distribution');
      expect(txnRepo.txns.first.amount, 18500);
      expect(txnRepo.txns.first.description, 'Bought rations for 50 families');
      expect(txnRepo.txns.first.note, 'Receipt attached in file');
      expect(find.text('Fund utilization recorded internally'), findsOneWidget);
    });

    testWidgets('2. Close button and DB failure handling', (tester) async {
      txnRepo.failNext = true;

      await tester.pumpWidget(
        _buildHarness(
          Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => FLUtilizeForm.show(ctx, contactId: 'c101'),
              child: const Text('Open Modal'),
            ),
          ),
          contactRepo: contactRepo,
          txnRepo: txnRepo,
          shareService: shareService,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      // Zero amount validation
      await tester.enterText(find.widgetWithText(TextFormField, 'Purpose / Title *'), 'Test');
      await tester.enterText(find.widgetWithText(TextFormField, 'Amount (₹) *'), '0');
      await tester.ensureVisible(find.text('Record Fund Utilization'));
      await tester.tap(find.text('Record Fund Utilization'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid amount greater than 0'), findsOneWidget);

      // Valid amount with failure
      await tester.enterText(find.widgetWithText(TextFormField, 'Amount (₹) *'), '2000');
      await tester.ensureVisible(find.text('Record Fund Utilization'));
      await tester.tap(find.text('Record Fund Utilization'));
      await tester.pumpAndSettle();
      expect(find.text('Failed to record fund utilization'), findsOneWidget);

      // Close modal
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.text('Utilize Fund'), findsNothing);
    });
  });
}
