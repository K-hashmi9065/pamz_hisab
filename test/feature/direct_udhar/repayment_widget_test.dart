import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pamz_khata/feature/contacts/domain/entities/contact.dart';
import 'package:pamz_khata/feature/contacts/presentation/providers/contact_providers.dart';
import 'package:pamz_khata/feature/direct_udhar/domain/entities/direct_udhar_loan.dart';
import 'package:pamz_khata/feature/direct_udhar/presentation/providers/direct_udhar_providers.dart';
import 'package:pamz_khata/feature/direct_udhar/presentation/widgets/repayment_form_sheet.dart';

import '../../test_helpers/mocks.dart';
import '../../test_helpers/pump_app.dart';

void main() {
  setUpAll(registerFallbacks);

  final testContact = Contact(
    id: 'contact-rep-1',
    type: ContactType.buyer,
    name: 'Mohammad Tariq',
    mobileNumber: '9876543210',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  final testLoan = DirectUdharLoan(
    id: 'loan-rep-1',
    contactId: testContact.id,
    direction: LoanDirection.lent,
    principalAmount: 10000.0,
    interestType: InterestType.interestFree,
    status: LoanStatus.open,
    outstandingBalance: 7500.0,
    createdAt: DateTime(2026, 2, 1),
    updatedAt: DateTime(2026, 2, 1),
  );

  group('Repayment (Jama) FormSheet Widget Tests (FR-DU-003)', () {
    late MockDirectUdharRepository mockUdharRepo;
    late MockContactRepository mockContactRepo;

    setUp(() {
      mockUdharRepo = MockDirectUdharRepository();
      mockContactRepo = MockContactRepository();

      when(() => mockUdharRepo.getByContact(testContact.id))
          .thenAnswer((_) async => right([testLoan]));
      when(() => mockUdharRepo.findById(testLoan.id))
          .thenAnswer((_) async => right(testLoan));
      when(() => mockUdharRepo.recordRepayment(any(), any()))
          .thenAnswer((_) async => right(null));
      when(() => mockUdharRepo.getRepayments(testLoan.id))
          .thenAnswer((_) async => right([]));
      when(() => mockContactRepo.getTotalBalance(any()))
          .thenAnswer((_) async => right(7500.0));
      when(() => mockContactRepo.getAll())
          .thenAnswer((_) async => right([testContact]));
    });

    List<Override> buildOverrides({List<DirectUdharLoan>? loans}) {
      return [
        contactRepositoryProvider.overrideWithValue(mockContactRepo),
        directUdharRepositoryProvider.overrideWithValue(mockUdharRepo),
        allContactListProvider.overrideWith((ref) async => [testContact]),
        buyerListProvider.overrideWith((ref) async => [testContact]),
        supplierListProvider.overrideWith((ref) async => []),
        contactTotalBalanceProvider.overrideWith((ref, id) async => 7500.0),
        loansByContactProvider.overrideWith((ref, id) async => loans ?? [testLoan]),
      ];
    }

    Future<void> scrollToAndTap(WidgetTester tester, Finder finder) async {
      await tester.scrollUntilVisible(finder, 100.0, scrollable: find.byType(Scrollable).first);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -150));
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    testWidgets('1. Renders correctly with contact name, loan summary, amount, and controls', (tester) async {
      await pumpApp(
        tester,
        RepaymentFormSheet(contact: testContact, initialLoan: testLoan),
        overrides: buildOverrides(),
      );
      await tester.pumpAndSettle();

      expect(find.text('Record Repayment (Jama)'), findsNWidgets(2));
      expect(find.textContaining('Mohammad Tariq'), findsOneWidget);
      expect(find.text('LENT UDHAR (RECEIVABLE)'), findsOneWidget);
      expect(find.textContaining('7,500'), findsWidgets); // outstanding balance
      expect(find.text('Repayment Amount *'), findsOneWidget);
      expect(find.text('Payment Mode'), findsOneWidget);
      expect(find.text('Cash'), findsOneWidget);
      expect(find.text('Bank Transfer'), findsOneWidget);
      expect(find.text('UPI / Online'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Record Repayment (Jama)'), findsOneWidget);
    });

    testWidgets('2. Validates empty amount on submit', (tester) async {
      await pumpApp(
        tester,
        RepaymentFormSheet(contact: testContact, initialLoan: testLoan),
        overrides: buildOverrides(),
      );
      await tester.pumpAndSettle();

      final submitBtn = find.widgetWithText(ElevatedButton, 'Record Repayment (Jama)');
      await scrollToAndTap(tester, submitBtn);

      expect(find.text('Please enter repayment amount'), findsOneWidget);
      verifyNever(() => mockUdharRepo.recordRepayment(any(), any()));
    });

    testWidgets('3. Validates zero or negative amount', (tester) async {
      await pumpApp(
        tester,
        RepaymentFormSheet(contact: testContact, initialLoan: testLoan),
        overrides: buildOverrides(),
      );
      await tester.pumpAndSettle();

      final amountField = find.byType(TextFormField).at(0);
      await tester.enterText(amountField, '0');
      await tester.pumpAndSettle();

      final submitBtn = find.widgetWithText(ElevatedButton, 'Record Repayment (Jama)');
      await scrollToAndTap(tester, submitBtn);

      expect(find.text('Enter a valid amount greater than 0'), findsOneWidget);
      verifyNever(() => mockUdharRepo.recordRepayment(any(), any()));
    });

    testWidgets('4. Validates and rejects overpayment exceeding current outstanding balance', (tester) async {
      await pumpApp(
        tester,
        RepaymentFormSheet(contact: testContact, initialLoan: testLoan),
        overrides: buildOverrides(),
      );
      await tester.pumpAndSettle();

      final amountField = find.byType(TextFormField).at(0);
      await tester.enterText(amountField, '9000'); // loan outstanding is 7500
      await tester.pumpAndSettle();

      final submitBtn = find.widgetWithText(ElevatedButton, 'Record Repayment (Jama)');
      await scrollToAndTap(tester, submitBtn);

      expect(find.textContaining('Amount cannot exceed current balance'), findsOneWidget);
      verifyNever(() => mockUdharRepo.recordRepayment(any(), any()));
    });

    testWidgets('5. Full Balance chip pre-fills exact outstanding balance', (tester) async {
      await pumpApp(
        tester,
        RepaymentFormSheet(contact: testContact, initialLoan: testLoan),
        overrides: buildOverrides(),
      );
      await tester.pumpAndSettle();

      final chip = find.textContaining('Full Balance');
      expect(chip, findsOneWidget);
      await tester.tap(chip);
      await tester.pumpAndSettle();

      expect(find.text('7500'), findsOneWidget);
      expect(find.text('Loan will be FULLY SETTLED'), findsOneWidget);
    });

    testWidgets('6. Live remaining balance updates when amount is typed', (tester) async {
      await pumpApp(
        tester,
        RepaymentFormSheet(contact: testContact, initialLoan: testLoan),
        overrides: buildOverrides(),
      );
      await tester.pumpAndSettle();

      final amountField = find.byType(TextFormField).at(0);
      await tester.enterText(amountField, '2500');
      await tester.pumpAndSettle();

      expect(find.text('Remaining Balance after payment:'), findsOneWidget);
      expect(find.text('₹5,000'), findsOneWidget);
    });

    testWidgets('7. Valid submission calls recordRepayment and closes sheet', (tester) async {
      await pumpApp(
        tester,
        RepaymentFormSheet(contact: testContact, initialLoan: testLoan),
        overrides: buildOverrides(),
      );
      await tester.pumpAndSettle();

      final amountField = find.byType(TextFormField).at(0);
      await tester.enterText(amountField, '3000');
      await tester.pumpAndSettle();

      // Select UPI mode
      await tester.tap(find.text('UPI / Online'));
      await tester.pumpAndSettle();

      final submitBtn = find.widgetWithText(ElevatedButton, 'Record Repayment (Jama)');
      await scrollToAndTap(tester, submitBtn);

      verify(() => mockUdharRepo.recordRepayment(
            testLoan.id,
            any(that: isA<Repayment>().having((r) => r.amount, 'amount', 3000.0)),
          )).called(1);
    });

    testWidgets('8. Displays empty state if contact has no open loans', (tester) async {
      final closedLoan = testLoan.copyWith(
        status: LoanStatus.closed,
        outstandingBalance: 0.0,
      );

      await pumpApp(
        tester,
        RepaymentFormSheet(contact: testContact),
        overrides: buildOverrides(loans: [closedLoan]),
      );
      await tester.pumpAndSettle();

      expect(find.text('No Outstanding Balance'), findsOneWidget);
      expect(find.textContaining('has no open Udhar balance'), findsOneWidget);
    });
  });
}
