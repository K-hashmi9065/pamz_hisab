import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pamz_khata/feature/contacts/domain/entities/contact.dart';
import 'package:pamz_khata/feature/contacts/presentation/providers/contact_providers.dart';
import 'package:pamz_khata/feature/contacts/presentation/screens/contact_detail_screen.dart';
import 'package:pamz_khata/feature/direct_udhar/domain/entities/direct_udhar_loan.dart';
import 'package:pamz_khata/feature/direct_udhar/presentation/providers/direct_udhar_providers.dart';

import '../../test_helpers/mocks.dart';
import '../../test_helpers/pump_app.dart';

void main() {
  setUpAll(registerFallbacks);

  final testContact = Contact(
    id: 'contact-st-1',
    type: ContactType.buyer,
    name: 'Anil Kumar',
    mobileNumber: '9876543210',
    address: 'Hospital Road, Kishanganj',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  final testLoan = DirectUdharLoan(
    id: 'loan-st-1',
    contactId: testContact.id,
    direction: LoanDirection.lent,
    principalAmount: 15000,
    interestType: InterestType.interestFree,
    status: LoanStatus.open,
    outstandingBalance: 15000,
    createdAt: DateTime(2026, 1, 10),
    updatedAt: DateTime(2026, 1, 10),
  );

  group('ContactDetailScreen Statement Dispatch Widget Tests (FR-NT-001)', () {
    late MockContactRepository mockContactRepo;
    late MockDirectUdharRepository mockDirectUdharRepo;

    setUp(() {
      mockContactRepo = MockContactRepository();
      mockDirectUdharRepo = MockDirectUdharRepository();

      when(() => mockContactRepo.findById(testContact.id))
          .thenAnswer((_) async => right(testContact));
      when(() => mockContactRepo.getTotalBalance(testContact.id))
          .thenAnswer((_) async => right(15000.0));
      when(() => mockDirectUdharRepo.getByContact(testContact.id))
          .thenAnswer((_) async => right([testLoan]));
      when(() => mockDirectUdharRepo.getRepayments(testLoan.id))
          .thenAnswer((_) async => right([]));
    });

    List<Override> buildOverrides() {
      return [
        contactRepositoryProvider.overrideWithValue(mockContactRepo),
        directUdharRepositoryProvider.overrideWithValue(mockDirectUdharRepo),
        contactByIdProvider(testContact.id).overrideWith((ref) async => testContact),
        contactTotalBalanceProvider(testContact.id).overrideWith((ref) async => 15000.0),
        loansByContactProvider(testContact.id).overrideWith((ref) async => [testLoan]),
      ];
    }

    testWidgets('Renders Share Statement buttons in AppBar and action card', (tester) async {
      await pumpApp(
        tester,
        ContactDetailScreen(contactId: testContact.id),
        overrides: buildOverrides(),
      );
      await tester.pumpAndSettle();

      // Verify contact name & profile
      expect(find.text('Anil Kumar'), findsWidgets);
      expect(find.text('9876543210'), findsOneWidget);

      // Verify AppBar Share button
      expect(find.byKey(const Key('shareStatementButton')), findsOneWidget);

      // Verify Full Action Button
      expect(find.byKey(const Key('shareStatementFullButton')), findsOneWidget);
      expect(find.text('Share Ledger Statement (WhatsApp / PDF)'), findsOneWidget);
    });

    testWidgets('Tapping Share Statement in AppBar triggers ledger retrieval', (tester) async {
      await pumpApp(
        tester,
        ContactDetailScreen(contactId: testContact.id),
        overrides: buildOverrides(),
      );
      await tester.pumpAndSettle();

      // Tap AppBar Share button
      await tester.tap(find.byKey(const Key('shareStatementButton')));
      await tester.pumpAndSettle();

      // Verify repository was queried for loans and repayments
      verify(() => mockDirectUdharRepo.getByContact(testContact.id)).called(1);
      verify(() => mockDirectUdharRepo.getRepayments(testLoan.id)).called(1);
    });

    testWidgets('Tapping Full Share Statement button triggers ledger retrieval', (tester) async {
      await pumpApp(
        tester,
        ContactDetailScreen(contactId: testContact.id),
        overrides: buildOverrides(),
      );
      await tester.pumpAndSettle();

      // Tap Action Button
      await tester.tap(find.byKey(const Key('shareStatementFullButton')));
      await tester.pumpAndSettle();

      verify(() => mockDirectUdharRepo.getByContact(testContact.id)).called(1);
      verify(() => mockDirectUdharRepo.getRepayments(testLoan.id)).called(1);
    });
  });
}
