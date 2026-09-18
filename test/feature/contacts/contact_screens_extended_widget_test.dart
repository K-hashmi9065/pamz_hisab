import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pamz_khata/feature/contacts/domain/entities/contact.dart';
import 'package:pamz_khata/feature/contacts/presentation/providers/contact_providers.dart';
import 'package:pamz_khata/feature/contacts/presentation/screens/contact_detail_screen.dart';
import 'package:pamz_khata/feature/contacts/presentation/screens/contact_list_screen.dart';
import 'package:pamz_khata/feature/direct_udhar/data/services/direct_udhar_share_service.dart';
import 'package:pamz_khata/feature/direct_udhar/domain/entities/direct_udhar_loan.dart';
import 'package:pamz_khata/feature/direct_udhar/presentation/providers/direct_udhar_providers.dart';

import 'package:pamz_khata/feature/contacts/domain/entities/contact_ledger_statement.dart';

import '../../test_helpers/mocks.dart';
import '../../test_helpers/pump_app.dart';

class MockDirectUdharShareService extends Mock implements DirectUdharShareService {}
class FakeContactLedgerStatement extends Fake implements ContactLedgerStatement {}

void main() {
  setUpAll(() {
    registerFallbacks();
    registerFallbackValue(FakeContactLedgerStatement());
  });

  final testBuyer1 = Contact(
    id: 'buyer-001',
    type: ContactType.buyer,
    name: 'Aarav Sharma',
    mobileNumber: '9876500001',
    creditLimit: 25000.0,
    address: 'Shop 12, Main Bazaar',
    villageTola: 'North Ward',
    dueDateAlertEnabled: true,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  final testBuyer2 = Contact(
    id: 'buyer-002',
    type: ContactType.buyer,
    name: 'Bhavna Patel',
    mobileNumber: '9876500002',
    creditLimit: 40000.0,
    address: 'Plot 45, Sector 9',
    createdAt: DateTime(2026, 1, 2),
    updatedAt: DateTime(2026, 1, 2),
  );

  final testSupplier1 = Contact(
    id: 'supp-001',
    type: ContactType.supplier,
    name: 'Chetan Wholesalers',
    mobileNumber: '9876500003',
    shopLocation: 'GIDC Market Block B',
    dueDateAlertEnabled: true,
    createdAt: DateTime(2026, 1, 3),
    updatedAt: DateTime(2026, 1, 3),
  );

  final testLoan1 = DirectUdharLoan(
    id: 'loan-001',
    contactId: 'buyer-001',
    direction: LoanDirection.lent,
    principalAmount: 15000.0,
    interestType: InterestType.simple,
    interestRatePercent: 1.5,
    status: LoanStatus.open,
    outstandingBalance: 15000.0,
    createdAt: DateTime(2026, 2, 1),
    updatedAt: DateTime(2026, 2, 1),
  );

  final testLoan2 = DirectUdharLoan(
    id: 'loan-002',
    contactId: 'buyer-001',
    direction: LoanDirection.borrowed,
    principalAmount: 5000.0,
    interestType: InterestType.interestFree,
    status: LoanStatus.partiallyPaid,
    outstandingBalance: 2000.0,
    memo: '[Opening Balance] Initial ledger migration',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  group('ContactScreens Extended Widget Tests', () {
    late MockContactRepository mockContactRepo;
    late MockDirectUdharRepository mockUdharRepo;
    late MockDirectUdharShareService mockShareService;

    setUp(() {
      mockContactRepo = MockContactRepository();
      mockUdharRepo = MockDirectUdharRepository();
      mockShareService = MockDirectUdharShareService();

      when(() => mockContactRepo.delete(any())).thenAnswer((_) async => const Right(null));
      when(() => mockContactRepo.getTotalBalance('buyer-001')).thenAnswer((_) async => const Right(13000.0));
      when(() => mockContactRepo.getTotalBalance('buyer-002')).thenAnswer((_) async => const Right(0.0));
      when(() => mockContactRepo.getTotalBalance('supp-001')).thenAnswer((_) async => const Right(-25000.0));
      when(() => mockUdharRepo.getByContact('buyer-001')).thenAnswer((_) async => Right([testLoan1, testLoan2]));
      when(() => mockUdharRepo.getByContact('buyer-002')).thenAnswer((_) async => const Right([]));
      when(() => mockUdharRepo.getByContact('supp-001')).thenAnswer((_) async => const Right([]));
      when(() => mockUdharRepo.getRepayments(any())).thenAnswer((_) async => const Right([]));
      when(() => mockShareService.shareStatementPdfWithSummary(statement: any(named: 'statement')))
          .thenAnswer((_) async => true);
    });

    List<Override> buildOverrides({
      List<Contact>? buyers,
      List<Contact>? suppliers,
      Contact? selectedContact,
    }) {
      final buyerList = buyers ?? [testBuyer1, testBuyer2];
      final supplierList = suppliers ?? [testSupplier1];
      final allList = [...buyerList, ...supplierList];

      return [
        contactRepositoryProvider.overrideWithValue(mockContactRepo),
        directUdharRepositoryProvider.overrideWithValue(mockUdharRepo),
        directUdharShareServiceProvider.overrideWithValue(mockShareService),
        buyerListProvider.overrideWith((ref) async => buyerList),
        supplierListProvider.overrideWith((ref) async => supplierList),
        allContactListProvider.overrideWith((ref) async => allList),
        contactByIdProvider.overrideWith((ref, id) async {
          if (id == 'buyer-001') return testBuyer1;
          if (id == 'buyer-002') return testBuyer2;
          if (id == 'supp-001') return testSupplier1;
          return null;
        }),
      ];
    }

    testWidgets('1. ContactList: search filtering by name and mobile number with clear button', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await pumpApp(
        tester,
        const ContactListScreen(),
        overrides: buildOverrides(),
      );
      await tester.pumpAndSettle();

      expect(find.text('Aarav Sharma'), findsOneWidget);
      expect(find.text('Bhavna Patel'), findsOneWidget);

      // Search by name 'Aarav'
      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'aarav');
      await tester.pumpAndSettle();

      expect(find.text('Aarav Sharma'), findsOneWidget);
      expect(find.text('Bhavna Patel'), findsNothing);

      // Search by mobile '0002'
      await tester.enterText(searchField, '0002');
      await tester.pumpAndSettle();

      expect(find.text('Aarav Sharma'), findsNothing);
      expect(find.text('Bhavna Patel'), findsOneWidget);

      // Tap clear button
      final clearIcon = find.byIcon(Icons.clear_rounded);
      await tester.tap(clearIcon);
      await tester.pumpAndSettle();

      expect(find.text('Aarav Sharma'), findsOneWidget);
      expect(find.text('Bhavna Patel'), findsOneWidget);

      // Non-matching search displays empty state
      await tester.enterText(searchField, 'NonExistentPerson');
      await tester.pumpAndSettle();

      expect(find.text('No buyers yet'), findsOneWidget);
    });

    testWidgets('2. ContactList: tab switching between Buyers, Suppliers, and Direct Cash placeholder', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await pumpApp(
        tester,
        const ContactListScreen(),
        overrides: buildOverrides(),
      );
      await tester.pumpAndSettle();

      // Switch to Suppliers tab
      await tester.tap(find.text('Suppliers'));
      await tester.pumpAndSettle();

      expect(find.text('Chetan Wholesalers'), findsOneWidget);
      expect(find.text('Aarav Sharma'), findsNothing);

      // Switch to Direct Cash tab
      await tester.tap(find.text('Direct Cash'));
      await tester.pumpAndSettle();

      expect(find.text('Direct Cash & Opening Balances'), findsOneWidget);
      expect(find.text('Record prior balances or new direct loans with simple interest'), findsOneWidget);
    });

    testWidgets('3. Master-Detail layout on tablet: selecting contact displays detail pane', (tester) async {
      tester.view.physicalSize = const Size(1800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await pumpApp(
        tester,
        const ContactListScreen(),
        overrides: buildOverrides(),
      );
      await tester.pumpAndSettle();

      // Before selection, detail pane shows Select a Contact empty state
      expect(find.text('Select a Contact'), findsOneWidget);

      // Tap Aarav Sharma
      await tester.tap(find.text('Aarav Sharma'));
      await tester.pumpAndSettle();

      // Right pane now displays Aarav Sharma's details and active loans
      expect(find.text('North Ward'), findsOneWidget);
      expect(find.text('Shop 12, Main Bazaar'), findsOneWidget);
      expect(find.text('Udhar Given'), findsOneWidget);
      expect(find.text('Opening Balance'), findsOneWidget);
      expect(find.text('OPEN'), findsOneWidget);
      expect(find.text('PARTIALLY PAID'), findsOneWidget);
    });

    testWidgets('4. ContactDetail: Supplier profile rendering and negative balance payable display', (tester) async {
      tester.view.physicalSize = const Size(1300, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await pumpApp(
        tester,
        const ContactDetailScreen(contactId: 'supp-001'),
        overrides: buildOverrides(),
      );
      await tester.pumpAndSettle();

      expect(find.text('Chetan Wholesalers'), findsWidgets);
      expect(find.text('GIDC Market Block B'), findsOneWidget);
      expect(find.text('Net Balance (Payable)'), findsOneWidget);
      expect(find.text('No loan or opening balance records found.'), findsOneWidget);
    });

    testWidgets('5. ContactDetail: Share statement button triggers PDF share service', (tester) async {
      tester.view.physicalSize = const Size(1194, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await pumpApp(
        tester,
        const ContactDetailScreen(contactId: 'buyer-001'),
        overrides: buildOverrides(),
      );
      await tester.pumpAndSettle();

      final shareBtn = find.byKey(const Key('shareStatementFullButton'));
      await tester.tap(shareBtn);
      await tester.pumpAndSettle();

      verify(() => mockShareService.shareStatementPdfWithSummary(statement: any(named: 'statement'))).called(1);
    });

    testWidgets('6. ContactDetail: Delete confirmation dialog cancellation and confirmation', (tester) async {
      tester.view.physicalSize = const Size(1194, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      var onDeletedCalled = false;

      await pumpApp(
        tester,
        ContactDetailScreen(
          contactId: 'buyer-001',
          isMasterDetail: true,
          onDeleted: () => onDeletedCalled = true,
        ),
        overrides: buildOverrides(),
      );
      await tester.pumpAndSettle();

      // Tap Delete icon button in app bar
      final deleteBtn = find.byKey(const Key('deleteContactButton'));
      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();

      expect(find.text('Delete Contact'), findsOneWidget);
      expect(find.text('Are you sure you want to delete Aarav Sharma? Previous financial records will be preserved in audit logs.'), findsOneWidget);

      // Cancel dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Delete Contact'), findsNothing);
      expect(onDeletedCalled, isFalse);

      // Open dialog again and confirm delete
      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();

      final confirmDeleteBtn = find.byKey(const Key('confirmDeleteButton'));
      await tester.tap(confirmDeleteBtn);
      await tester.pumpAndSettle();

      verify(() => mockContactRepo.delete('buyer-001')).called(1);
      expect(onDeletedCalled, isTrue);
    });

    testWidgets('7. ContactDetail: non-existent contact renders Contact Not Found empty state', (tester) async {
      tester.view.physicalSize = const Size(1194, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await pumpApp(
        tester,
        const ContactDetailScreen(contactId: 'invalid-contact-id', isMasterDetail: true),
        overrides: buildOverrides(),
      );
      await tester.pumpAndSettle();

      expect(find.text('Contact Not Found'), findsOneWidget);
      expect(find.text('This contact may have been deleted.'), findsOneWidget);
    });
  });
}
