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
import 'package:pamz_khata/feature/fund_ledger/presentation/screens/fl_user_guide_screen.dart';

class MockScreensContactRepo implements FLContactRepository {
  final List<FLContact> contacts = [
    FLContact(
      id: 'c1',
      name: 'Salman Farsi',
      mobileNumber: '9988776655',
      aadhaarNumber: '112233445566',
      project: 'Relief 2026',
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

class MockScreensTxnRepo implements FLTransactionRepository {
  final List<FLTransaction> txns = [
    FLTransaction(
      id: 't1',
      contactId: 'c1',
      type: FLTransactionType.received,
      amount: 20000,
      txnDate: '2026-09-15',
      paymentMode: 'UPI',
      paymentReference: 'UPI/999888',
      createdAt: DateTime(2026, 9, 21),
      updatedAt: DateTime(2026, 9, 21),
    ),
    FLTransaction(
      id: 't2',
      contactId: 'c1',
      type: FLTransactionType.utilized,
      amount: 8000,
      txnDate: '2026-09-18',
      title: 'Aid packages',
      createdAt: DateTime(2026, 9, 21),
      updatedAt: DateTime(2026, 9, 21),
    ),
  ];

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

Widget buildScreen(Widget child, {List<Override> overrides = const []}) {
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
  group('Fund Ledger Screens UI Tests', () {
    late MockScreensContactRepo contactRepo;
    late MockScreensTxnRepo txnRepo;

    setUp(() {
      contactRepo = MockScreensContactRepo();
      txnRepo = MockScreensTxnRepo();
    });

    testWidgets('FLContactsScreen renders search field, contact list, and Add button', (tester) async {
      await tester.pumpWidget(
        buildScreen(
          const FLContactsScreen(),
          overrides: [
            flContactRepositoryProvider.overrideWithValue(contactRepo),
            flTransactionRepositoryProvider.overrideWithValue(txnRepo),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Contacts'), findsOneWidget);
      expect(find.text('Salman Farsi'), findsOneWidget);
      expect(find.text('Add Contact'), findsOneWidget);

      // Search filtering
      await tester.enterText(find.byType(TextField), 'NonExistent');
      await tester.pumpAndSettle();
      expect(find.text('No matching contacts found'), findsOneWidget);
    });

    testWidgets('FLContactDetailScreen renders contact header and action buttons', (tester) async {
      await tester.pumpWidget(
        buildScreen(
          const FLContactDetailScreen(contactId: 'c1'),
          overrides: [
            flContactRepositoryProvider.overrideWithValue(contactRepo),
            flTransactionRepositoryProvider.overrideWithValue(txnRepo),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Salman Farsi'), findsWidgets);
      expect(find.text('Receive'), findsWidgets);
      expect(find.text('Utilize'), findsWidgets);
      expect(find.text('Return'), findsWidgets);
    });

    testWidgets('FLReportsScreen renders filter chips and metrics', (tester) async {
      await tester.pumpWidget(
        buildScreen(
          const FLReportsScreen(),
          overrides: [
            flContactRepositoryProvider.overrideWithValue(contactRepo),
            flTransactionRepositoryProvider.overrideWithValue(txnRepo),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Reports & Analytics'), findsOneWidget);
      expect(find.text('All Types'), findsOneWidget);
      expect(find.text('Received'), findsOneWidget);
      expect(find.text('Utilized'), findsOneWidget);
      expect(find.text('Returned'), findsOneWidget);
    });

    testWidgets('FLUserGuideScreen renders instructions and guides', (tester) async {
      await tester.pumpWidget(
        buildScreen(
          const FLUserGuideScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('User Guide'), findsOneWidget);
      expect(find.textContaining('Fund Responsibility Ledger'), findsWidgets);
    });
  });
}
