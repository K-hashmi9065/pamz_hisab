import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pamz_khata/core/db/hive/hive_registrar.dart';
import 'package:pamz_khata/core/db/sqlite/app_database.dart';
import 'package:pamz_khata/core/db/sqlite/database_helper.dart';
import 'package:pamz_khata/feature/contacts/data/datasources/contact_hive_datasource.dart';
import 'package:pamz_khata/feature/contacts/data/datasources/contact_sqlite_datasource.dart';
import 'package:pamz_khata/feature/contacts/data/repositories/contact_repository_impl.dart';
import 'package:pamz_khata/feature/direct_udhar/data/models/direct_udhar_models.dart';
import 'package:pamz_khata/feature/direct_udhar/domain/entities/direct_udhar_loan.dart';
import 'package:pamz_khata/feature/direct_udhar/domain/services/interest_calculator.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  group('Direct Udhar Contact Balance - Hive DataSource Tests', () {
    late Directory tempDir;
    const dataSource = ContactHiveDataSource();
    const repository = ContactRepositoryImpl(dataSource);
    const contactId = 'contact-test-001';

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('hive_contact_bal_test_');
      await HiveRegistrar.initialize(tempDir.path);
    });

    tearDown(() async {
      await Hive.close();
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    // 1. Interest-free lent loan
    test('1. Interest-free lent loan: Principal Rs.10,000 -> balance = Rs.10,000', () async {
      final loan = DirectUdharLoan(
        id: 'loan-1',
        contactId: contactId,
        direction: LoanDirection.lent,
        principalAmount: 10000,
        interestType: InterestType.interestFree,
        status: LoanStatus.open,
        outstandingBalance: 10000,
        createdAt: DateTime.now().subtract(const Duration(days: 60)),
        updatedAt: DateTime.now().subtract(const Duration(days: 60)),
      );

      final box = HiveRegistrar.directUdharBox;
      await box.put(loan.id, DirectUdharLoanModel.fromEntity(loan).toMap());

      final res = await repository.getTotalBalance(contactId);
      expect(res.isRight(), isTrue);
      expect(res.getOrElse((_) => 0), 10000.0);
    });

    // 2. Simple-interest lent loan
    test('2. Simple-interest lent loan: Accrued unpaid interest is included in balance', () async {
      final now = DateTime.now();
      final loan = DirectUdharLoan(
        id: 'loan-2',
        contactId: contactId,
        direction: LoanDirection.lent,
        principalAmount: 10000,
        interestType: InterestType.simple,
        interestRatePercent: 2.0, // 2% per 30 days
        status: LoanStatus.open,
        outstandingBalance: 10000,
        createdAt: now.subtract(const Duration(days: 30)),
        updatedAt: now.subtract(const Duration(days: 30)),
      );

      final box = HiveRegistrar.directUdharBox;
      await box.put(loan.id, DirectUdharLoanModel.fromEntity(loan).toMap());

      // Interest = 10000 * 2% * (30/30) = 200. Total = 10200.
      final expectedSummary = InterestCalculator.calculateSummary(
        loan: loan,
        repayments: [],
        asOfDate: now,
      );

      final res = await repository.getTotalBalance(contactId);
      expect(res.isRight(), isTrue);
      expect(res.getOrElse((_) => 0), expectedSummary.totalOutstanding);
      expect(res.getOrElse((_) => 0), 10200.0);
    });

    // 3. Simple-interest borrowed loan
    test('3. Simple-interest borrowed loan: Accrued interest is included and net balance is negative', () async {
      final now = DateTime.now();
      final loan = DirectUdharLoan(
        id: 'loan-3',
        contactId: contactId,
        direction: LoanDirection.borrowed,
        principalAmount: 5000,
        interestType: InterestType.simple,
        interestRatePercent: 3.0, // 3% per 30 days
        status: LoanStatus.open,
        outstandingBalance: 5000,
        createdAt: now.subtract(const Duration(days: 30)),
        updatedAt: now.subtract(const Duration(days: 30)),
      );

      final box = HiveRegistrar.directUdharBox;
      await box.put(loan.id, DirectUdharLoanModel.fromEntity(loan).toMap());

      // Interest = 5000 * 3% * (30/30) = 150. Total borrowed = 5150. Net balance = -5150.
      final expectedSummary = InterestCalculator.calculateSummary(
        loan: loan,
        repayments: [],
        asOfDate: now,
      );

      final res = await repository.getTotalBalance(contactId);
      expect(res.isRight(), isTrue);
      expect(res.getOrElse((_) => 0), -expectedSummary.totalOutstanding);
      expect(res.getOrElse((_) => 0), -5150.0);
    });

    // 4. Multiple active loans
    test('4. Multiple active loans: Aggregates lent and borrowed loans with interest', () async {
      final now = DateTime.now();
      final lentLoan = DirectUdharLoan(
        id: 'loan-lent',
        contactId: contactId,
        direction: LoanDirection.lent,
        principalAmount: 10000,
        interestType: InterestType.simple,
        interestRatePercent: 2.0,
        status: LoanStatus.open,
        outstandingBalance: 10000,
        createdAt: now.subtract(const Duration(days: 30)),
        updatedAt: now.subtract(const Duration(days: 30)),
      );

      final borrowedLoan = DirectUdharLoan(
        id: 'loan-borrowed',
        contactId: contactId,
        direction: LoanDirection.borrowed,
        principalAmount: 4000,
        interestType: InterestType.interestFree,
        status: LoanStatus.open,
        outstandingBalance: 4000,
        createdAt: now.subtract(const Duration(days: 10)),
        updatedAt: now.subtract(const Duration(days: 10)),
      );

      final box = HiveRegistrar.directUdharBox;
      await box.put(lentLoan.id, DirectUdharLoanModel.fromEntity(lentLoan).toMap());
      await box.put(borrowedLoan.id, DirectUdharLoanModel.fromEntity(borrowedLoan).toMap());

      // Lent total = 10,200, Borrowed total = 4,000. Net = 10,200 - 4,000 = 6,200.
      final res = await repository.getTotalBalance(contactId);
      expect(res.isRight(), isTrue);
      expect(res.getOrElse((_) => 0), 6200.0);
    });

    // 5. Deleted loan
    test('5. Deleted loan: Soft-deleted loan does not affect contact balance', () async {
      final activeLoan = DirectUdharLoan(
        id: 'loan-active',
        contactId: contactId,
        direction: LoanDirection.lent,
        principalAmount: 5000,
        interestType: InterestType.interestFree,
        status: LoanStatus.open,
        outstandingBalance: 5000,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final deletedLoan = DirectUdharLoan(
        id: 'loan-deleted',
        contactId: contactId,
        direction: LoanDirection.lent,
        principalAmount: 10000,
        interestType: InterestType.interestFree,
        status: LoanStatus.open,
        outstandingBalance: 10000,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isDeleted: true,
      );

      final box = HiveRegistrar.directUdharBox;
      await box.put(activeLoan.id, DirectUdharLoanModel.fromEntity(activeLoan).toMap());
      await box.put(deletedLoan.id, DirectUdharLoanModel.fromEntity(deletedLoan).toMap());

      final res = await repository.getTotalBalance(contactId);
      expect(res.isRight(), isTrue);
      expect(res.getOrElse((_) => 0), 5000.0);
    });

    // 6. Closed loan
    test('6. Closed loan: Closed loan does not affect contact balance', () async {
      final activeLoan = DirectUdharLoan(
        id: 'loan-open',
        contactId: contactId,
        direction: LoanDirection.lent,
        principalAmount: 3000,
        interestType: InterestType.interestFree,
        status: LoanStatus.open,
        outstandingBalance: 3000,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final closedLoan = DirectUdharLoan(
        id: 'loan-closed',
        contactId: contactId,
        direction: LoanDirection.lent,
        principalAmount: 7000,
        interestType: InterestType.interestFree,
        status: LoanStatus.closed,
        outstandingBalance: 0,
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
        updatedAt: DateTime.now(),
      );

      final box = HiveRegistrar.directUdharBox;
      await box.put(activeLoan.id, DirectUdharLoanModel.fromEntity(activeLoan).toMap());
      await box.put(closedLoan.id, DirectUdharLoanModel.fromEntity(closedLoan).toMap());

      final res = await repository.getTotalBalance(contactId);
      expect(res.isRight(), isTrue);
      expect(res.getOrElse((_) => 0), 3000.0);
    });

    // 7. Repayment with remaining interest
    test('7. Repayment with remaining interest: Balance equals remaining principal + unpaid interest', () async {
      final now = DateTime.now();
      // Loan created 30 days ago: 10,000 at 2% = 200 interest at day 30
      final loan = DirectUdharLoan(
        id: 'loan-repay',
        contactId: contactId,
        direction: LoanDirection.lent,
        principalAmount: 10000,
        interestType: InterestType.simple,
        interestRatePercent: 2.0,
        status: LoanStatus.partiallyPaid,
        outstandingBalance: 9900, // 10000 - 100 principal paid
        createdAt: now.subtract(const Duration(days: 30)),
        updatedAt: now.subtract(const Duration(days: 30)),
      );

      // Repayment of 300 on day 30: 200 interest accrued (10,000 * 2% * 30/30) + 100 principal -> remaining principal = 9,900
      final repayment = Repayment(
        id: 'rep-1',
        sourceType: RepaymentSourceType.directUdhar,
        sourceId: loan.id,
        amount: 300,
        paymentMode: 'cash',
        paidAt: now,
        createdAt: now,
      );

      final loanBox = HiveRegistrar.directUdharBox;
      final repBox = HiveRegistrar.repaymentsBox;
      await loanBox.put(loan.id, DirectUdharLoanModel.fromEntity(loan).toMap());
      await repBox.put(repayment.id, RepaymentModel.fromEntity(repayment).toMap());

      // At day 30: Remaining principal = 9,900, accrued interest = 0.
      final expectedSummary = InterestCalculator.calculateSummary(
        loan: loan,
        repayments: [repayment],
        asOfDate: now,
      );

      final res = await repository.getTotalBalance(contactId);
      expect(res.isRight(), isTrue);
      expect(res.getOrElse((_) => 0), expectedSummary.totalOutstanding);
      expect(res.getOrElse((_) => 0), 9900.0);
    });

    // 8. Deleted repayment
    test('8. Deleted repayment: Soft-deleted repayment does not reduce balance', () async {
      final now = DateTime.now();
      final loan = DirectUdharLoan(
        id: 'loan-del-rep',
        contactId: contactId,
        direction: LoanDirection.lent,
        principalAmount: 10000,
        interestType: InterestType.interestFree,
        status: LoanStatus.open,
        outstandingBalance: 10000,
        createdAt: now.subtract(const Duration(days: 30)),
        updatedAt: now.subtract(const Duration(days: 30)),
      );

      final deletedRepayment = Repayment(
        id: 'rep-deleted',
        sourceType: RepaymentSourceType.directUdhar,
        sourceId: loan.id,
        amount: 5000,
        paymentMode: 'cash',
        paidAt: now.subtract(const Duration(days: 15)),
        createdAt: now.subtract(const Duration(days: 15)),
        isDeleted: true,
      );

      final loanBox = HiveRegistrar.directUdharBox;
      final repBox = HiveRegistrar.repaymentsBox;
      await loanBox.put(loan.id, DirectUdharLoanModel.fromEntity(loan).toMap());
      await repBox.put(deletedRepayment.id, RepaymentModel.fromEntity(deletedRepayment).toMap());

      final res = await repository.getTotalBalance(contactId);
      expect(res.isRight(), isTrue);
      expect(res.getOrElse((_) => 0), 10000.0);
    });

    // 10. Interest-free edge case
    test('10. Interest-free edge case: No accrued interest is added regardless of elapsed days', () async {
      final loan = DirectUdharLoan(
        id: 'loan-if-edge',
        contactId: contactId,
        direction: LoanDirection.lent,
        principalAmount: 25000,
        interestType: InterestType.interestFree,
        interestRatePercent: 5.0, // Should be ignored since interestType is interestFree
        status: LoanStatus.open,
        outstandingBalance: 25000,
        createdAt: DateTime.now().subtract(const Duration(days: 365)),
        updatedAt: DateTime.now().subtract(const Duration(days: 365)),
      );

      final box = HiveRegistrar.directUdharBox;
      await box.put(loan.id, DirectUdharLoanModel.fromEntity(loan).toMap());

      final res = await repository.getTotalBalance(contactId);
      expect(res.isRight(), isTrue);
      expect(res.getOrElse((_) => 0), 25000.0);
    });
  });

  // 9. SQLite / Hive Parity Test
  group('Direct Udhar Contact Balance - SQLite and Hive Parity Tests', () {
    late Directory tempDir;
    late Database sqliteDb;
    late ContactSqliteDataSource sqliteDataSource;
    const hiveDataSource = ContactHiveDataSource();
    const contactId = 'contact-parity-001';

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('parity_test_');
      await HiveRegistrar.initialize(tempDir.path);

      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      sqliteDb = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE contacts (
              id TEXT PRIMARY KEY,
              type TEXT,
              name TEXT,
              mobile_number TEXT,
              address TEXT,
              village_tola TEXT,
              shop_location TEXT,
              credit_limit REAL DEFAULT 0,
              due_date_alert_enabled INTEGER DEFAULT 0,
              created_at TEXT,
              updated_at TEXT,
              is_deleted INTEGER DEFAULT 0
            );
          ''');
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
          await db.execute('''
            CREATE TABLE audit_log (
              id TEXT PRIMARY KEY,
              entity_type TEXT,
              entity_id TEXT,
              action TEXT,
              changed_fields_json TEXT,
              performed_at TEXT
            );
          ''');
        },
      );
      sqliteDataSource = ContactSqliteDataSource(DatabaseHelper(AppDatabase.instance..overrideForTesting(sqliteDb)));
    });

    tearDown(() async {
      await sqliteDb.close();
      await Hive.close();
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('9. SQLite and Hive produce the exact same total balance for complex multi-loan scenario', () async {
      final now = DateTime.now();

      // Loan 1: Lent Simple Interest 10,000 at 2% for 30 days
      final loan1 = DirectUdharLoan(
        id: 'p-loan-1',
        contactId: contactId,
        direction: LoanDirection.lent,
        principalAmount: 10000,
        interestType: InterestType.simple,
        interestRatePercent: 2.0,
        status: LoanStatus.open,
        outstandingBalance: 10000,
        createdAt: now.subtract(const Duration(days: 30)),
        updatedAt: now.subtract(const Duration(days: 30)),
      );

      // Loan 2: Borrowed Interest-free 4,000
      final loan2 = DirectUdharLoan(
        id: 'p-loan-2',
        contactId: contactId,
        direction: LoanDirection.borrowed,
        principalAmount: 4000,
        interestType: InterestType.interestFree,
        status: LoanStatus.open,
        outstandingBalance: 4000,
        createdAt: now.subtract(const Duration(days: 10)),
        updatedAt: now.subtract(const Duration(days: 10)),
      );

      // Loan 3: Closed Loan (should be ignored by both)
      final loan3 = DirectUdharLoan(
        id: 'p-loan-3',
        contactId: contactId,
        direction: LoanDirection.lent,
        principalAmount: 8000,
        interestType: InterestType.interestFree,
        status: LoanStatus.closed,
        outstandingBalance: 0,
        createdAt: now.subtract(const Duration(days: 60)),
        updatedAt: now.subtract(const Duration(days: 5)),
      );

      // Repayment on Loan 1 of 100 at day 30 (partially covers 200 interest, leaves 100 interest + 10,000 principal = 10,100)
      final rep1 = Repayment(
        id: 'p-rep-1',
        sourceType: RepaymentSourceType.directUdhar,
        sourceId: loan1.id,
        amount: 100,
        paymentMode: 'cash',
        paidAt: now,
        createdAt: now,
      );

      // Insert into Hive
      final hiveLoanBox = HiveRegistrar.directUdharBox;
      final hiveRepBox = HiveRegistrar.repaymentsBox;
      await hiveLoanBox.put(loan1.id, DirectUdharLoanModel.fromEntity(loan1).toMap());
      await hiveLoanBox.put(loan2.id, DirectUdharLoanModel.fromEntity(loan2).toMap());
      await hiveLoanBox.put(loan3.id, DirectUdharLoanModel.fromEntity(loan3).toMap());
      await hiveRepBox.put(rep1.id, RepaymentModel.fromEntity(rep1).toMap());

      // Insert into SQLite
      await sqliteDb.insert('direct_udhar_loans', DirectUdharLoanModel.fromEntity(loan1).toMap());
      await sqliteDb.insert('direct_udhar_loans', DirectUdharLoanModel.fromEntity(loan2).toMap());
      await sqliteDb.insert('direct_udhar_loans', DirectUdharLoanModel.fromEntity(loan3).toMap());
      await sqliteDb.insert('repayments', RepaymentModel.fromEntity(rep1).toMap());

      // Execute both
      final hiveBalance = await hiveDataSource.getTotalBalance(contactId);
      final sqliteBalance = await sqliteDataSource.getTotalBalance(contactId);

      expect(hiveBalance, sqliteBalance);
      // Day 30 interest on loan1 = 200. Repay 100 -> remaining interest = 100. Total loan1 = 10,100.
      // Loan2 = -4,000. Net = 6,100.
      expect(hiveBalance, 6100.0);
      expect(sqliteBalance, 6100.0);
    });
  });
}
