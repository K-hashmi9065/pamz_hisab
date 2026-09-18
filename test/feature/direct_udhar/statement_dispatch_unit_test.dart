import 'package:flutter_test/flutter_test.dart';
import 'package:pamz_khata/feature/contacts/domain/entities/contact.dart';
import 'package:pamz_khata/feature/contacts/domain/services/contact_statement_builder.dart';
import 'package:pamz_khata/feature/direct_udhar/data/services/direct_udhar_pdf_service.dart';
import 'package:pamz_khata/feature/direct_udhar/data/services/direct_udhar_share_service.dart';
import 'package:pamz_khata/feature/direct_udhar/domain/entities/direct_udhar_loan.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testContact = Contact(
    id: 'c-101',
    type: ContactType.buyer,
    name: 'Mohammad Tariq',
    mobileNumber: '9876543210',
    address: 'Line Bazar, Kishanganj',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  group('ContactStatementBuilder Unit Tests (FR-NT-001)', () {
    test('Builds empty statement when contact has no loans', () {
      final statement = ContactStatementBuilder.build(
        contact: testContact,
        loans: [],
        asOfDate: DateTime(2026, 3, 15),
      );

      expect(statement.contact.id, 'c-101');
      expect(statement.items.isEmpty, isTrue);
      expect(statement.totalDebit, 0.0);
      expect(statement.totalCredit, 0.0);
      expect(statement.netOutstandingBalance, 0.0);
      expect(statement.isReceivable, isTrue);
    });

    test('Calculates chronological running balance with loans and repayments', () {
      final loan1 = DirectUdharLoan(
        id: 'l-1',
        contactId: testContact.id,
        direction: LoanDirection.lent,
        principalAmount: 10000,
        interestType: InterestType.interestFree,
        status: LoanStatus.open,
        outstandingBalance: 6000,
        createdAt: DateTime(2026, 1, 10),
        updatedAt: DateTime(2026, 1, 10),
      );

      final rep1 = Repayment(
        id: 'r-1',
        sourceType: RepaymentSourceType.directUdhar,
        sourceId: 'l-1',
        amount: 4000,
        paidAt: DateTime(2026, 1, 25),
        paymentMode: 'upi',
        memo: 'GPay transfer',
        createdAt: DateTime(2026, 1, 25),
      );

      final loan2 = DirectUdharLoan(
        id: 'l-2',
        contactId: testContact.id,
        direction: LoanDirection.lent,
        principalAmount: 5000,
        interestType: InterestType.interestFree,
        status: LoanStatus.open,
        outstandingBalance: 5000,
        createdAt: DateTime(2026, 2, 5),
        updatedAt: DateTime(2026, 2, 5),
      );

      final statement = ContactStatementBuilder.build(
        contact: testContact,
        loans: [loan1, loan2],
        loanRepayments: {
          'l-1': [rep1],
        },
        asOfDate: DateTime(2026, 3, 1),
      );

      expect(statement.items.length, 3);

      // Event 1: Loan 1 (+10,000 debit) -> Running Balance = 10,000
      expect(statement.items[0].debit, 10000);
      expect(statement.items[0].credit, 0);
      expect(statement.items[0].runningBalance, 10000);

      // Event 2: Repayment 1 (+4,000 credit) -> Running Balance = 6,000
      expect(statement.items[1].debit, 0);
      expect(statement.items[1].credit, 4000);
      expect(statement.items[1].runningBalance, 6000);

      // Event 3: Loan 2 (+5,000 debit) -> Running Balance = 11,000
      expect(statement.items[2].debit, 5000);
      expect(statement.items[2].credit, 0);
      expect(statement.items[2].runningBalance, 11000);

      // Totals
      expect(statement.totalDebit, 15000);
      expect(statement.totalCredit, 4000);
      expect(statement.netOutstandingBalance, 11000);
      expect(statement.isReceivable, isTrue);
    });

    test('Handles borrowed loans and payable balances', () {
      final borrowedLoan = DirectUdharLoan(
        id: 'l-borrow',
        contactId: testContact.id,
        direction: LoanDirection.borrowed,
        principalAmount: 8000,
        interestType: InterestType.interestFree,
        status: LoanStatus.open,
        outstandingBalance: 8000,
        createdAt: DateTime(2026, 2, 1),
        updatedAt: DateTime(2026, 2, 1),
      );

      final statement = ContactStatementBuilder.build(
        contact: testContact,
        loans: [borrowedLoan],
      );

      expect(statement.items.length, 1);
      expect(statement.items[0].debit, 0);
      expect(statement.items[0].credit, 8000);
      expect(statement.items[0].runningBalance, -8000);
      expect(statement.netOutstandingBalance, -8000);
      expect(statement.isReceivable, isFalse);
    });

    test('Lent vs Borrowed repayments produce Repayment Received and Repayment Paid descriptions', () {
      final lentLoan = DirectUdharLoan(
        id: 'l-lent-word',
        contactId: testContact.id,
        direction: LoanDirection.lent,
        principalAmount: 6000,
        interestType: InterestType.interestFree,
        status: LoanStatus.open,
        outstandingBalance: 3000,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      final lentRep = Repayment(
        id: 'r-lent',
        sourceType: RepaymentSourceType.directUdhar,
        sourceId: 'l-lent-word',
        amount: 3000,
        paidAt: DateTime(2026, 1, 15),
        paymentMode: 'cash',
        createdAt: DateTime(2026, 1, 15),
      );

      final borrowedLoan = DirectUdharLoan(
        id: 'l-borrow-word',
        contactId: testContact.id,
        direction: LoanDirection.borrowed,
        principalAmount: 4000,
        interestType: InterestType.interestFree,
        status: LoanStatus.open,
        outstandingBalance: 2000,
        createdAt: DateTime(2026, 2, 1),
        updatedAt: DateTime(2026, 2, 1),
      );
      final borrowRep = Repayment(
        id: 'r-borrow',
        sourceType: RepaymentSourceType.directUdhar,
        sourceId: 'l-borrow-word',
        amount: 2000,
        paidAt: DateTime(2026, 2, 20),
        paymentMode: 'upi',
        createdAt: DateTime(2026, 2, 20),
      );

      final statement = ContactStatementBuilder.build(
        contact: testContact,
        loans: [lentLoan, borrowedLoan],
        loanRepayments: {
          'l-lent-word': [lentRep],
          'l-borrow-word': [borrowRep],
        },
      );

      expect(statement.items.length, 4);

      // Event 1: Lent Loan -> Debit 6000, Credit 0
      expect(statement.items[0].description, contains('Direct Udhar (Lent)'));
      expect(statement.items[0].debit, 6000.0);
      expect(statement.items[0].credit, 0.0);

      // Event 2: Lent Repayment -> "Repayment Received", Debit 0, Credit 3000
      expect(statement.items[1].description, contains('Repayment Received'));
      expect(statement.items[1].debit, 0.0);
      expect(statement.items[1].credit, 3000.0);

      // Event 3: Borrowed Loan -> Debit 0, Credit 4000
      expect(statement.items[2].description, contains('Direct Udhar (Borrowed)'));
      expect(statement.items[2].debit, 0.0);
      expect(statement.items[2].credit, 4000.0);

      // Event 4: Borrowed Repayment -> "Repayment Paid", Debit 2000, Credit 0
      expect(statement.items[3].description, contains('Repayment Paid'));
      expect(statement.items[3].debit, 2000.0);
      expect(statement.items[3].credit, 0.0);
    });
  });

  group('DirectUdharPdfService Statement Generation (FR-NT-001)', () {
    const pdfService = DirectUdharPdfService();

    test('Generates non-empty itemized statement PDF bytes', () async {
      final loan = DirectUdharLoan(
        id: 'l-pdf',
        contactId: testContact.id,
        direction: LoanDirection.lent,
        principalAmount: 12000,
        interestType: InterestType.simple,
        interestRatePercent: 2.0,
        status: LoanStatus.open,
        outstandingBalance: 12000,
        createdAt: DateTime(2026, 1, 15),
        updatedAt: DateTime(2026, 1, 15),
      );

      final statement = ContactStatementBuilder.build(
        contact: testContact,
        loans: [loan],
      );

      final bytes = await pdfService.generateStatementPdf(statement: statement);
      expect(bytes, isNotNull);
      expect(bytes.isNotEmpty, isTrue);
    });

    test('Generates statement PDF for empty ledger safely without crash', () async {
      final emptyStatement = ContactStatementBuilder.build(
        contact: testContact,
        loans: [],
      );

      final bytes = await pdfService.generateStatementPdf(statement: emptyStatement);
      expect(bytes, isNotNull);
      expect(bytes.isNotEmpty, isTrue);
    });
  });

  group('DirectUdharShareService Statement Text Templates (FR-NT-001)', () {
    const shareService = DirectUdharShareService();

    test('Builds multi-lingual statement summaries correctly', () {
      final loan = DirectUdharLoan(
        id: 'l-msg',
        contactId: testContact.id,
        direction: LoanDirection.lent,
        principalAmount: 20000,
        interestType: InterestType.interestFree,
        status: LoanStatus.open,
        outstandingBalance: 20000,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      final statement = ContactStatementBuilder.build(
        contact: testContact,
        loans: [loan],
        asOfDate: DateTime(2026, 3, 1),
      );

      // English
      final en = shareService.buildStatementMessageText(
        statement: statement,
        language: ShareLanguage.english,
      );
      expect(en.contains('Party Ledger Statement'), isTrue);
      expect(en.contains('Mohammad Tariq'), isTrue);
      expect(en.contains('20,000.00'), isTrue);
      expect(en.contains('Receivable'), isTrue);

      // Hindi
      final hi = shareService.buildStatementMessageText(
        statement: statement,
        language: ShareLanguage.hindi,
      );
      expect(hi.contains('खाता विवरण'), isTrue);
      expect(hi.contains('Mohammad Tariq'), isTrue);
      expect(hi.contains('लेना बाकी'), isTrue);

      // Hinglish
      final hinglish = shareService.buildStatementMessageText(
        statement: statement,
        language: ShareLanguage.hinglish,
      );
      expect(hinglish.contains('Khata Statement'), isTrue);
      expect(hinglish.contains('Lena baaki'), isTrue);
    });
  });
}
