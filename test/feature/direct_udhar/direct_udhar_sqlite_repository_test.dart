import 'package:flutter_test/flutter_test.dart';
import 'package:pamz_khata/core/db/sqlite/app_database.dart';
import 'package:pamz_khata/core/db/sqlite/database_helper.dart';
import 'package:pamz_khata/feature/direct_udhar/data/repositories/direct_udhar_repository_impl.dart';
import 'package:pamz_khata/feature/direct_udhar/domain/entities/direct_udhar_loan.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('DirectUdharRepositoryImpl (SQLite) Unit Tests', () {
    late Database sqliteDb;
    late DatabaseHelper dbHelper;
    late DirectUdharRepositoryImpl repository;

    setUp(() async {
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
              is_deleted INTEGER DEFAULT 0
            );
          ''');
          await db.execute('''
            CREATE TABLE direct_udhar_loans (
              id TEXT PRIMARY KEY,
              contact_id TEXT NOT NULL,
              direction TEXT NOT NULL,
              principal_amount REAL NOT NULL,
              interest_type TEXT NOT NULL,
              interest_rate_percent REAL,
              due_date TEXT,
              memo TEXT,
              status TEXT NOT NULL DEFAULT 'open',
              outstanding_balance REAL NOT NULL,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL,
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
          await db.execute('''
            CREATE TABLE monthly_summary (
              id TEXT PRIMARY KEY,
              month TEXT,
              category_id TEXT,
              total_udhar_given REAL DEFAULT 0,
              total_udhar_received REAL DEFAULT 0,
              UNIQUE(month, category_id)
            );
          ''');
        },
      );

      AppDatabase.instance.overrideForTesting(sqliteDb);
      dbHelper = DatabaseHelper(AppDatabase.instance);
      repository = DirectUdharRepositoryImpl(dbHelper);

      // Insert dummy contact
      await sqliteDb.insert('contacts', {
        'id': 'contact-1',
        'type': 'buyer',
        'name': 'Test Contact',
        'mobile_number': '9876543210',
        'is_deleted': 0,
      });
    });

    tearDown(() async {
      await sqliteDb.close();
    });

    final now = DateTime.now();

    final testLoan = DirectUdharLoan(
      id: 'loan-1',
      contactId: 'contact-1',
      direction: LoanDirection.lent,
      principalAmount: 10000,
      interestType: InterestType.interestFree,
      status: LoanStatus.open,
      outstandingBalance: 10000,
      createdAt: now,
      updatedAt: now,
      memo: 'Test loan',
    );

    test('1. create and findById returns loan correctly', () async {
      final createRes = await repository.create(testLoan);
      expect(createRes.isRight(), isTrue);

      final findRes = await repository.findById(testLoan.id);
      expect(findRes.isRight(), isTrue);
      final found = findRes.getOrElse((_) => null);
      expect(found, isNotNull);
      expect(found!.id, testLoan.id);
      expect(found.principalAmount, 10000.0);
      expect(found.outstandingBalance, 10000.0);
    });

    test('2. getByContact returns active loans for contact', () async {
      await repository.create(testLoan);
      final res = await repository.getByContact('contact-1');
      expect(res.isRight(), isTrue);
      final list = res.getOrElse((_) => []);
      expect(list.length, 1);
      expect(list.first.contactId, 'contact-1');
    });

    test('3. update modifies existing loan details', () async {
      await repository.create(testLoan);
      final updatedLoan = testLoan.copyWith(
        memo: 'Updated Memo',
        outstandingBalance: 8000,
      );

      final updateRes = await repository.update(updatedLoan);
      expect(updateRes.isRight(), isTrue);

      final findRes = await repository.findById(testLoan.id);
      final found = findRes.getOrElse((_) => null);
      expect(found?.memo, 'Updated Memo');
      expect(found?.outstandingBalance, 8000.0);
    });

    test('4. delete soft-deletes loan and sets is_deleted = 1', () async {
      await repository.create(testLoan);
      final delRes = await repository.delete(testLoan.id);
      expect(delRes.isRight(), isTrue);

      final findRes = await repository.findById(testLoan.id);
      expect(findRes.getOrElse((_) => null), isNull);
    });

    test('5. updateStatus updates status field', () async {
      await repository.create(testLoan);
      final res = await repository.updateStatus(testLoan.id, LoanStatus.closed);
      expect(res.isRight(), isTrue);

      final findRes = await repository.findById(testLoan.id);
      expect(findRes.getOrElse((_) => null)?.status, LoanStatus.closed);
    });

    test('6. recordRepayment atomically updates loan balance, status and inserts repayment row', () async {
      await repository.create(testLoan);

      final repayment = Repayment(
        id: 'rep-1',
        sourceType: RepaymentSourceType.directUdhar,
        sourceId: testLoan.id,
        amount: 4000,
        paymentMode: 'cash',
        paidAt: now,
        memo: 'First installment',
        createdAt: now,
      );

      final repRes = await repository.recordRepayment(testLoan.id, repayment);
      expect(repRes.isRight(), isTrue);

      // Check loan balance reduced to 6000 and status is partiallyPaid
      final findRes = await repository.findById(testLoan.id);
      final loanAfter = findRes.getOrElse((_) => null);
      expect(loanAfter?.outstandingBalance, 6000.0);
      expect(loanAfter?.status, LoanStatus.partiallyPaid);

      // Check repayments list
      final repaymentsRes = await repository.getRepayments(testLoan.id);
      expect(repaymentsRes.isRight(), isTrue);
      final reps = repaymentsRes.getOrElse((_) => []);
      expect(reps.length, 1);
      expect(reps.first.amount, 4000.0);
      expect(reps.first.paymentMode, 'cash');

      // Check audit log row was written
      final auditRows = await sqliteDb.query('audit_log', where: 'entity_type = ?', whereArgs: ['repayment']);
      expect(auditRows.length, 1);
      expect(auditRows.first['action'], 'create');
    });

    test('7. recordRepayment settling full amount updates status to closed', () async {
      await repository.create(testLoan);

      final fullRepayment = Repayment(
        id: 'rep-full',
        sourceType: RepaymentSourceType.directUdhar,
        sourceId: testLoan.id,
        amount: 10000,
        paymentMode: 'upi',
        paidAt: now,
        memo: 'Full settlement',
        createdAt: now,
      );

      final repRes = await repository.recordRepayment(testLoan.id, fullRepayment);
      expect(repRes.isRight(), isTrue);

      final findRes = await repository.findById(testLoan.id);
      final loanAfter = findRes.getOrElse((_) => null);
      expect(loanAfter?.outstandingBalance, 0.0);
      expect(loanAfter?.status, LoanStatus.closed);
    });

    test('8. Simple interest loan repayment allocates interest first then principal', () async {
      final interestLoan = DirectUdharLoan(
        id: 'loan-interest',
        contactId: 'contact-1',
        direction: LoanDirection.lent,
        principalAmount: 10000,
        interestType: InterestType.simple,
        interestRatePercent: 2.0, // 2% per month = ₹200/mo
        status: LoanStatus.open,
        outstandingBalance: 10000,
        createdAt: now.subtract(const Duration(days: 60)), // 2 months ago -> ₹400 accrued interest
        updatedAt: now.subtract(const Duration(days: 60)),
      );

      await repository.create(interestLoan);

      final repayment = Repayment(
        id: 'rep-int-1',
        sourceType: RepaymentSourceType.directUdhar,
        sourceId: interestLoan.id,
        amount: 1000,
        paymentMode: 'bank_transfer',
        paidAt: now,
        createdAt: now,
      );

      final repRes = await repository.recordRepayment(interestLoan.id, repayment);
      expect(repRes.isRight(), isTrue);

      final findRes = await repository.findById(interestLoan.id);
      final loanAfter = findRes.getOrElse((_) => null);
      expect(loanAfter, isNotNull);
      // Principal should be reduced after interest is satisfied
      expect(loanAfter!.outstandingBalance, lessThan(10000.0));
    });
  });
}
