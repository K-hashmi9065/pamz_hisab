import 'package:flutter_test/flutter_test.dart';
import 'package:pamz_khata/core/db/sqlite/app_database.dart';
import 'package:pamz_khata/core/db/sqlite/database_helper.dart';
import 'package:pamz_khata/feature/contacts/data/datasources/contact_sqlite_datasource.dart';
import 'package:pamz_khata/feature/contacts/data/repositories/contact_repository_impl.dart';
import 'package:pamz_khata/feature/contacts/domain/entities/contact.dart';
import 'package:pamz_khata/feature/direct_udhar/data/repositories/direct_udhar_repository_impl.dart';
import 'package:pamz_khata/feature/direct_udhar/domain/entities/direct_udhar_loan.dart';
import 'package:pamz_khata/feature/direct_udhar/domain/usecases/direct_udhar_usecases.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('GAP-INT01 — Direct Udhar Lifecycle Cross-Layer Integration Tests', () {
    late Database sqliteDb;
    late DatabaseHelper dbHelper;
    late ContactRepositoryImpl contactRepo;
    late DirectUdharRepositoryImpl directUdharRepo;
    late CreateDirectLoanUsecase createLoanUsecase;
    late LogRepaymentUsecase logRepaymentUsecase;

    setUp(() async {
      sqliteDb = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE contacts (
              id                    TEXT PRIMARY KEY,
              type                  TEXT NOT NULL,
              name                  TEXT NOT NULL,
              mobile_number         TEXT NOT NULL,
              address               TEXT,
              village_tola          TEXT,
              shop_location         TEXT,
              credit_limit          REAL DEFAULT 0,
              due_date_alert_enabled INTEGER DEFAULT 0,
              created_at            TEXT NOT NULL,
              updated_at            TEXT NOT NULL,
              is_deleted            INTEGER DEFAULT 0
            );
          ''');
          await db.execute('''
            CREATE TABLE direct_udhar_loans (
              id                    TEXT PRIMARY KEY,
              contact_id            TEXT NOT NULL,
              direction             TEXT NOT NULL,
              principal_amount      REAL NOT NULL,
              interest_type         TEXT NOT NULL,
              interest_rate_percent REAL,
              due_date              TEXT,
              memo                  TEXT,
              status                TEXT NOT NULL DEFAULT 'open',
              outstanding_balance   REAL NOT NULL,
              created_at            TEXT NOT NULL,
              updated_at            TEXT NOT NULL,
              is_deleted            INTEGER DEFAULT 0
            );
          ''');
          await db.execute('''
            CREATE TABLE repayments (
              id           TEXT PRIMARY KEY,
              source_type  TEXT NOT NULL,
              source_id    TEXT NOT NULL,
              amount       REAL NOT NULL,
              payment_mode TEXT,
              paid_at      TEXT NOT NULL,
              memo         TEXT,
              created_at   TEXT NOT NULL,
              is_deleted   INTEGER DEFAULT 0
            );
          ''');
          await db.execute('''
            CREATE TABLE monthly_summary (
              id                   TEXT PRIMARY KEY,
              month                TEXT NOT NULL,
              category_id          TEXT,
              total_income         REAL DEFAULT 0,
              total_expense        REAL DEFAULT 0,
              total_udhar_given    REAL DEFAULT 0,
              total_udhar_received REAL DEFAULT 0
            );
          ''');
          await db.execute('''
            CREATE UNIQUE INDEX idx_summary_month_category
              ON monthly_summary(month, category_id);
          ''');
          await db.execute('''
            CREATE TABLE audit_log (
              id                  TEXT PRIMARY KEY,
              entity_type         TEXT NOT NULL,
              entity_id           TEXT NOT NULL,
              action              TEXT NOT NULL,
              changed_fields_json TEXT,
              performed_at        TEXT NOT NULL
            );
          ''');
        },
      );

      AppDatabase.instance.overrideForTesting(sqliteDb);
      dbHelper = DatabaseHelper(AppDatabase.instance);

      final contactDataSource = ContactSqliteDataSource(dbHelper);
      contactRepo = ContactRepositoryImpl(contactDataSource);
      directUdharRepo = DirectUdharRepositoryImpl(dbHelper);
      createLoanUsecase = CreateDirectLoanUsecase(directUdharRepo);
      logRepaymentUsecase = LogRepaymentUsecase(directUdharRepo);
    });

    tearDown(() async {
      await AppDatabase.instance.close();
    });

    test('Complete Direct Udhar lifecycle: Contact Creation -> Loan -> Partial Repayment -> Settlement -> Balance Sync', () async {
      // ───────────────────────────────────────────────────────────────────────
      // 1. Create Contact
      // ───────────────────────────────────────────────────────────────────────
      final contactInput = Contact(
        id: 'contact-int-001',
        type: ContactType.buyer,
        name: 'Ramesh Patel',
        mobileNumber: '9876543210',
        address: 'MG Road, Kishanganj',
        createdAt: DateTime(2026, 3, 1),
        updatedAt: DateTime(2026, 3, 1),
      );

      final contactResult = await contactRepo.create(contactInput);
      expect(contactResult.isRight(), isTrue);
      final createdContact = contactResult.getOrElse((_) => throw Exception());

      // Query from SQLite to verify persistence
      final queriedContactRes = await contactRepo.findById(createdContact.id);
      expect(queriedContactRes.isRight(), isTrue);
      final queriedContact = queriedContactRes.getOrElse((_) => null);
      expect(queriedContact, isNotNull);
      expect(queriedContact!.name, 'Ramesh Patel');
      expect(queriedContact.mobileNumber, '9876543210');

      // Initial contact balance should be 0
      final initialBalanceRes = await contactRepo.getTotalBalance(createdContact.id);
      expect(initialBalanceRes.getOrElse((_) => -1.0), 0.0);

      // ───────────────────────────────────────────────────────────────────────
      // 2. Create Direct Udhar Loan (Lent ₹10,000, Interest-Free)
      // ───────────────────────────────────────────────────────────────────────
      final loanInput = DirectUdharLoan(
        id: 'loan-int-001',
        contactId: createdContact.id,
        direction: LoanDirection.lent,
        principalAmount: 10000.0,
        interestType: InterestType.interestFree,
        memo: 'Cash advance for seeds',
        status: LoanStatus.open,
        outstandingBalance: 10000.0,
        createdAt: DateTime(2026, 3, 1, 10, 0),
        updatedAt: DateTime(2026, 3, 1, 10, 0),
      );

      final loanResult = await createLoanUsecase(loanInput);
      expect(loanResult.isRight(), isTrue);

      // Re-query from SQLite
      final queriedLoanRes = await directUdharRepo.findById('loan-int-001');
      expect(queriedLoanRes.isRight(), isTrue);
      final queriedLoan = queriedLoanRes.getOrElse((_) => null);
      expect(queriedLoan, isNotNull);
      expect(queriedLoan!.principalAmount, 10000.0);
      expect(queriedLoan.outstandingBalance, 10000.0);
      expect(queriedLoan.status, LoanStatus.open);
      expect(queriedLoan.direction, LoanDirection.lent);

      // Contact balance must now reflect ₹10,000 receivable
      final postLoanBalanceRes = await contactRepo.getTotalBalance(createdContact.id);
      expect(postLoanBalanceRes.getOrElse((_) => -1.0), 10000.0);

      // ───────────────────────────────────────────────────────────────────────
      // 3. Partial Repayment (₹4,000 Cash)
      // ───────────────────────────────────────────────────────────────────────
      final partialRepaymentRes = await logRepaymentUsecase(
        loanId: 'loan-int-001',
        amount: 4000.0,
        mode: 'cash',
        paidAt: DateTime(2026, 3, 5, 14, 0),
        memo: 'First installment',
      );
      expect(partialRepaymentRes.isRight(), isTrue);

      // Re-query loan state
      final afterPartialLoanRes = await directUdharRepo.findById('loan-int-001');
      final afterPartialLoan = afterPartialLoanRes.getOrElse((_) => null);
      expect(afterPartialLoan, isNotNull);
      expect(afterPartialLoan!.outstandingBalance, 6000.0);
      expect(afterPartialLoan.status, LoanStatus.partiallyPaid);

      // Verify repayment record in SQLite
      final repaymentsRes = await directUdharRepo.getRepayments('loan-int-001');
      expect(repaymentsRes.isRight(), isTrue);
      final repayments = repaymentsRes.getOrElse((_) => []);
      expect(repayments.length, 1);
      expect(repayments.first.amount, 4000.0);
      expect(repayments.first.paymentMode, 'cash');

      // Contact balance must now be ₹6,000
      final afterPartialBalanceRes = await contactRepo.getTotalBalance(createdContact.id);
      expect(afterPartialBalanceRes.getOrElse((_) => -1.0), 6000.0);

      // ───────────────────────────────────────────────────────────────────────
      // 4. Full Settlement (Remaining ₹6,000 via UPI)
      // ───────────────────────────────────────────────────────────────────────
      final fullRepaymentRes = await logRepaymentUsecase(
        loanId: 'loan-int-001',
        amount: 6000.0,
        mode: 'upi',
        paidAt: DateTime(2026, 3, 10, 16, 0),
        memo: 'Full settlement',
      );
      expect(fullRepaymentRes.isRight(), isTrue);

      // Re-query loan state: must be closed with 0 balance
      final afterSettledLoanRes = await directUdharRepo.findById('loan-int-001');
      final afterSettledLoan = afterSettledLoanRes.getOrElse((_) => null);
      expect(afterSettledLoan, isNotNull);
      expect(afterSettledLoan!.outstandingBalance, 0.0);
      expect(afterSettledLoan.status, LoanStatus.closed);

      // Both repayments must be present (ordered by paid_at DESC)
      final allRepaymentsRes = await directUdharRepo.getRepayments('loan-int-001');
      final allRepayments = allRepaymentsRes.getOrElse((_) => []);
      expect(allRepayments.length, 2);
      expect(allRepayments[0].amount, 6000.0); // Latest repayment (March 10)
      expect(allRepayments[1].amount, 4000.0); // Initial repayment (March 5)

      // Contact balance must now be 0
      final finalBalanceRes = await contactRepo.getTotalBalance(createdContact.id);
      expect(finalBalanceRes.getOrElse((_) => -1.0), 0.0);

      // Loans by contact must return the settled loan
      final contactLoansRes = await directUdharRepo.getByContact(createdContact.id);
      final contactLoans = contactLoansRes.getOrElse((_) => []);
      expect(contactLoans.length, 1);
      expect(contactLoans.first.status, LoanStatus.closed);
    });

    test('Overpayment rejection prevents financial corruption in storage', () async {
      final contact = (await contactRepo.create(Contact(
        id: 'contact-overpay',
        type: ContactType.buyer,
        name: 'Suresh Kumar',
        mobileNumber: '9876543211',
        createdAt: DateTime(2026, 3, 1),
        updatedAt: DateTime(2026, 3, 1),
      ))).getOrElse((_) => throw Exception());

      final loan = (await createLoanUsecase(DirectUdharLoan(
        id: 'loan-overpay-001',
        contactId: contact.id,
        direction: LoanDirection.lent,
        principalAmount: 5000.0,
        interestType: InterestType.interestFree,
        status: LoanStatus.open,
        outstandingBalance: 5000.0,
        createdAt: DateTime(2026, 3, 1),
        updatedAt: DateTime(2026, 3, 1),
      ))).getOrElse((_) => throw Exception());

      // Attempt repayment of ₹6,000 on ₹5,000 loan
      final overpayRes = await logRepaymentUsecase(
        loanId: loan.id,
        amount: 6000.0,
        mode: 'cash',
      );

      expect(overpayRes.isLeft(), isTrue);

      // Verify no repayment was written to SQLite and balance remains ₹5,000
      final repayments = (await directUdharRepo.getRepayments(loan.id)).getOrElse((_) => []);
      expect(repayments.isEmpty, isTrue);

      final reloadedLoan = (await directUdharRepo.findById(loan.id)).getOrElse((_) => null);
      expect(reloadedLoan!.outstandingBalance, 5000.0);
      expect(reloadedLoan.status, LoanStatus.open);
    });
  });
}
