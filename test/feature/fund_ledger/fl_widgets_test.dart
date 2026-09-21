import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:pamz_khata/core/error/failure.dart';
import 'package:pamz_khata/core/theme/app_colors.dart';
import 'package:pamz_khata/feature/fund_ledger/domain/entities/fl_contact.dart';
import 'package:pamz_khata/feature/fund_ledger/domain/entities/fl_transaction.dart';
import 'package:pamz_khata/feature/fund_ledger/domain/repositories/fl_contact_repository.dart';
import 'package:pamz_khata/feature/fund_ledger/domain/repositories/fl_transaction_repository.dart';
import 'package:pamz_khata/feature/fund_ledger/presentation/providers/fl_contact_providers.dart';
import 'package:pamz_khata/feature/fund_ledger/presentation/providers/fl_transaction_providers.dart';
import 'package:pamz_khata/feature/fund_ledger/presentation/widgets/fl_contact_card.dart';
import 'package:pamz_khata/feature/fund_ledger/presentation/widgets/fl_payment_mode_field.dart';
import 'package:pamz_khata/feature/fund_ledger/presentation/widgets/fl_receive_form.dart';
import 'package:pamz_khata/feature/fund_ledger/presentation/widgets/fl_return_form.dart';
import 'package:pamz_khata/feature/fund_ledger/presentation/widgets/fl_summary_card.dart';
import 'package:pamz_khata/feature/fund_ledger/presentation/widgets/fl_transaction_tile.dart';
import 'package:pamz_khata/feature/fund_ledger/presentation/widgets/fl_utilize_form.dart';

class _FakeFLContactRepo implements FLContactRepository {
  final List<FLContact> contacts = [
    FLContact(
      id: 'c1',
      name: 'Tariq Ahmad',
      mobileNumber: '9988776655',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
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

class _FakeFLTransactionRepo implements FLTransactionRepository {
  final List<FLTransaction> txns = [
    FLTransaction(
      id: 't1',
      contactId: 'c1',
      type: FLTransactionType.received,
      amount: 50000,
      txnDate: '2026-09-01',
      paymentMode: 'Cash',
      createdAt: DateTime(2026, 9, 1),
      updatedAt: DateTime(2026, 9, 1),
    ),
  ];

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

Widget _wrapWidget(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
    child: ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      builder: (_, __) => MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
}

void main() {
  group('Fund Ledger Presentation Widget Tests', () {
    testWidgets('1. FLSummaryCard renders title, amount and icon', (tester) async {
      await tester.pumpWidget(
        _wrapWidget(
          const FLSummaryCard(
            label: 'Total Received',
            amount: 75000.0,
            icon: Icons.arrow_downward_rounded,
            color: AppColors.credit,
            subtitle: 'All contributors',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Total Received'), findsOneWidget);
      expect(find.text('All contributors'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_downward_rounded), findsOneWidget);
    });

    testWidgets('2. FLContactCard renders contact details and 3 metrics', (tester) async {
      final summary = FLContactSummaryData(
        contact: FLContact(
          id: 'contact-01',
          name: 'Tariq Ahmad',
          mobileNumber: '9988776655',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        totalReceived: 60000.0,
        totalUtilized: 20000.0,
        totalReturned: 10000.0,
      );

      await tester.pumpWidget(
        _wrapWidget(
          FLContactCard(
            summary: summary,
            onTap: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tariq Ahmad'), findsOneWidget);
      expect(find.text('9988776655'), findsOneWidget);
      expect(find.text('Received'), findsOneWidget);
      expect(find.text('Utilized'), findsOneWidget);
      expect(find.text('Returned'), findsOneWidget);
    });

    testWidgets('3. FLTransactionTile renders received transaction correctly', (tester) async {
      final txn = FLTransaction(
        id: 'txn-1',
        contactId: 'c1',
        type: FLTransactionType.received,
        amount: 25000.0,
        txnDate: '2026-09-21',
        paymentMode: 'UPI',
        paymentReference: 'UPI/001122',
        note: 'Donation for school books',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        _wrapWidget(FLTransactionTile(transaction: txn)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Fund Received'), findsOneWidget);
      expect(find.text('Donation for school books'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_downward_rounded), findsOneWidget);
    });

    testWidgets('4. FLPaymentModeField renders chips and triggers callback', (tester) async {
      String selected = 'Cash';

      await tester.pumpWidget(
        _wrapWidget(
          StatefulBuilder(
            builder: (context, setState) => FLPaymentModeField(
              selectedMode: selected,
              onChanged: (mode) => setState(() => selected = mode),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Payment Mode'), findsOneWidget);
      expect(find.text('Cash'), findsOneWidget);
      expect(find.text('UPI'), findsOneWidget);
      expect(find.text('Cheque'), findsOneWidget);
      expect(find.text('Draft'), findsOneWidget);

      await tester.tap(find.text('UPI'));
      await tester.pumpAndSettle();
      expect(selected, equals('UPI'));
    });

    testWidgets('5. FLReceiveForm modal renders fields and validates amount', (tester) async {
      final contactRepo = _FakeFLContactRepo();
      final txnRepo = _FakeFLTransactionRepo();

      await tester.pumpWidget(
        _wrapWidget(
          const FLReceiveForm(initialContactId: 'c1'),
          overrides: [
            flContactRepositoryProvider.overrideWithValue(contactRepo),
            flTransactionRepositoryProvider.overrideWithValue(txnRepo),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Receive Fund'), findsOneWidget);
      expect(find.text('Record Received Fund'), findsOneWidget);

      final submitBtn = find.text('Record Received Fund');
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Please enter amount'), findsOneWidget);
    });

    testWidgets('6. FLUtilizeForm modal renders fields and validates purpose', (tester) async {
      final contactRepo = _FakeFLContactRepo();
      final txnRepo = _FakeFLTransactionRepo();

      await tester.pumpWidget(
        _wrapWidget(
          const FLUtilizeForm(initialContactId: 'c1'),
          overrides: [
            flContactRepositoryProvider.overrideWithValue(contactRepo),
            flTransactionRepositoryProvider.overrideWithValue(txnRepo),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Utilize Fund'), findsOneWidget);
      expect(find.text('Record Fund Utilization'), findsOneWidget);

      final submitBtn = find.text('Record Fund Utilization');
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Please enter purpose/title'), findsOneWidget);
    });

    testWidgets('7. FLReturnForm modal renders fields and validates amount', (tester) async {
      final contactRepo = _FakeFLContactRepo();
      final txnRepo = _FakeFLTransactionRepo();

      await tester.pumpWidget(
        _wrapWidget(
          const FLReturnForm(initialContactId: 'c1'),
          overrides: [
            flContactRepositoryProvider.overrideWithValue(contactRepo),
            flTransactionRepositoryProvider.overrideWithValue(txnRepo),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Return Fund'), findsOneWidget);
      expect(find.text('Record Returned Fund'), findsOneWidget);

      final submitBtn = find.text('Record Returned Fund');
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Please enter amount'), findsOneWidget);
    });
  });
}
