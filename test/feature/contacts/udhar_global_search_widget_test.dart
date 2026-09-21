import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pamz_khata/feature/contacts/domain/entities/contact.dart';
import 'package:pamz_khata/feature/contacts/presentation/providers/contact_providers.dart';
import 'package:pamz_khata/feature/contacts/presentation/screens/contact_list_screen.dart';
import 'package:pamz_khata/feature/direct_udhar/presentation/providers/direct_udhar_providers.dart';
import 'package:pamz_khata/shared/widgets/app_states.dart';

import '../../test_helpers/mocks.dart';
import '../../test_helpers/pump_app.dart';

void main() {
  setUpAll(registerFallbacks);

  final testBuyer = Contact(
    id: 'buyer-101',
    type: ContactType.buyer,
    name: 'Kamran Akmal',
    mobileNumber: '9876543210',
    address: 'Shop 12, Main Market',
    creditLimit: 50000,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  final testSupplier = Contact(
    id: 'supp-202',
    type: ContactType.supplier,
    name: 'Suresh Wholesalers',
    mobileNumber: '9123456780',
    shopLocation: 'Block B, Market',
    createdAt: DateTime(2026, 1, 2),
    updatedAt: DateTime(2026, 1, 2),
  );

  group('Udhar Global Search Widget Tests', () {
    late MockContactRepository mockContactRepo;
    late MockDirectUdharRepository mockUdharRepo;

    setUp(() {
      mockContactRepo = MockContactRepository();
      mockUdharRepo = MockDirectUdharRepository();

      when(() => mockContactRepo.getTotalBalance(any()))
          .thenAnswer((_) async => right(12500.0));
      when(() => mockUdharRepo.getByContact(any()))
          .thenAnswer((_) async => right([]));
    });

    List<Override> buildOverrides({
      List<Contact>? buyers,
      List<Contact>? suppliers,
      List<Contact>? allContacts,
    }) {
      final bList = buyers ?? [testBuyer];
      final sList = suppliers ?? [testSupplier];
      final aList = allContacts ?? [testBuyer, testSupplier];

      return [
        contactRepositoryProvider.overrideWithValue(mockContactRepo),
        directUdharRepositoryProvider.overrideWithValue(mockUdharRepo),
        buyerListProvider.overrideWith((ref) async => bList),
        supplierListProvider.overrideWith((ref) async => sList),
        allContactListProvider.overrideWith((ref) async => aList),
        contactByIdProvider.overrideWith((ref, id) async => id == testBuyer.id ? testBuyer : testSupplier),
      ];
    }

    testWidgets('1. Global Search bar renders on top of tabs and Opening Balance in AppBar actions', (tester) async {
      await pumpApp(
        tester,
        const ContactListScreen(),
        overrides: buildOverrides(),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('udharSearchBar')), findsOneWidget);
      expect(find.byKey(const Key('openingBalanceButton')), findsOneWidget);
      expect(find.byKey(const Key('newContactButton')), findsOneWidget);
    });

    testWidgets('2. Search bar and Opening Balance action remain accessible together', (tester) async {
      await pumpApp(
        tester,
        const ContactListScreen(),
        overrides: buildOverrides(),
      );
      await tester.pumpAndSettle();

      final searchBar = find.byKey(const Key('udharSearchBar'));
      final openingBalanceBtn = find.byKey(const Key('openingBalanceButton'));

      expect(searchBar, findsOneWidget);
      expect(openingBalanceBtn, findsOneWidget);

      // Tap opening balance action to verify it remains fully accessible
      await tester.tap(openingBalanceBtn);
      await tester.pumpAndSettle();

      expect(find.text('Set Opening Balance'), findsWidgets);
    });

    testWidgets('3. Typing partial query ("kam") reactively filters and renders matching Buyer', (tester) async {
      await pumpApp(
        tester,
        const ContactListScreen(),
        overrides: buildOverrides(),
      );
      await tester.pumpAndSettle();

      final searchField = find.byKey(const Key('udharSearchBar'));
      expect(searchField, findsOneWidget);

      await tester.enterText(searchField, 'kam');
      await tester.pumpAndSettle();

      expect(find.text('Kamran Akmal'), findsOneWidget);
      expect(find.text('Suresh Wholesalers'), findsNothing);
      expect(find.textContaining('Buyer'), findsOneWidget);
    });

    testWidgets('4. Searching mobile number ("9123") finds expected Supplier in unified results', (tester) async {
      await pumpApp(
        tester,
        const ContactListScreen(),
        overrides: buildOverrides(),
      );
      await tester.pumpAndSettle();

      final searchField = find.byKey(const Key('udharSearchBar'));
      await tester.enterText(searchField, '9123');
      await tester.pumpAndSettle();

      expect(find.text('Suresh Wholesalers'), findsOneWidget);
      expect(find.text('Kamran Akmal'), findsNothing);
      expect(find.textContaining('Supplier'), findsOneWidget);
    });

    testWidgets('5. Generic search ("market") returns both Buyer and Supplier unified results', (tester) async {
      await pumpApp(
        tester,
        const ContactListScreen(),
        overrides: buildOverrides(),
      );
      await tester.pumpAndSettle();

      final searchField = find.byKey(const Key('udharSearchBar'));
      await tester.enterText(searchField, 'market');
      await tester.pumpAndSettle();

      expect(find.text('Kamran Akmal'), findsOneWidget);
      expect(find.text('Suresh Wholesalers'), findsOneWidget);
      expect(find.textContaining('Buyer'), findsOneWidget);
      expect(find.textContaining('Supplier'), findsOneWidget);
    });

    testWidgets('6. Non-matching query renders empty state', (tester) async {
      await pumpApp(
        tester,
        const ContactListScreen(),
        overrides: buildOverrides(),
      );
      await tester.pumpAndSettle();

      final searchField = find.byKey(const Key('udharSearchBar'));
      await tester.enterText(searchField, 'UnknownPerson123');
      await tester.pumpAndSettle();

      expect(find.text('No matching records'), findsOneWidget);
      expect(find.byType(AppEmptyState), findsOneWidget);
    });

    testWidgets('7. Clearing search query restores normal segmented tabs and content', (tester) async {
      await pumpApp(
        tester,
        const ContactListScreen(),
        overrides: buildOverrides(),
      );
      await tester.pumpAndSettle();

      final searchField = find.byKey(const Key('udharSearchBar'));
      await tester.enterText(searchField, 'kam');
      await tester.pumpAndSettle();

      expect(find.text('Suresh Wholesalers'), findsNothing);

      // Tap clear icon
      final clearBtn = find.byIcon(Icons.clear_rounded);
      await tester.tap(clearBtn);
      await tester.pumpAndSettle();

      expect(find.text('Buyers'), findsOneWidget);
      expect(find.text('Suppliers'), findsOneWidget);
      expect(find.text('Kamran Akmal'), findsOneWidget);
    });

    testWidgets('8. Responsive layout on wide/tablet (1194x834) renders without overflow', (tester) async {
      tester.view.physicalSize = const Size(1194, 834);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await pumpApp(
        tester,
        const ContactListScreen(),
        overrides: buildOverrides(),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('udharSearchBar')), findsOneWidget);
      expect(find.byKey(const Key('openingBalanceButton')), findsOneWidget);
      expect(find.text('Aarav Sharma'), findsWidgets);

      // Type search in wide search bar
      await tester.enterText(find.byKey(const Key('udharSearchBar')), 'kam');
      await tester.pumpAndSettle();

      expect(find.text('Kamran Akmal'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('9. Responsive layout on narrow/mobile (375x667) renders without overflow', (tester) async {
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await pumpApp(
        tester,
        const ContactListScreen(),
        overrides: buildOverrides(),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('udharSearchBar')), findsOneWidget);
      expect(find.byKey(const Key('openingBalanceButton')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('udharSearchBar')), 'suresh');
      await tester.pumpAndSettle();

      expect(find.text('Suresh Wholesalers'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
