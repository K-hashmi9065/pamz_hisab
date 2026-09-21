import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pamz_khata/core/db/hive/hive_registrar.dart';
import 'package:pamz_khata/core/db/sqlite/app_database.dart';
import 'package:pamz_khata/core/db/sqlite/database_helper.dart';
import 'package:pamz_khata/feature/fund_ledger/data/datasources/fl_contact_hive_datasource.dart';
import 'package:pamz_khata/feature/fund_ledger/data/datasources/fl_contact_sqlite_datasource.dart';
import 'package:pamz_khata/feature/fund_ledger/data/datasources/fl_transaction_hive_datasource.dart';
import 'package:pamz_khata/feature/fund_ledger/data/datasources/fl_transaction_sqlite_datasource.dart';
import 'package:pamz_khata/feature/fund_ledger/data/models/fl_contact_model.dart';
import 'package:pamz_khata/feature/fund_ledger/data/models/fl_transaction_model.dart';
import 'package:pamz_khata/feature/fund_ledger/domain/entities/fl_transaction.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FL Hive DataSources Real Parity Tests', () {
    late Directory tempDir;
    const contactDs = FLContactHiveDataSource();
    const txnDs = FLTransactionHiveDataSource();

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('hive_fl_test_');
      await HiveRegistrar.initialize(tempDir.path);
    });

    tearDown(() async {
      await Hive.close();
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('FLContactHiveDataSource CRUD and existence checks', () async {
      const model = FLContactModel(
        id: 'c1',
        name: 'Tariq Jameel',
        mobileNumber: '9876543210',
        aadhaarNumber: '111122223333',
        project: 'Relief Fund',
        createdAt: '2026-09-21T10:00:00.000',
        updatedAt: '2026-09-21T10:00:00.000',
        isDeleted: false,
      );

      await contactDs.insert(model);
      final fetched = await contactDs.findById('c1');
      expect(fetched?.name, equals('Tariq Jameel'));
      expect(await contactDs.existsByMobile('9876543210'), isTrue);
      expect(await contactDs.existsByMobile('9876543210', excludeId: 'c1'), isFalse);
      expect(await contactDs.existsByMobile('9999999999'), isFalse);

      final updated = model.copyWith(name: 'Tariq Jameel Updated');
      await contactDs.update(updated);
      expect((await contactDs.findById('c1'))?.name, equals('Tariq Jameel Updated'));

      final all = await contactDs.getAll();
      expect(all.length, equals(1));

      await contactDs.softDelete('c1');
      expect(await contactDs.findById('c1'), isNull);
      expect((await contactDs.getAll()).isEmpty, isTrue);
    });

    test('FLTransactionHiveDataSource CRUD, filtering and aggregate totals', () async {
      const t1 = FLTransactionModel(
        id: 't1',
        contactId: 'c1',
        type: 'received',
        amount: 5000,
        txnDate: '2026-09-10',
        createdAt: '2026-09-21T10:00:00.000',
        updatedAt: '2026-09-21T10:00:00.000',
        isDeleted: false,
      );

      const t2 = FLTransactionModel(
        id: 't2',
        contactId: 'c1',
        type: 'utilized',
        amount: 2000,
        txnDate: '2026-09-12',
        title: 'Medicine',
        createdAt: '2026-09-21T10:00:00.000',
        updatedAt: '2026-09-21T10:00:00.000',
        isDeleted: false,
      );

      const t3 = FLTransactionModel(
        id: 't3',
        contactId: 'c1',
        type: 'returned',
        amount: 1500,
        txnDate: '2026-09-15',
        createdAt: '2026-09-21T10:00:00.000',
        updatedAt: '2026-09-21T10:00:00.000',
        isDeleted: false,
      );

      await txnDs.insert(t1);
      await txnDs.insert(t2);
      await txnDs.insert(t3);

      final byContact = await txnDs.getByContact('c1');
      expect(byContact.length, equals(3));

      final filtered = await txnDs.getAll(
        type: FLTransactionType.received,
        contactId: 'c1',
        fromDate: '2026-09-01',
        toDate: '2026-09-20',
      );
      expect(filtered.length, equals(1));
      expect(filtered.first.id, equals('t1'));

      final totals = await txnDs.getTotals('c1');
      expect(totals.totalReceived, equals(5000));
      expect(totals.totalUtilized, equals(2000));
      expect(totals.totalReturned, equals(1500));

      final globalTotals = await txnDs.getGlobalTotals();
      expect(globalTotals.totalReceived, equals(5000));

      await txnDs.softDelete('t3');
      final newTotals = await txnDs.getTotals('c1');
      expect(newTotals.totalReturned, equals(0));
    });
  });

  group('FL SQLite DataSources Real Parity Tests', () {
    late Database db;
    late DatabaseHelper dbHelper;
    late FLContactSqliteDataSource contactSqliteDs;
    late FLTransactionSqliteDataSource txnSqliteDs;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      await db.execute('''
        CREATE TABLE fl_contacts (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          mobile_number TEXT NOT NULL,
          aadhaar_number TEXT,
          project TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          is_deleted INTEGER NOT NULL DEFAULT 0
        )
      ''');
      await db.execute('''
        CREATE TABLE fl_transactions (
          id TEXT PRIMARY KEY,
          contact_id TEXT NOT NULL,
          type TEXT NOT NULL,
          amount REAL NOT NULL,
          txn_date TEXT NOT NULL,
          txn_time TEXT,
          payment_mode TEXT,
          payment_reference TEXT,
          title TEXT,
          description TEXT,
          note TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          is_deleted INTEGER NOT NULL DEFAULT 0
        )
      ''');

      AppDatabase.instance.overrideForTesting(db);
      dbHelper = DatabaseHelper(AppDatabase.instance);
      contactSqliteDs = FLContactSqliteDataSource(dbHelper);
      txnSqliteDs = FLTransactionSqliteDataSource(dbHelper);
    });

    tearDown(() async {
      await AppDatabase.instance.close();
    });

    test('FLContactSqliteDataSource CRUD and existsByMobile', () async {
      const model = FLContactModel(
        id: 'c1',
        name: 'Usman Ghani',
        mobileNumber: '9123456789',
        aadhaarNumber: '999988887777',
        project: 'Charity Aid',
        createdAt: '2026-09-21T10:00:00.000',
        updatedAt: '2026-09-21T10:00:00.000',
        isDeleted: false,
      );

      await contactSqliteDs.insert(model);
      final found = await contactSqliteDs.findById('c1');
      expect(found?.name, equals('Usman Ghani'));
      expect(await contactSqliteDs.existsByMobile('9123456789'), isTrue);
      expect(await contactSqliteDs.existsByMobile('9123456789', excludeId: 'c1'), isFalse);

      await contactSqliteDs.update(model.copyWith(name: 'Usman Ghani Updated'));
      expect((await contactSqliteDs.findById('c1'))?.name, equals('Usman Ghani Updated'));

      final all = await contactSqliteDs.getAll();
      expect(all.length, equals(1));

      await contactSqliteDs.softDelete('c1');
      expect(await contactSqliteDs.findById('c1'), isNull);
    });

    test('FLTransactionSqliteDataSource CRUD, queries, and aggregates', () async {
      const t1 = FLTransactionModel(
        id: 't1',
        contactId: 'c1',
        type: 'received',
        amount: 8000,
        txnDate: '2026-09-01',
        createdAt: '2026-09-21T10:00:00.000',
        updatedAt: '2026-09-21T10:00:00.000',
        isDeleted: false,
      );

      const t2 = FLTransactionModel(
        id: 't2',
        contactId: 'c1',
        type: 'utilized',
        amount: 3000,
        txnDate: '2026-09-05',
        title: 'Groceries',
        createdAt: '2026-09-21T10:00:00.000',
        updatedAt: '2026-09-21T10:00:00.000',
        isDeleted: false,
      );

      const t3 = FLTransactionModel(
        id: 't3',
        contactId: 'c1',
        type: 'returned',
        amount: 2500,
        txnDate: '2026-09-10',
        createdAt: '2026-09-21T10:00:00.000',
        updatedAt: '2026-09-21T10:00:00.000',
        isDeleted: false,
      );

      await txnSqliteDs.insert(t1);
      await txnSqliteDs.insert(t2);
      await txnSqliteDs.insert(t3);

      final byContact = await txnSqliteDs.getByContact('c1');
      expect(byContact.length, equals(3));

      final filtered = await txnSqliteDs.getAll(
        type: FLTransactionType.received,
        contactId: 'c1',
        fromDate: '2026-09-01',
        toDate: '2026-09-20',
      );
      expect(filtered.length, equals(1));

      final totals = await txnSqliteDs.getTotals('c1');
      expect(totals.totalReceived, equals(8000));
      expect(totals.totalUtilized, equals(3000));
      expect(totals.totalReturned, equals(2500));

      final globalTotals = await txnSqliteDs.getGlobalTotals();
      expect(globalTotals.totalReceived, equals(8000));

      await txnSqliteDs.softDelete('t3');
      final newTotals = await txnSqliteDs.getTotals('c1');
      expect(newTotals.totalReturned, equals(0));
    });
  });
}
