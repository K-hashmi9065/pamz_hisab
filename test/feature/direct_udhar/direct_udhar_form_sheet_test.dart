import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pamz_khata/feature/contacts/domain/entities/contact.dart';
import 'package:pamz_khata/feature/contacts/presentation/providers/contact_providers.dart';
import 'package:pamz_khata/feature/direct_udhar/domain/entities/direct_udhar_loan.dart';
import 'package:pamz_khata/feature/direct_udhar/presentation/providers/direct_udhar_providers.dart';
import 'package:pamz_khata/feature/direct_udhar/presentation/widgets/direct_udhar_form_sheet.dart';
import 'package:pamz_khata/shared/widgets/app_button.dart';

import '../../test_helpers/fixtures.dart';
import '../../test_helpers/mocks.dart';
import '../../test_helpers/pump_app.dart';

void main() {
  setUpAll(registerFallbacks);

  group('DirectUdharFormSheet Widget Tests', () {
    late MockDirectUdharRepository mockUdharRepo;
    late MockContactRepository mockContactRepo;

    final testContacts = [buyerFixture, supplierFixture];

    setUp(() {
      mockUdharRepo = MockDirectUdharRepository();
      mockContactRepo = MockContactRepository();

      when(() => mockUdharRepo.create(any()))
          .thenAnswer((inv) async => right(inv.positionalArguments.first as DirectUdharLoan));
      when(() => mockContactRepo.getAll())
          .thenAnswer((_) async => right(testContacts));
    });

    List<Override> buildOverrides({List<Contact>? contacts}) {
      return [
        directUdharRepositoryProvider.overrideWithValue(mockUdharRepo),
        contactRepositoryProvider.overrideWithValue(mockContactRepo),
        allContactListProvider.overrideWith((ref) async => contacts ?? testContacts),
      ];
    }

    testWidgets('1. Renders DirectUdharFormSheet with Lent mode default', (tester) async {
      tester.view.physicalSize = const Size(1194, 834);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await pumpApp(
        tester,
        const DirectUdharFormSheet(),
        overrides: buildOverrides(),
      );
      await tester.pumpAndSettle();

      expect(find.text('New Udhar Given (Lent)'), findsOneWidget);
      expect(find.text('Given (Lent)'), findsOneWidget);
      expect(find.text('Taken (Borrowed)'), findsOneWidget);
      expect(find.text('Select Contact'), findsOneWidget);
      expect(find.text('Interest Free'), findsOneWidget);
      expect(find.text('Simple Interest'), findsOneWidget);
      expect(find.text('Record Udhar'), findsOneWidget);
    });

    testWidgets('2. Toggle direction updates title and submission mode', (tester) async {
      tester.view.physicalSize = const Size(1194, 834);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await pumpApp(
        tester,
        const DirectUdharFormSheet(initialDirection: LoanDirection.borrowed),
        overrides: buildOverrides(),
      );
      await tester.pumpAndSettle();

      expect(find.text('New Udhar Taken (Borrowed)'), findsOneWidget);

      // Toggle back to lent
      await tester.tap(find.text('Given (Lent)'));
      await tester.pumpAndSettle();

      expect(find.text('New Udhar Given (Lent)'), findsOneWidget);
    });

    testWidgets('3. Empty contact list shows info message and add contact button', (tester) async {
      tester.view.physicalSize = const Size(1194, 834);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await pumpApp(
        tester,
        const DirectUdharFormSheet(),
        overrides: buildOverrides(contacts: []),
      );
      await tester.pumpAndSettle();

      expect(find.text('No contacts found. Please add a contact first.'), findsOneWidget);
      expect(find.text('+ Add Contact'), findsOneWidget);
    });

    testWidgets('4. Simple Interest toggle displays monthly interest rate field and validates', (tester) async {
      tester.view.physicalSize = const Size(1194, 834);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await pumpApp(
        tester,
        const DirectUdharFormSheet(),
        overrides: buildOverrides(),
      );
      await tester.pumpAndSettle();

      // Tap Simple Interest
      await tester.tap(find.text('Simple Interest'));
      await tester.pumpAndSettle();

      expect(find.text('Monthly Interest Rate (% per month)'), findsOneWidget);

      // Enter amount
      final amountField = find.byType(TextFormField).first;
      await tester.enterText(amountField, '5000');
      await tester.pumpAndSettle();

      // Submit without entering interest rate
      final submitBtn = find.widgetWithText(AppButton, 'Record Udhar');
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Enter monthly interest rate'), findsOneWidget);
    });

    testWidgets('5. Amount validation rejects empty and zero/negative amount', (tester) async {
      tester.view.physicalSize = const Size(1194, 834);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await pumpApp(
        tester,
        const DirectUdharFormSheet(),
        overrides: buildOverrides(),
      );
      await tester.pumpAndSettle();

      // Submit empty
      final submitBtn = find.widgetWithText(AppButton, 'Record Udhar');
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Please enter amount'), findsOneWidget);

      // Enter zero
      final amountField = find.byType(TextFormField).first;
      await tester.enterText(amountField, '0');
      await tester.pumpAndSettle();

      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid amount greater than 0'), findsOneWidget);
    });

    testWidgets('6. Successful Lent Udhar submission invokes create with correct entity', (tester) async {
      tester.view.physicalSize = const Size(1194, 834);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await pumpApp(
        tester,
        DirectUdharFormSheet(targetContactId: buyerFixture.id),
        overrides: buildOverrides(),
      );
      await tester.pumpAndSettle();

      // Enter amount
      final amountField = find.byType(TextFormField).first;
      await tester.enterText(amountField, '7500');
      await tester.pumpAndSettle();

      // Enter memo
      final memoField = find.byType(TextFormField).last;
      await tester.enterText(memoField, 'Fertilizer supplies');
      await tester.pumpAndSettle();

      // Submit
      final submitBtn = find.widgetWithText(AppButton, 'Record Udhar');
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      verify(() => mockUdharRepo.create(any(
            that: isA<DirectUdharLoan>()
                .having((l) => l.principalAmount, 'principal', 7500.0)
                .having((l) => l.direction, 'direction', LoanDirection.lent)
                .having((l) => l.interestType, 'interestType', InterestType.interestFree),
          ))).called(1);
    });

    testWidgets('7. Successful Borrowed Simple-Interest submission invokes create', (tester) async {
      tester.view.physicalSize = const Size(1194, 834);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await pumpApp(
        tester,
        DirectUdharFormSheet(
          targetContactId: supplierFixture.id,
          initialDirection: LoanDirection.borrowed,
        ),
        overrides: buildOverrides(),
      );
      await tester.pumpAndSettle();

      // Select Simple Interest
      await tester.tap(find.text('Simple Interest'));
      await tester.pumpAndSettle();

      // Amount
      final amountField = find.byType(TextFormField).at(0);
      await tester.enterText(amountField, '12000');

      // Interest Rate
      final interestField = find.byType(TextFormField).at(1);
      await tester.enterText(interestField, '2.5');
      await tester.pumpAndSettle();

      // Submit
      final submitBtn = find.widgetWithText(AppButton, 'Record Udhar');
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      verify(() => mockUdharRepo.create(any(
            that: isA<DirectUdharLoan>()
                .having((l) => l.principalAmount, 'principal', 12000.0)
                .having((l) => l.direction, 'direction', LoanDirection.borrowed)
                .having((l) => l.interestType, 'interestType', InterestType.simple)
                .having((l) => l.interestRatePercent, 'rate', 2.5),
          ))).called(1);
    });
  });
}
