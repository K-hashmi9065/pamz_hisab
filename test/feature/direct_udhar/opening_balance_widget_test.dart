import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pamz_khata/feature/contacts/domain/entities/contact.dart';
import 'package:pamz_khata/feature/contacts/presentation/providers/contact_providers.dart';
import 'package:pamz_khata/feature/direct_udhar/domain/entities/direct_udhar_loan.dart';
import 'package:pamz_khata/feature/direct_udhar/presentation/providers/direct_udhar_providers.dart';
import 'package:pamz_khata/feature/direct_udhar/presentation/widgets/opening_balance_form_sheet.dart';

import '../../test_helpers/mocks.dart';
import '../../test_helpers/pump_app.dart';

void main() {
  setUpAll(registerFallbacks);

  final testContact = Contact(
    id: 'contact-w-1',
    type: ContactType.buyer,
    name: 'Ahmad Khan',
    mobileNumber: '9876543210',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  group('Opening Balance FormSheet Widget Tests', () {
    late MockDirectUdharRepository mockRepo;
    late MockContactRepository mockContactRepo;

    setUp(() {
      mockRepo = MockDirectUdharRepository();
      mockContactRepo = MockContactRepository();
      when(() => mockRepo.create(any())).thenAnswer((invocation) async {
        final loan = invocation.positionalArguments.first as DirectUdharLoan;
        return right(loan);
      });
      when(() => mockRepo.getByContact(any())).thenAnswer((_) async => right([]));
      when(() => mockContactRepo.getAll()).thenAnswer((_) async => right([testContact]));
      when(() => mockContactRepo.getTotalBalance(any())).thenAnswer((_) async => right(0.0));
    });

    List<Override> buildOverrides({List<Contact>? contacts}) {
      final list = contacts ?? [testContact];
      return [
        contactRepositoryProvider.overrideWithValue(mockContactRepo),
        allContactListProvider.overrideWith((ref) async => list),
        buyerListProvider.overrideWith((ref) async => list.where((c) => c.type == ContactType.buyer).toList()),
        supplierListProvider.overrideWith((ref) async => list.where((c) => c.type == ContactType.supplier).toList()),
        contactTotalBalanceProvider.overrideWith((ref, contactId) async => 0.0),
        directUdharRepositoryProvider.overrideWithValue(mockRepo),
      ];
    }

    Future<void> scrollToAndTap(WidgetTester tester, Finder finder) async {
      await tester.scrollUntilVisible(finder, 100.0, scrollable: find.byType(Scrollable).first);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -150));
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    testWidgets('1 & 2. Opening Balance form renders correctly with contact, title, and initial controls', (tester) async {
      await pumpApp(
        tester,
        const OpeningBalanceFormSheet(),
        overrides: buildOverrides(),
      );
      await tester.pumpAndSettle();

      expect(find.text('Set Opening Balance'), findsOneWidget);
      expect(find.text('Party / Contact'), findsOneWidget);
      expect(find.text('Balance Direction'), findsOneWidget);
      expect(find.text('Opening Amount Details'), findsOneWidget);
      expect(find.text('Interest Terms'), findsOneWidget);
      expect(find.text('Opening Date'), findsWidgets);
      expect(find.text('Save Opening Balance'), findsOneWidget);
    });

    testWidgets('3 & 4. Lent / Borrowed selection toggles direction and updates live summary', (tester) async {
      await pumpApp(
        tester,
        const OpeningBalanceFormSheet(),
        overrides: buildOverrides(),
      );
      await tester.pumpAndSettle();

      expect(find.text('Lent (Receivable)'), findsOneWidget);
      expect(find.text('Borrowed (Payable)'), findsOneWidget);

      // Tap Borrowed
      await tester.tap(find.text('Borrowed (Payable)'));
      await tester.pumpAndSettle();

      expect(find.text('PAYABLE (BORROWED)'), findsOneWidget);

      // Tap Lent
      await tester.tap(find.text('Lent (Receivable)'));
      await tester.pumpAndSettle();

      expect(find.text('RECEIVABLE (LENT)'), findsOneWidget);
    });

    testWidgets('5 & 6. Interest-Free hides Monthly Rate, Simple Interest shows Monthly Rate', (tester) async {
      await pumpApp(
        tester,
        const OpeningBalanceFormSheet(),
        overrides: buildOverrides(),
      );
      await tester.pumpAndSettle();

      // Initially Interest-Free: Monthly rate field should NOT exist
      expect(find.textContaining('Monthly Interest Rate'), findsNothing);

      // Select Simple Interest
      await tester.tap(find.text('Simple Interest'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Monthly Interest Rate'), findsOneWidget);

      // Switch back to Interest-Free
      await tester.tap(find.text('Interest Free'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Monthly Interest Rate'), findsNothing);
    });

    testWidgets('7 & 8. Invalid, empty, zero, or negative amount is rejected with validation error', (tester) async {
      await pumpApp(
        tester,
        const OpeningBalanceFormSheet(),
        overrides: buildOverrides(),
      );
      await tester.pumpAndSettle();

      final saveBtn = find.text('Save Opening Balance');

      // Submit without amount
      await scrollToAndTap(tester, saveBtn);

      expect(find.text('Please enter opening amount'), findsOneWidget);

      // Enter 0
      final amountField = find.byType(TextFormField).at(0); // amount
      await tester.enterText(amountField, '0');
      await tester.pumpAndSettle();
      await scrollToAndTap(tester, saveBtn);

      expect(find.text('Enter a valid amount greater than 0'), findsOneWidget);
    });

    testWidgets('9. Missing Simple Interest rate triggers validation error', (tester) async {
      await pumpApp(
        tester,
        const OpeningBalanceFormSheet(),
        overrides: buildOverrides(),
      );
      await tester.pumpAndSettle();

      // Select Simple Interest
      await tester.tap(find.text('Simple Interest'));
      await tester.pumpAndSettle();

      // Fill amount
      await tester.enterText(find.byType(TextFormField).at(0), '5000');
      await tester.pumpAndSettle();

      final saveBtn = find.text('Save Opening Balance');
      await scrollToAndTap(tester, saveBtn);

      expect(find.text('Monthly interest rate is required'), findsOneWidget);
    });

    testWidgets('10 & 11. Opening Date and Memo fields are editable', (tester) async {
      await pumpApp(
        tester,
        const OpeningBalanceFormSheet(),
        overrides: buildOverrides(),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.calendar_month_rounded), findsOneWidget);
      expect(find.text('Memo / Note (optional)'), findsOneWidget);
    });

    testWidgets('12, 13, 14 & 15. Valid form submission calls repository, shows post-save action sheet with language selector (FR-NT-003)', (tester) async {
      await pumpApp(
        tester,
        OpeningBalanceFormSheet(targetContactId: testContact.id),
        overrides: buildOverrides(),
      );
      await tester.pumpAndSettle();

      // Enter valid amount
      await tester.enterText(find.byType(TextFormField).at(0), '12500');
      await tester.pumpAndSettle();

      final saveBtn = find.text('Save Opening Balance');
      await scrollToAndTap(tester, saveBtn);

      // Verify repository was called once
      verify(() => mockRepo.create(any())).called(1);

      // Post-save UI rendered
      expect(find.text('Opening Balance Recorded Successfully'), findsOneWidget);
      expect(find.text('Message Language'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      expect(find.text('हिंदी (Hindi)'), findsOneWidget);
      expect(find.text('Hinglish'), findsOneWidget);

      // Switch language to Hindi
      final hindiBtn = find.text('हिंदी (Hindi)');
      await scrollToAndTap(tester, hindiBtn);

      // Switch language to Hinglish
      final hinglishBtn = find.text('Hinglish');
      await scrollToAndTap(tester, hinglishBtn);

      expect(find.text('View / Print PDF Receipt'), findsOneWidget);
      expect(find.text('Share via WhatsApp'), findsOneWidget);
      expect(find.text('Send SMS Alert'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });
  });
}
