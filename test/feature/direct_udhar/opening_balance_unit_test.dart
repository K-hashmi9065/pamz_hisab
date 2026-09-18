import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pamz_khata/core/db/hive/hive_registrar.dart';
import 'package:pamz_khata/core/db/sqlite/app_database.dart';
import 'package:pamz_khata/core/db/sqlite/database_helper.dart';
import 'package:pamz_khata/feature/contacts/data/datasources/contact_hive_datasource.dart';
import 'package:pamz_khata/feature/contacts/data/datasources/contact_sqlite_datasource.dart';
import 'package:pamz_khata/feature/contacts/data/repositories/contact_repository_impl.dart';
import 'package:pamz_khata/feature/contacts/domain/entities/contact.dart';
import 'package:pamz_khata/feature/direct_udhar/data/models/direct_udhar_models.dart';
import 'package:pamz_khata/feature/direct_udhar/data/repositories/direct_udhar_hive_repository_impl.dart';
import 'package:pamz_khata/feature/direct_udhar/data/services/direct_udhar_pdf_service.dart';
import 'package:pamz_khata/feature/direct_udhar/data/services/direct_udhar_share_service.dart';
import 'package:pamz_khata/feature/direct_udhar/domain/entities/direct_udhar_loan.dart';
import 'package:pamz_khata/feature/direct_udhar/domain/services/interest_calculator.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Opening Balance Financial & Unit Tests', () {
    late Directory tempDir;
    const hiveDataSource = ContactHiveDataSource();
    const contactRepo = ContactRepositoryImpl(hiveDataSource);
    const directUdharRepo = DirectUdharHiveRepositoryImpl();
    final contact = Contact(
      id: 'contact-ob-001',
      type: ContactType.buyer,
      name: 'Ramesh Shah',
      mobileNumber: '9876543210',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('ob_unit_test_');
      await HiveRegistrar.initialize(tempDir.path);
    });

    tearDown(() async {
      await Hive.close();
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    // 1. Interest-free opening lent balance
    test('1. Interest-free opening lent balance adds exact principal to contact balance', () async {
      final obLoan = DirectUdharLoan(
        id: 'ob-1',
        contactId: contact.id,
        direction: LoanDirection.lent,
        principalAmount: 15000,
        interestType: InterestType.interestFree,
        memo: '[Opening Balance] Carry forward',
        status: LoanStatus.open,
        outstandingBalance: 15000,
        createdAt: DateTime.now().subtract(const Duration(days: 90)),
        updatedAt: DateTime.now().subtract(const Duration(days: 90)),
      );

      final box = HiveRegistrar.directUdharBox;
      await box.put(obLoan.id, DirectUdharLoanModel.fromEntity(obLoan).toMap());

      final balRes = await contactRepo.getTotalBalance(contact.id);
      expect(balRes.isRight(), isTrue);
      expect(balRes.getOrElse((_) => 0), 15000.0);
    });

    // 2. Simple-interest opening lent balance
    test('2. Simple-interest opening lent balance calculates accrued interest from Opening Date', () async {
      final now = DateTime.now();
      // 10,000 at 2% per month for 30 days = 200 interest
      final obLoan = DirectUdharLoan(
        id: 'ob-2',
        contactId: contact.id,
        direction: LoanDirection.lent,
        principalAmount: 10000,
        interestType: InterestType.simple,
        interestRatePercent: 2.0,
        memo: '[Opening Balance]',
        status: LoanStatus.open,
        outstandingBalance: 10000,
        createdAt: now.subtract(const Duration(days: 30)),
        updatedAt: now.subtract(const Duration(days: 30)),
      );

      final box = HiveRegistrar.directUdharBox;
      await box.put(obLoan.id, DirectUdharLoanModel.fromEntity(obLoan).toMap());

      final balRes = await contactRepo.getTotalBalance(contact.id);
      expect(balRes.isRight(), isTrue);
      expect(balRes.getOrElse((_) => 0), 10200.0);
    });

    // 3. Opening borrowed balance
    test('3. Opening borrowed balance includes accrued interest and reduces contact balance', () async {
      final now = DateTime.now();
      // Borrowed 5,000 at 3% for 30 days = 150 interest -> -5,150 balance
      final obLoan = DirectUdharLoan(
        id: 'ob-3',
        contactId: contact.id,
        direction: LoanDirection.borrowed,
        principalAmount: 5000,
        interestType: InterestType.simple,
        interestRatePercent: 3.0,
        memo: '[Opening Balance]',
        status: LoanStatus.open,
        outstandingBalance: 5000,
        createdAt: now.subtract(const Duration(days: 30)),
        updatedAt: now.subtract(const Duration(days: 30)),
      );

      final box = HiveRegistrar.directUdharBox;
      await box.put(obLoan.id, DirectUdharLoanModel.fromEntity(obLoan).toMap());

      final balRes = await contactRepo.getTotalBalance(contact.id);
      expect(balRes.isRight(), isTrue);
      expect(balRes.getOrElse((_) => 0), -5150.0);
    });

    // 4. Opening balance + normal Direct Udhar aggregation
    test('4. Opening balance + normal Direct Udhar aggregation computes net balance correctly', () async {
      final now = DateTime.now();
      // OB Lent: 10,000 + 200 interest = 10,200
      final obLoan = DirectUdharLoan(
        id: 'ob-lent',
        contactId: contact.id,
        direction: LoanDirection.lent,
        principalAmount: 10000,
        interestType: InterestType.simple,
        interestRatePercent: 2.0,
        memo: '[Opening Balance]',
        status: LoanStatus.open,
        outstandingBalance: 10000,
        createdAt: now.subtract(const Duration(days: 30)),
        updatedAt: now.subtract(const Duration(days: 30)),
      );

      // Normal Loan Borrowed: 3,000 interest-free
      final normalLoan = DirectUdharLoan(
        id: 'normal-borrowed',
        contactId: contact.id,
        direction: LoanDirection.borrowed,
        principalAmount: 3000,
        interestType: InterestType.interestFree,
        status: LoanStatus.open,
        outstandingBalance: 3000,
        createdAt: now.subtract(const Duration(days: 5)),
        updatedAt: now.subtract(const Duration(days: 5)),
      );

      final box = HiveRegistrar.directUdharBox;
      await box.put(obLoan.id, DirectUdharLoanModel.fromEntity(obLoan).toMap());
      await box.put(normalLoan.id, DirectUdharLoanModel.fromEntity(normalLoan).toMap());

      // Net = 10,200 - 3,000 = 7,200
      final balRes = await contactRepo.getTotalBalance(contact.id);
      expect(balRes.isRight(), isTrue);
      expect(balRes.getOrElse((_) => 0), 7200.0);
    });

    // 5 & 6. Repayment against opening balance with interest-first allocation
    test('5 & 6. Repayment against opening balance allocates interest first then reduces principal', () async {
      final now = DateTime.now();
      final obLoan = DirectUdharLoan(
        id: 'ob-loan-repay',
        contactId: contact.id,
        direction: LoanDirection.lent,
        principalAmount: 10000,
        interestType: InterestType.simple,
        interestRatePercent: 2.0,
        memo: '[Opening Balance]',
        status: LoanStatus.open,
        outstandingBalance: 10000,
        createdAt: now.subtract(const Duration(days: 30)),
        updatedAt: now.subtract(const Duration(days: 30)),
      );

      await directUdharRepo.create(obLoan);

      // Repay 500 at day 30: 200 interest accrued (10,000 * 2% * 30/30) + 300 principal -> new outstanding principal = 9,700
      final repayment = Repayment(
        id: 'rep-ob-1',
        sourceType: RepaymentSourceType.directUdhar,
        sourceId: obLoan.id,
        amount: 500,
        paymentMode: 'cash',
        paidAt: now,
        createdAt: now,
      );

      final repRes = await directUdharRepo.recordRepayment(obLoan.id, repayment);
      expect(repRes.isRight(), isTrue);

      final updatedLoan = (await directUdharRepo.findById(obLoan.id)).getOrElse((_) => null);
      expect(updatedLoan, isNotNull);
      expect(updatedLoan!.outstandingBalance, 9700.0);

      final balRes = await contactRepo.getTotalBalance(contact.id);
      expect(balRes.isRight(), isTrue);
      expect(balRes.getOrElse((_) => 0), 9700.0);
    });

    // 7. Deleted opening balance exclusion
    test('7. Soft-deleted opening balance is excluded from balance calculation', () async {
      final obLoan = DirectUdharLoan(
        id: 'ob-deleted',
        contactId: contact.id,
        direction: LoanDirection.lent,
        principalAmount: 20000,
        interestType: InterestType.interestFree,
        memo: '[Opening Balance]',
        status: LoanStatus.open,
        outstandingBalance: 20000,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isDeleted: true,
      );

      final box = HiveRegistrar.directUdharBox;
      await box.put(obLoan.id, DirectUdharLoanModel.fromEntity(obLoan).toMap());

      final balRes = await contactRepo.getTotalBalance(contact.id);
      expect(balRes.isRight(), isTrue);
      expect(balRes.getOrElse((_) => 0), 0.0);
    });

    // 8. Closed/settled opening balance exclusion
    test('8. Closed opening balance is excluded from active balance', () async {
      final obLoan = DirectUdharLoan(
        id: 'ob-closed',
        contactId: contact.id,
        direction: LoanDirection.lent,
        principalAmount: 12000,
        interestType: InterestType.interestFree,
        memo: '[Opening Balance]',
        status: LoanStatus.closed,
        outstandingBalance: 0,
        createdAt: DateTime.now().subtract(const Duration(days: 60)),
        updatedAt: DateTime.now(),
      );

      final box = HiveRegistrar.directUdharBox;
      await box.put(obLoan.id, DirectUdharLoanModel.fromEntity(obLoan).toMap());

      final balRes = await contactRepo.getTotalBalance(contact.id);
      expect(balRes.isRight(), isTrue);
      expect(balRes.getOrElse((_) => 0), 0.0);
    });

    // 9. Interest-free balance never accrues interest
    test('9. Interest-free opening balance never accrues interest regardless of age', () async {
      final obLoan = DirectUdharLoan(
        id: 'ob-if-9',
        contactId: contact.id,
        direction: LoanDirection.lent,
        principalAmount: 50000,
        interestType: InterestType.interestFree,
        memo: '[Opening Balance]',
        status: LoanStatus.open,
        outstandingBalance: 50000,
        createdAt: DateTime.now().subtract(const Duration(days: 730)), // 2 years old
        updatedAt: DateTime.now().subtract(const Duration(days: 730)),
      );

      final box = HiveRegistrar.directUdharBox;
      await box.put(obLoan.id, DirectUdharLoanModel.fromEntity(obLoan).toMap());

      final balRes = await contactRepo.getTotalBalance(contact.id);
      expect(balRes.isRight(), isTrue);
      expect(balRes.getOrElse((_) => 0), 50000.0);
    });

    // 10. Opening Date interest calculation
    test('10. Opening Date starts interest calculation accurately', () async {
      final startDate = DateTime(2026, 1, 1);
      final evalDate = DateTime(2026, 1, 31); // exactly 30 days
      final obLoan = DirectUdharLoan(
        id: 'ob-date-10',
        contactId: contact.id,
        direction: LoanDirection.lent,
        principalAmount: 10000,
        interestType: InterestType.simple,
        interestRatePercent: 2.0,
        memo: '[Opening Balance]',
        status: LoanStatus.open,
        outstandingBalance: 10000,
        createdAt: startDate,
        updatedAt: startDate,
      );

      final summary = InterestCalculator.calculateSummary(
        loan: obLoan,
        repayments: [],
        asOfDate: evalDate,
      );

      expect(summary.accruedInterest, 200.0);
      expect(summary.totalOutstanding, 10200.0);
    });

    // 11. SQLite/Hive Parity for Opening Balance
    test('11. SQLite and Hive produce identical Opening Balance calculation', () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final sqliteDb = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE direct_udhar_loans (
              id TEXT PRIMARY KEY,
              contact_id TEXT,
              direction TEXT,
              principal_amount REAL,
              interest_type TEXT,
              interest_rate_percent REAL,
              due_date TEXT,
              memo TEXT,
              status TEXT,
              outstanding_balance REAL,
              created_at TEXT,
              updated_at TEXT,
              is_deleted INTEGER DEFAULT 0
            );
          ''');
          await db.execute('''
            CREATE TABLE repayments (
              id TEXT PRIMARY KEY,
              source_type TEXT,
              source_id TEXT,
              amount REAL,
              payment_mode TEXT,
              paid_at TEXT,
              memo TEXT,
              created_at TEXT,
              is_deleted INTEGER DEFAULT 0
            );
          ''');
        },
      );
      final sqliteDataSource = ContactSqliteDataSource(
        DatabaseHelper(AppDatabase.instance..overrideForTesting(sqliteDb)),
      );

      final now = DateTime.now();
      final obLoan = DirectUdharLoan(
        id: 'ob-parity',
        contactId: contact.id,
        direction: LoanDirection.lent,
        principalAmount: 20000,
        interestType: InterestType.simple,
        interestRatePercent: 1.5,
        memo: '[Opening Balance]',
        status: LoanStatus.open,
        outstandingBalance: 20000,
        createdAt: now.subtract(const Duration(days: 30)),
        updatedAt: now.subtract(const Duration(days: 30)),
      );

      // Hive
      await HiveRegistrar.directUdharBox.put(obLoan.id, DirectUdharLoanModel.fromEntity(obLoan).toMap());
      // SQLite
      await sqliteDb.insert('direct_udhar_loans', DirectUdharLoanModel.fromEntity(obLoan).toMap());

      final hiveBal = await hiveDataSource.getTotalBalance(contact.id);
      final sqliteBal = await sqliteDataSource.getTotalBalance(contact.id);

      expect(hiveBal, sqliteBal);
      expect(hiveBal, 20300.0); // 20,000 + 1.5% = 20,300
      await sqliteDb.close();
    });

    // 12. PDF receipt data contains correct Opening Balance values
    test('12. PDF receipt generator produces valid document bytes with opening balance data', () async {
      const pdfService = DirectUdharPdfService();
      final obLoan = DirectUdharLoan(
        id: 'ob-pdf-12',
        contactId: contact.id,
        direction: LoanDirection.lent,
        principalAmount: 10000,
        interestType: InterestType.simple,
        interestRatePercent: 2.0,
        memo: '[Opening Balance] Carry forward balance',
        status: LoanStatus.open,
        outstandingBalance: 10000,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      final bytes = await pdfService.generateReceiptPdf(
        loan: obLoan,
        contact: contact,
        customTitle: 'Opening Balance Acknowledgment',
      );

      expect(bytes, isNotNull);
      expect(bytes.isNotEmpty, isTrue);
    });

    // 13. WhatsApp/SMS message template receives correct summary across English, Hindi, and Hinglish
    test('13. Message templates format Opening Balance correctly in English, Hindi, and Hinglish', () {
      const shareService = DirectUdharShareService();
      final obLoan = DirectUdharLoan(
        id: 'ob-msg-13',
        contactId: contact.id,
        direction: LoanDirection.lent,
        principalAmount: 10000,
        interestType: InterestType.simple,
        interestRatePercent: 2.0,
        memo: 'Previous balance',
        status: LoanStatus.open,
        outstandingBalance: 10000,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      final enMsg = shareService.buildMessageText(
        loan: obLoan,
        contact: contact,
        language: ShareLanguage.english,
        isOpeningBalance: true,
      );
      expect(enMsg.contains('Opening Balance Acknowledgment'), isTrue);
      expect(enMsg.contains('Dear Ramesh Shah'), isTrue);
      expect(enMsg.contains('10,000.00'), isTrue);
      expect(enMsg.contains('Lent (Receivable)'), isTrue);
      expect(enMsg.contains('Simple Interest (2.0%/mo)'), isTrue);

      final hiMsg = shareService.buildMessageText(
        loan: obLoan,
        contact: contact,
        language: ShareLanguage.hindi,
        isOpeningBalance: true,
      );
      expect(hiMsg.contains('शुरुआती शेष (Opening Balance)'), isTrue);
      expect(hiMsg.contains('नमस्ते Ramesh Shah जी'), isTrue);
      expect(hiMsg.contains('10,000.00'), isTrue);
      expect(hiMsg.contains('दिया गया (Lent)'), isTrue);

      final hinglishMsg = shareService.buildMessageText(
        loan: obLoan,
        contact: contact,
        language: ShareLanguage.hinglish,
        isOpeningBalance: true,
      );
      expect(hinglishMsg.contains('Opening Balance Update'), isTrue);
      expect(hinglishMsg.contains('Namaste Ramesh Shah ji'), isTrue);
      expect(hinglishMsg.contains('10,000.00'), isTrue);
      expect(hinglishMsg.contains('Diya gaya (Lent)'), isTrue);
    });

    // 14. Regular Udhar entry message templates in English, Hindi, and Hinglish
    test('14. Message templates format regular Direct Udhar entry correctly in English, Hindi, and Hinglish', () {
      const shareService = DirectUdharShareService();
      final regularLoan = DirectUdharLoan(
        id: 'reg-loan-14',
        contactId: contact.id,
        direction: LoanDirection.borrowed,
        principalAmount: 5000,
        interestType: InterestType.interestFree,
        status: LoanStatus.open,
        outstandingBalance: 5000,
        createdAt: DateTime(2026, 2, 1),
        updatedAt: DateTime(2026, 2, 1),
      );

      final enMsg = shareService.buildMessageText(
        loan: regularLoan,
        contact: contact,
        language: ShareLanguage.english,
        isOpeningBalance: false,
      );
      expect(enMsg.contains('Direct Udhar Voucher'), isTrue);
      expect(enMsg.contains('Borrowed (Payable)'), isTrue);
      expect(enMsg.contains('5,000.00'), isTrue);

      final hiMsg = shareService.buildMessageText(
        loan: regularLoan,
        contact: contact,
        language: ShareLanguage.hindi,
        isOpeningBalance: false,
      );
      expect(hiMsg.contains('उधार पर्ची (Udhar)'), isTrue);
      expect(hiMsg.contains('लिया गया (Borrowed)'), isTrue);

      final hinglishMsg = shareService.buildMessageText(
        loan: regularLoan,
        contact: contact,
        language: ShareLanguage.hinglish,
        isOpeningBalance: false,
      );
      expect(hinglishMsg.contains('Udhar Entry'), isTrue);
      expect(hinglishMsg.contains('Liya gaya (Borrowed)'), isTrue);
    });

    // 15. No share/send when contact phone is missing
    test('15. Share via WhatsApp and SMS returns false when contact mobile is missing', () async {
      const shareService = DirectUdharShareService();
      final contactWithoutPhone = contact.copyWith(mobileNumber: '');
      final obLoan = DirectUdharLoan(
        id: 'ob-15',
        contactId: contact.id,
        direction: LoanDirection.lent,
        principalAmount: 5000,
        interestType: InterestType.interestFree,
        status: LoanStatus.open,
        outstandingBalance: 5000,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final waResult = await shareService.shareViaWhatsApp(
        loan: obLoan,
        contact: contactWithoutPhone,
        language: ShareLanguage.hindi,
      );
      final smsResult = await shareService.sendSms(
        loan: obLoan,
        contact: contactWithoutPhone,
        language: ShareLanguage.hinglish,
      );

      expect(waResult, isFalse);
      expect(smsResult, isFalse);
    });
  });
}
