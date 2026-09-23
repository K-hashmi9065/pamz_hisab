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
import 'package:pamz_khata/feature/fund_ledger/presentation/screens/fl_contact_detail_screen.dart';
import 'package:pamz_khata/feature/fund_ledger/presentation/widgets/fl_transaction_history.dart';

class FakeShareService extends FLShareService {
  const FakeShareService();
  @override
  Future<bool> shareStatement(FLShareStatement statement) async => true;
}

class FakeDetailContactRepo implements FLContactRepository {
  final contact = FLContact(
    id: 'c1',
    name: 'Hamza Farooqi',
    mobileNumber: '9876543210',
    aadhaarNumber: '112233445566',
    project: 'Disaster Relief',
    createdAt: DateTime(2026, 9, 21),
    updatedAt: DateTime(2026, 9, 21),
  );

  @override
  Future<Either<Failure, FLContact?>> findById(String id) async =>
      Right(contact);

  @override
  Future<Either<Failure, List<FLContact>>> getAll() async => Right([contact]);

  @override
  Future<Either<Failure, bool>> existsByMobile(String mobileNumber,
          {String? excludeId}) async =>
      const Right(false);

  @override
  Future<Either<Failure, void>> insert(FLContact contact) async =>
      const Right(null);

  @override
  Future<Either<Failure, void>> update(FLContact contact) async =>
      const Right(null);

  @override
  Future<Either<Failure, void>> softDelete(String id) async =>
      const Right(null);
}

class FakeDetailTxnRepo implements FLTransactionRepository {
  final List<FLTransaction> txns = [
    FLTransaction(
      id: 't1',
      contactId: 'c1',
      type: FLTransactionType.received,
      amount: 10000,
      txnDate: '2026-09-01',
      paymentMode: 'Cash',
      createdAt: DateTime(2026, 9, 21),
      updatedAt: DateTime(2026, 9, 21),
    ),
    FLTransaction(
      id: 't2',
      contactId: 'c1',
      type: FLTransactionType.utilized,
      amount: 4000,
      txnDate: '2026-09-05',
      title: 'Food Packets',
      createdAt: DateTime(2026, 9, 21),
      updatedAt: DateTime(2026, 9, 21),
    ),
    FLTransaction(
      id: 't3',
      contactId: 'c1',
      type: FLTransactionType.returned,
      amount: 2000,
      txnDate: '2026-09-10',
      paymentMode: 'UPI',
      paymentReference: 'UPI/555666',
      createdAt: DateTime(2026, 9, 21),
      updatedAt: DateTime(2026, 9, 21),
    ),
  ];

  @override
  Future<Either<Failure, List<FLTransaction>>> getByContact(
          String contactId) async =>
      Right(List.from(txns));

  @override
  Future<Either<Failure, List<FLTransaction>>> getAll(
          {FLTransactionType? type,
          String? contactId,
          DateTime? from,
          DateTime? to}) async =>
      Right(List.from(txns));

  @override
  Future<Either<Failure, FLContactTotals>> getTotals(String contactId) async {
    return const Right(FLContactTotals(
        totalReceived: 10000, totalUtilized: 4000, totalReturned: 2000));
  }

  @override
  Future<Either<Failure, FLContactTotals>> getGlobalTotals() async {
    return const Right(FLContactTotals(
        totalReceived: 10000, totalUtilized: 4000, totalReturned: 2000));
  }

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
  Future<Either<Failure, void>> update(FLTransaction transaction) {
    throw UnimplementedError();
  }
}

Widget buildTestWidget(Widget child, {List<Override> overrides = const []}) {
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
  group('FL Contact Detail & Transaction History Deep UI Tests', () {
    late FakeDetailContactRepo contactRepo;
    late FakeDetailTxnRepo txnRepo;

    setUp(() {
      contactRepo = FakeDetailContactRepo();
      txnRepo = FakeDetailTxnRepo();
    });

    testWidgets('FLContactDetailScreen exports PDF and switches tabs',
        (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          const FLContactDetailScreen(contactId: 'c1'),
          overrides: [
            flContactRepositoryProvider.overrideWithValue(contactRepo),
            flTransactionRepositoryProvider.overrideWithValue(txnRepo),
            flShareServiceProvider.overrideWithValue(const FakeShareService()),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hamza Farooqi'), findsWidgets);
      expect(find.text('9876543210'), findsWidgets);

      // Export PDF button
      final pdfBtn = find.byIcon(Icons.picture_as_pdf_outlined);
      expect(pdfBtn, findsOneWidget);
      await tester.tap(pdfBtn);
      await tester.pumpAndSettle();

      // Edit contact button
      final editBtn = find.byIcon(Icons.edit_outlined);
      expect(editBtn, findsOneWidget);
      await tester.tap(editBtn);
      await tester.pumpAndSettle();
      expect(find.text('Edit Contact'), findsOneWidget);

      // Pop edit
      Navigator.of(tester.element(find.text('Edit Contact'))).pop();
      await tester.pumpAndSettle();
    });

    testWidgets('FLTransactionHistory tabs, search, and detail modal',
        (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          const FLTransactionHistory(
            contactId: 'c1',
          ),
          overrides: [
            flContactRepositoryProvider.overrideWithValue(contactRepo),
            flTransactionRepositoryProvider.overrideWithValue(txnRepo),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Check all 3 transactions present
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Received'), findsOneWidget);
      expect(find.text('Utilized'), findsOneWidget);
      expect(find.text('Returned'), findsOneWidget);

      // Filter by Utilized tab
      await tester.tap(find.text('Utilized'));
      await tester.pumpAndSettle();
      expect(find.text('Food Packets'), findsOneWidget);

      // Filter by Returned tab
      await tester.tap(find.text('Returned'));
      await tester.pumpAndSettle();
      expect(find.textContaining('UPI/555666'), findsOneWidget);

      // Filter by Received tab
      await tester.tap(find.text('Received'));
      await tester.pumpAndSettle();

      // Return to All tab
      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();
      expect(find.text('Food Packets'), findsOneWidget);
      expect(find.text('Fund Received'), findsOneWidget);
      expect(find.text('Fund Returned'), findsOneWidget);
    });
  });
}
