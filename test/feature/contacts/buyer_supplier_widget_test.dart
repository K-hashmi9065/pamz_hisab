import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pamz_khata/feature/contacts/domain/entities/contact.dart';
import 'package:pamz_khata/feature/contacts/presentation/providers/contact_providers.dart';
import 'package:pamz_khata/feature/contacts/presentation/screens/contact_detail_screen.dart';
import 'package:pamz_khata/feature/contacts/presentation/screens/contact_form_screen.dart';
import 'package:pamz_khata/feature/contacts/presentation/screens/contact_list_screen.dart';
import 'package:pamz_khata/feature/direct_udhar/presentation/providers/direct_udhar_providers.dart';

import '../../test_helpers/fixtures.dart';
import '../../test_helpers/mocks.dart';
import '../../test_helpers/pump_app.dart';

void main() {
  setUpAll(registerFallbacks);

  group('Buyer & Supplier Contact Widget Tests', () {
    late MockContactRepository mockContactRepo;
    late MockDirectUdharRepository mockUdharRepo;

    setUp(() {
      mockContactRepo = MockContactRepository();
      mockUdharRepo = MockDirectUdharRepository();

      when(() => mockContactRepo.existsByMobile(any(), excludeId: any(named: 'excludeId')))
          .thenAnswer((_) async => false);
      when(() => mockContactRepo.create(any()))
          .thenAnswer((inv) async => right(inv.positionalArguments.first as Contact));
      when(() => mockContactRepo.update(any()))
          .thenAnswer((inv) async => right(inv.positionalArguments.first as Contact));
      when(() => mockContactRepo.delete(any()))
          .thenAnswer((_) async => right(null));
      when(() => mockContactRepo.getTotalBalance(any()))
          .thenAnswer((_) async => right(5000.0));
      when(() => mockUdharRepo.getByContact(any()))
          .thenAnswer((_) async => right([]));
    });

    List<Override> buildOverrides({List<Contact>? buyers, List<Contact>? suppliers}) {
      return [
        contactRepositoryProvider.overrideWithValue(mockContactRepo),
        directUdharRepositoryProvider.overrideWithValue(mockUdharRepo),
        buyerListProvider.overrideWith((ref) async => buyers ?? [buyerFixture]),
        supplierListProvider.overrideWith((ref) async => suppliers ?? [supplierFixture]),
        allContactListProvider.overrideWith((ref) async => [...(buyers ?? [buyerFixture]), ...(suppliers ?? [supplierFixture])]),
        contactByIdProvider.overrideWith((ref, id) async => id == buyerFixture.id ? buyerFixture : supplierFixture),
      ];
    }

    // 1. Buyer form renders correctly with Buyer-specific fields
    testWidgets('1. Buyer form renders correctly with Address, Village/Tola, Credit Limit', (tester) async {
      await pumpApp(
        tester,
        const ContactFormScreen(type: ContactType.buyer),
        overrides: buildOverrides(),
      );
      await tester.pumpAndSettle();

      expect(find.text('New Contact'), findsOneWidget);
      expect(find.text('Buyer'), findsOneWidget);
      expect(find.text('Supplier'), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('nameField')), matching: find.byType(TextFormField)), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('mobileField')), matching: find.byType(TextFormField)), findsOneWidget);
      expect(find.text('Address (optional)'), findsOneWidget);
      expect(find.text('Village / Tola (optional)'), findsOneWidget);
      expect(find.text('Credit Limit (optional)'), findsOneWidget);
      // Supplier fields should NOT be shown
      expect(find.text('Shop Location (optional)'), findsNothing);
      expect(find.byKey(const Key('dueDateAlertSwitch')), findsNothing);
    });

    // 2. Supplier form renders correctly with Supplier-specific fields
    testWidgets('2. Supplier form renders correctly with Shop Location and Due Date Alerts', (tester) async {
      await pumpApp(
        tester,
        const ContactFormScreen(type: ContactType.supplier),
        overrides: buildOverrides(),
      );
      await tester.pumpAndSettle();

      expect(find.text('Shop Location (optional)'), findsOneWidget);
      expect(find.byKey(const Key('dueDateAlertSwitch')), findsOneWidget);
      // Buyer fields should NOT be shown
      expect(find.text('Village / Tola (optional)'), findsNothing);
      expect(find.text('Credit Limit (optional)'), findsNothing);
    });

    // 3. Required-field and Mobile validation
    testWidgets('3. Required name and 10-digit Indian mobile validation', (tester) async {
      await pumpApp(
        tester,
        const ContactFormScreen(type: ContactType.buyer),
        overrides: buildOverrides(),
      );
      await tester.pumpAndSettle();

      final nameField = find.descendant(of: find.byKey(const Key('nameField')), matching: find.byType(TextFormField));
      final mobileField = find.descendant(of: find.byKey(const Key('mobileField')), matching: find.byType(TextFormField));

      // Submit empty form
      await tester.tap(find.byKey(const Key('saveContactButton')));
      await tester.pumpAndSettle();

      expect(find.text('Name is required'), findsOneWidget);
      expect(find.text('Mobile number is required'), findsOneWidget);

      // Enter invalid mobile
      await tester.enterText(nameField, 'Test Buyer');
      await tester.enterText(mobileField, '12345');
      await tester.tap(find.byKey(const Key('saveContactButton')));
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid 10-digit Indian mobile number starting with 6-9'), findsOneWidget);
    });

    // 4. Duplicate mobile error presentation in UI
    testWidgets('4. Duplicate mobile error is presented gracefully on save', (tester) async {
      when(() => mockContactRepo.existsByMobile('9876543210', excludeId: any(named: 'excludeId')))
          .thenAnswer((_) async => true);

      await pumpApp(
        tester,
        const ContactFormScreen(type: ContactType.buyer),
        overrides: buildOverrides(),
      );
      await tester.pumpAndSettle();

      final nameField = find.descendant(of: find.byKey(const Key('nameField')), matching: find.byType(TextFormField));
      final mobileField = find.descendant(of: find.byKey(const Key('mobileField')), matching: find.byType(TextFormField));

      await tester.enterText(nameField, 'Ramesh');
      await tester.enterText(mobileField, '9876543210');
      await tester.tap(find.byKey(const Key('saveContactButton')));
      await tester.pumpAndSettle();

      expect(find.text('This mobile number is already registered. Please use a different number.'), findsOneWidget);
    });

    // 5. Edit existing contact
    testWidgets('5. Edit existing contact pre-populates fields and submits update', (tester) async {
      await pumpApp(
        tester,
        ContactFormScreen(existingContact: buyerFixture),
        overrides: buildOverrides(),
      );
      await tester.pumpAndSettle();

      expect(find.text('Edit Contact'), findsOneWidget);
      expect(find.text('Ramesh Kumar'), findsOneWidget);
      expect(find.text('9876543210'), findsOneWidget);
      expect(find.text('Update Contact'), findsOneWidget);

      // Edit name
      final nameField = find.descendant(of: find.byKey(const Key('nameField')), matching: find.byType(TextFormField));
      await tester.enterText(nameField, 'Ramesh Kumar Updated');
      await tester.tap(find.byKey(const Key('saveContactButton')));
      await tester.pumpAndSettle();

      verify(() => mockContactRepo.update(any())).called(1);
    });

    // 6. Contact List rendering with balance and tabs
    testWidgets('6. Contact list screen renders Buyers and Suppliers with balance badges', (tester) async {
      await pumpApp(
        tester,
        const ContactListScreen(),
        overrides: buildOverrides(),
      );
      await tester.pumpAndSettle();

      expect(find.text('Udhar Khata'), findsOneWidget);
      expect(find.text('Buyers'), findsOneWidget);
      expect(find.text('Suppliers'), findsOneWidget);
      expect(find.text('Direct Cash'), findsOneWidget);
      expect(find.text('Ramesh Kumar'), findsOneWidget);
    });

    // 7. Contact Details Screen & Delete Confirmation
    testWidgets('7. Contact details screen renders profile info and delete confirmation dialog', (tester) async {
      await pumpAppWithRouter(
        tester,
        ContactDetailScreen(contactId: buyerFixture.id),
        overrides: buildOverrides(),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ramesh Kumar'), findsNWidgets(2));
      expect(find.text('BUYER'), findsOneWidget);
      expect(find.text('Give / Take Udhar'), findsOneWidget);
      expect(find.text('Opening Bal'), findsOneWidget);
      expect(find.byKey(const Key('editContactButton')), findsOneWidget);
      expect(find.byKey(const Key('deleteContactButton')), findsOneWidget);

      // Tap Delete
      await tester.tap(find.byKey(const Key('deleteContactButton')));
      await tester.pumpAndSettle();

      expect(find.text('Delete Contact'), findsOneWidget);
      expect(find.text('Are you sure you want to delete Ramesh Kumar? Previous financial records will be preserved in audit logs.'), findsOneWidget);

      // Confirm Delete
      await tester.tap(find.byKey(const Key('confirmDeleteButton')));
      await tester.pumpAndSettle();

      verify(() => mockContactRepo.delete(buyerFixture.id)).called(1);
    });
  });
}
