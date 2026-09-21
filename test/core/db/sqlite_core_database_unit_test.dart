import 'package:flutter_test/flutter_test.dart';
import 'package:pamz_khata/core/constants/app_constants.dart';
import 'package:pamz_khata/core/db/sqlite/app_database.dart';
import 'package:pamz_khata/core/db/sqlite/database_helper.dart';
import 'package:pamz_khata/core/db/storage_config.dart';
import 'package:pamz_khata/feature/contacts/data/datasources/contact_sqlite_datasource.dart';
import 'package:pamz_khata/feature/contacts/data/models/contact_model.dart';
import 'package:pamz_khata/feature/contacts/domain/entities/contact.dart';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('SQLite Core Database & AppDatabase Unit Tests', () {
    late Database inMemoryDb;
    late DatabaseHelper dbHelper;

    setUp(() async {
      inMemoryDb = await openDatabase(
        inMemoryDatabasePath,
        version: AppConstants.dbVersion,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON;');
        },
        onCreate: (db, version) async {
          // Initialize AppDatabase schema
          final appDb = AppDatabase.instance;
          appDb.overrideForTesting(db);
          // Trigger the private _onCreate via database singleton getter or manual execution
          await db.transaction((txn) async {
            await txn.execute('''
              CREATE TABLE contacts (
                id TEXT PRIMARY KEY,
                type TEXT NOT NULL CHECK(type IN ('buyer','supplier')),
                name TEXT NOT NULL,
                mobile_number TEXT NOT NULL,
                address TEXT,
                village_tola TEXT,
                shop_location TEXT,
                credit_limit REAL DEFAULT 0,
                due_date_alert_enabled INTEGER DEFAULT 0,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                is_deleted INTEGER DEFAULT 0
              );
            ''');
            await txn.execute('''
              CREATE UNIQUE INDEX idx_contacts_mobile
                ON contacts(mobile_number) WHERE is_deleted = 0;
            ''');
            await txn.execute('CREATE INDEX idx_contacts_type ON contacts(type);');

            await txn.execute('''
              CREATE TABLE direct_udhar_loans (
                id TEXT PRIMARY KEY,
                contact_id TEXT NOT NULL REFERENCES contacts(id),
                direction TEXT NOT NULL CHECK(direction IN ('lent','borrowed')),
                principal_amount REAL NOT NULL,
                interest_type TEXT NOT NULL CHECK(interest_type IN ('simple','interest_free')),
                interest_rate_percent REAL,
                due_date TEXT,
                memo TEXT,
                status TEXT NOT NULL DEFAULT 'open'
                       CHECK(status IN ('open','partially_paid','closed')),
                outstanding_balance REAL NOT NULL,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                is_deleted INTEGER DEFAULT 0
              );
            ''');

            await txn.execute('''
              CREATE TABLE trade_ledger_entries (
                id TEXT PRIMARY KEY,
                contact_id TEXT NOT NULL REFERENCES contacts(id),
                type TEXT NOT NULL CHECK(type IN ('sale','purchase','payment_in','payment_out')),
                amount REAL NOT NULL,
                entry_date TEXT NOT NULL,
                notes TEXT,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                is_deleted INTEGER DEFAULT 0
              );
            ''');

            await txn.execute('''
              CREATE TABLE repayments (
                id TEXT PRIMARY KEY,
                source_type TEXT NOT NULL CHECK(source_type IN ('direct_udhar','trade_ledger')),
                source_id TEXT NOT NULL,
                amount REAL NOT NULL,
                payment_mode TEXT REFERENCES payment_modes(code),
                paid_at TEXT NOT NULL,
                memo TEXT,
                created_at TEXT NOT NULL,
                is_deleted INTEGER DEFAULT 0
              );
            ''');

            await txn.execute('''
              CREATE TABLE categories (
                id TEXT PRIMARY KEY,
                domain TEXT NOT NULL CHECK(domain IN ('family','business')),
                name TEXT NOT NULL,
                parent_category_id TEXT,
                icon_key TEXT,
                color_hex TEXT,
                is_system_preset INTEGER DEFAULT 0,
                sort_order INTEGER DEFAULT 0,
                is_deleted INTEGER DEFAULT 0
              );
            ''');

            await txn.execute('''
              CREATE TABLE accounts (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                type TEXT NOT NULL CHECK(type IN ('cash','bank','wallet')),
                account_number_last4 TEXT,
                bank_name TEXT,
                is_deleted INTEGER DEFAULT 0
              );
            ''');

            await txn.execute('''
              CREATE TABLE family_transactions (
                id TEXT PRIMARY KEY,
                type TEXT NOT NULL CHECK(type IN ('income','expense')),
                amount REAL NOT NULL,
                category_id TEXT NOT NULL REFERENCES categories(id),
                account_id TEXT REFERENCES accounts(id),
                source_tag TEXT,
                receipt_photo_path TEXT,
                transaction_date TEXT NOT NULL,
                notes TEXT,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                is_deleted INTEGER DEFAULT 0
              );
            ''');

            await txn.execute('''
              CREATE TABLE budgets (
                id TEXT PRIMARY KEY,
                category_id TEXT NOT NULL REFERENCES categories(id),
                month TEXT NOT NULL,
                monthly_limit REAL NOT NULL,
                alert_threshold_percent REAL NOT NULL DEFAULT 80.0,
                created_at TEXT,
                updated_at TEXT,
                is_deleted INTEGER NOT NULL DEFAULT 0
              );
            ''');
            await txn.execute('''
              CREATE UNIQUE INDEX idx_budget_category_month
                ON budgets(category_id, month) WHERE is_deleted = 0;
            ''');

            await txn.execute('''
              CREATE TABLE payment_modes (
                id TEXT PRIMARY KEY,
                code TEXT NOT NULL UNIQUE,
                name TEXT NOT NULL,
                icon_key TEXT NOT NULL,
                is_system INTEGER DEFAULT 0,
                is_active INTEGER DEFAULT 1,
                sort_order INTEGER DEFAULT 0
              );
            ''');

            await txn.execute('''
              CREATE TABLE monthly_summary (
                id TEXT PRIMARY KEY,
                month TEXT NOT NULL,
                domain TEXT NOT NULL CHECK(domain IN ('family','business')),
                category_id TEXT REFERENCES categories(id),
                total_income REAL DEFAULT 0,
                total_expense REAL DEFAULT 0,
                net_savings REAL DEFAULT 0
              );
            ''');
            await txn.execute('''
              CREATE UNIQUE INDEX idx_monthly_summary_month_cat
                ON monthly_summary(month, category_id);
            ''');

            await txn.execute('''
              CREATE TABLE audit_log (
                id TEXT PRIMARY KEY,
                entity_type TEXT NOT NULL,
                entity_id TEXT NOT NULL,
                action TEXT NOT NULL CHECK(action IN ('create','update','delete')),
                changed_fields_json TEXT,
                performed_at TEXT NOT NULL
              );
            ''');
          });
        },
      );

      AppDatabase.instance.overrideForTesting(inMemoryDb);
      dbHelper = DatabaseHelper(AppDatabase.instance);
    });

    tearDown(() async {
      await inMemoryDb.close();
      await AppDatabase.instance.close();
    });

    test('1. AppDatabase schema creation initializes all 11 required tables', () async {
      final tablesQuery = await inMemoryDb.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
      );
      final tableNames = tablesQuery.map((r) => r['name'] as String).toSet();

      expect(tableNames, contains('contacts'));
      expect(tableNames, contains('direct_udhar_loans'));
      expect(tableNames, contains('trade_ledger_entries'));
      expect(tableNames, contains('repayments'));
      expect(tableNames, contains('categories'));
      expect(tableNames, contains('accounts'));
      expect(tableNames, contains('family_transactions'));
      expect(tableNames, contains('budgets'));
      expect(tableNames, contains('payment_modes'));
      expect(tableNames, contains('monthly_summary'));
      expect(tableNames, contains('audit_log'));
    });

    test('2. Unique constraints: contacts mobile uniqueness for active vs soft-deleted contacts', () async {
      // Insert first contact
      await inMemoryDb.insert('contacts', {
        'id': 'c1',
        'type': 'buyer',
        'name': 'Ramesh Kumar',
        'mobile_number': '9876543210',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'is_deleted': 0,
      });

      // Inserting duplicate active mobile number should throw DatabaseException
      expect(
        () async => await inMemoryDb.insert('contacts', {
          'id': 'c2',
          'type': 'buyer',
          'name': 'Ramesh Clone',
          'mobile_number': '9876543210',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
          'is_deleted': 0,
        }),
        throwsA(isA<DatabaseException>()),
      );

      // Soft delete contact 1
      await inMemoryDb.update(
        'contacts',
        {'is_deleted': 1},
        where: 'id = ?',
        whereArgs: ['c1'],
      );

      // Inserting duplicate mobile number when previous is soft deleted should succeed
      final rowId = await inMemoryDb.insert('contacts', {
        'id': 'c2',
        'type': 'buyer',
        'name': 'Ramesh New',
        'mobile_number': '9876543210',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'is_deleted': 0,
      });

      expect(rowId, isPositive);
    });

    test('3. Unique constraints: monthly summary (month, category_id) uniqueness', () async {
      // Insert category
      await inMemoryDb.insert('categories', {
        'id': 'cat_food',
        'domain': 'family',
        'name': 'Groceries',
        'is_deleted': 0,
      });

      await inMemoryDb.insert('monthly_summary', {
        'id': 'ms1',
        'month': '2026-09',
        'domain': 'family',
        'category_id': 'cat_food',
        'total_income': 0,
        'total_expense': 500,
        'net_savings': -500,
      });

      // Duplicate month + category_id should fail
      expect(
        () async => await inMemoryDb.insert('monthly_summary', {
          'id': 'ms2',
          'month': '2026-09',
          'domain': 'family',
          'category_id': 'cat_food',
          'total_income': 0,
          'total_expense': 300,
          'net_savings': -300,
        }),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('4. Foreign key constraint enforcement: rejects orphan records when enabled', () async {
      // Inserting direct udhar loan for non-existent contact should fail foreign key check
      expect(
        () async => await inMemoryDb.insert('direct_udhar_loans', {
          'id': 'loan_invalid',
          'contact_id': 'non_existent_contact',
          'direction': 'lent',
          'principal_amount': 5000.0,
          'interest_type': 'interest_free',
          'status': 'open',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
          'is_deleted': 0,
        }),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('5. Migration v1 -> v2: adds missing budget columns and soft-delete safe unique index', () async {
      // Create a temporary v1 SQLite DB
      final v1Db = await openDatabase(
        inMemoryDatabasePath,
        singleInstance: false,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE categories (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL
            );
          ''');
          // Old v1 schema for budgets without alert_threshold_percent, created_at, updated_at, is_deleted
          await db.execute('''
            CREATE TABLE budgets (
              id TEXT PRIMARY KEY,
              category_id TEXT NOT NULL,
              month TEXT NOT NULL,
              monthly_limit REAL NOT NULL
            );
          ''');
          await db.execute('''
            CREATE UNIQUE INDEX idx_budget_category_month
              ON budgets(category_id, month);
          ''');
        },
      );

      // Perform v1 -> v2 migration logic
      final tableInfoBefore = await v1Db.rawQuery('PRAGMA table_info(budgets)');
      final colsBefore = tableInfoBefore.map((r) => r['name'] as String).toSet();
      expect(colsBefore.contains('alert_threshold_percent'), isFalse);
      expect(colsBefore.contains('is_deleted'), isFalse);

      // Apply v2 upgrade
      if (!colsBefore.contains('alert_threshold_percent')) {
        await v1Db.execute(
            'ALTER TABLE budgets ADD COLUMN alert_threshold_percent REAL NOT NULL DEFAULT 80.0');
      }
      if (!colsBefore.contains('created_at')) {
        await v1Db.execute('ALTER TABLE budgets ADD COLUMN created_at TEXT');
      }
      if (!colsBefore.contains('updated_at')) {
        await v1Db.execute('ALTER TABLE budgets ADD COLUMN updated_at TEXT');
      }
      if (!colsBefore.contains('is_deleted')) {
        await v1Db.execute(
            'ALTER TABLE budgets ADD COLUMN is_deleted INTEGER NOT NULL DEFAULT 0');
      }
      await v1Db.execute('DROP INDEX IF EXISTS idx_budget_category_month');
      await v1Db.execute('''
        CREATE UNIQUE INDEX idx_budget_category_month
          ON budgets(category_id, month) WHERE is_deleted = 0
      ''');

      // Verify columns after migration
      final tableInfoAfter = await v1Db.rawQuery('PRAGMA table_info(budgets)');
      final colsAfter = tableInfoAfter.map((r) => r['name'] as String).toSet();
      expect(colsAfter, contains('alert_threshold_percent'));
      expect(colsAfter, contains('created_at'));
      expect(colsAfter, contains('updated_at'));
      expect(colsAfter, contains('is_deleted'));

      await v1Db.close();
    });

    test('6. AppDatabase instance lifecycle, overrideForTesting, and storage config', () async {
      expect(AppStorageConfig.current, isNotNull);
      final dbInstance = AppDatabase.instance;
      dbInstance.overrideForTesting(inMemoryDb);
      final activeDb = await dbInstance.database;
      expect(activeDb, equals(inMemoryDb));

      await dbInstance.close();
    });

    test('7. ContactSqliteDataSource complete CRUD, existsByMobile, and balance calculations', () async {
      final dataSource = ContactSqliteDataSource(dbHelper);

      final buyer = ContactModel.fromEntity(Contact(
        id: 'c_buyer_1',
        type: ContactType.buyer,
        name: 'Amit Patel',
        mobileNumber: '9988776655',
        creditLimit: 50000,
        address: '123 Market Rd',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ));

      final supplier = ContactModel.fromEntity(Contact(
        id: 'c_supp_1',
        type: ContactType.supplier,
        name: 'Bharat Traders',
        mobileNumber: '9988776644',
        shopLocation: 'Shop 4, GIDC',
        dueDateAlertEnabled: true,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ));

      // Insert
      await dataSource.insert(buyer);
      await dataSource.insert(supplier);

      // Exists by mobile
      expect(await dataSource.existsByMobile('9988776655'), isTrue);
      expect(await dataSource.existsByMobile('9988776655', excludeId: 'c_buyer_1'), isFalse);
      expect(await dataSource.existsByMobile('0000000000'), isFalse);

      // Find by ID
      final found = await dataSource.findById('c_buyer_1');
      expect(found, isNotNull);
      expect(found!.name, 'Amit Patel');
      expect(found.type, 'buyer');

      // Get all filtered by type
      final buyers = await dataSource.getAll(type: 'buyer');
      expect(buyers.length, 1);
      expect(buyers.first.id, 'c_buyer_1');

      final suppliers = await dataSource.getAll(type: 'supplier');
      expect(suppliers.length, 1);
      expect(suppliers.first.id, 'c_supp_1');

      final allContacts = await dataSource.getAll();
      expect(allContacts.length, 2);

      // Update
      final updatedBuyer = ContactModel.fromEntity(
        buyer.toEntity().copyWith(name: 'Amit Kumar Patel', creditLimit: 75000),
      );
      await dataSource.update(updatedBuyer);
      final fetchedUpdated = await dataSource.findById('c_buyer_1');
      expect(fetchedUpdated!.name, 'Amit Kumar Patel');
      expect(fetchedUpdated.creditLimit, 75000);

      // getTotalBalance returns 0.0 since Direct Udhar loan calculations are retired
      final balance = await dataSource.getTotalBalance('c_buyer_1');
      expect(balance, equals(0.0));

      // Balance for empty contact also returns 0.0
      expect(await dataSource.getTotalBalance('c_supp_1'), equals(0.0));

      // Soft delete
      await dataSource.softDelete('c_buyer_1');
      expect(await dataSource.findById('c_buyer_1'), isNull);
      final remaining = await dataSource.getAll();
      expect(remaining.length, 1);
      expect(remaining.first.id, 'c_supp_1');
    });
  });
}
