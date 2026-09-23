import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../../constants/app_constants.dart';
import 'db_factory_init.dart';

/// The single SQLite database instance for PAMZ Hisab.
/// Schema matches Backend Schema doc §1.
/// Manages onCreate, onUpgrade, and schema versioning.
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  /// Returns the open database. Initializes if first access.
  Future<Database> get database async {
    _db ??= await _initialize();
    return _db!;
  }

  /// Allows tests to inject an in-memory database instance.
  @visibleForTesting
  void overrideForTesting(Database db) {
    _db = db;
  }

  /// Closes the database and resets the singleton (for tests).
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  Future<Database> _initialize() async {
    initializeDatabaseFactory();
    final path = kIsWeb
        ? AppConstants.dbName
        : join(await getDatabasesPath(), AppConstants.dbName);
    return openDatabase(
      path,
      version: AppConstants.dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: _onConfigure,
    );
  }

  Future<void> _onConfigure(Database db) async {
    // Enable foreign key enforcement
    await db.execute('PRAGMA foreign_keys = ON;');
    // WAL mode for concurrent read/write and crash-safety (not applicable on web)
    if (!kIsWeb) {
      await db.rawQuery('PRAGMA journal_mode = WAL;');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.transaction((txn) async {
      await _createContacts(txn);
      await _createDirectUdharLoans(txn);
      await _createTradeLedgerEntries(txn);
      await _createRepayments(txn);
      await _createCategories(txn);
      await _createAccounts(txn);
      await _createFamilyTransactions(txn);
      await _createBudgets(txn);
      await _createPaymentModes(txn);
      await _createMonthlySummary(txn);
      await _createAuditLog(txn);
      await _createFLContacts(txn);
      await _createFLTransactions(txn);
      await _createFamilyUtilizations(txn);
      await _seedPaymentModes(txn);
      await _seedCategories(txn);
      await _seedAccounts(txn);
    });
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // 1. Add missing budget columns if not already present on existing DBs
      final tableInfo = await db.rawQuery('PRAGMA table_info(budgets)');
      final columns = tableInfo.map((r) => r['name'] as String).toSet();

      if (!columns.contains('alert_threshold_percent')) {
        await db.execute(
            'ALTER TABLE budgets ADD COLUMN alert_threshold_percent REAL NOT NULL DEFAULT 80.0');
      }
      if (!columns.contains('created_at')) {
        await db.execute('ALTER TABLE budgets ADD COLUMN created_at TEXT');
      }
      if (!columns.contains('updated_at')) {
        await db.execute('ALTER TABLE budgets ADD COLUMN updated_at TEXT');
      }
      if (!columns.contains('is_deleted')) {
        await db.execute(
            'ALTER TABLE budgets ADD COLUMN is_deleted INTEGER NOT NULL DEFAULT 0');
      }

      // 2. Re-create unique index with WHERE is_deleted = 0 for soft-delete safety
      await db.execute('DROP INDEX IF EXISTS idx_budget_category_month');
      await db.execute('''
        CREATE UNIQUE INDEX idx_budget_category_month
          ON budgets(category_id, month) WHERE is_deleted = 0
      ''');
    }

    if (oldVersion < 3) {
      // Add Fund Ledger tables — new feature, no destructive migration of old data
      await db.transaction((txn) async {
        await _createFLContacts(txn);
        await _createFLTransactions(txn);
      });
    }

    if (oldVersion < 4) {
      // Add Family Utilizations table — new feature, non-destructive migration
      await db.transaction((txn) async {
        await _createFamilyUtilizations(txn);
      });
    }

    if (oldVersion < 5) {
      // Add payment_mode and payment_reference columns to family_utilizations
      final tableInfo =
          await db.rawQuery('PRAGMA table_info(family_utilizations)');
      final columns = tableInfo.map((r) => r['name'] as String).toSet();
      if (!columns.contains('payment_mode')) {
        await db.execute(
            'ALTER TABLE family_utilizations ADD COLUMN payment_mode TEXT');
      }
      if (!columns.contains('payment_reference')) {
        await db.execute(
            'ALTER TABLE family_utilizations ADD COLUMN payment_reference TEXT');
      }
    }
  }

  // ─────────────────────────────────────────────
  // Table Creation (Schema §1.1–1.11)
  // ─────────────────────────────────────────────

  Future<void> _createContacts(Transaction txn) async {
    await txn.execute('''
      CREATE TABLE contacts (
        id                    TEXT PRIMARY KEY,
        type                  TEXT NOT NULL CHECK(type IN ('buyer','supplier')),
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
      )
    ''');
    // Unique mobile only among non-deleted contacts
    await txn.execute('''
      CREATE UNIQUE INDEX idx_contacts_mobile
        ON contacts(mobile_number) WHERE is_deleted = 0
    ''');
    await txn.execute('''
      CREATE INDEX idx_contacts_type ON contacts(type)
    ''');
  }

  Future<void> _createDirectUdharLoans(Transaction txn) async {
    await txn.execute('''
      CREATE TABLE direct_udhar_loans (
        id                    TEXT PRIMARY KEY,
        contact_id            TEXT NOT NULL REFERENCES contacts(id),
        direction             TEXT NOT NULL CHECK(direction IN ('lent','borrowed')),
        principal_amount      REAL NOT NULL,
        interest_type         TEXT NOT NULL CHECK(interest_type IN ('simple','interest_free')),
        interest_rate_percent REAL,
        due_date              TEXT,
        memo                  TEXT,
        status                TEXT NOT NULL DEFAULT 'open'
                                CHECK(status IN ('open','partially_paid','closed')),
        outstanding_balance   REAL NOT NULL,
        created_at            TEXT NOT NULL,
        updated_at            TEXT NOT NULL,
        is_deleted            INTEGER DEFAULT 0
      )
    ''');
    await txn.execute(
        'CREATE INDEX idx_udhar_contact ON direct_udhar_loans(contact_id)');
    await txn.execute(
        'CREATE INDEX idx_udhar_due_date ON direct_udhar_loans(due_date)');
    await txn.execute(
        'CREATE INDEX idx_udhar_status ON direct_udhar_loans(status)');
  }

  Future<void> _createTradeLedgerEntries(Transaction txn) async {
    await txn.execute('''
      CREATE TABLE trade_ledger_entries (
        id          TEXT PRIMARY KEY,
        contact_id  TEXT NOT NULL REFERENCES contacts(id),
        entry_type  TEXT NOT NULL CHECK(entry_type IN ('credit','debit')),
        amount      REAL NOT NULL,
        description TEXT,
        entry_date  TEXT NOT NULL,
        created_at  TEXT NOT NULL,
        updated_at  TEXT NOT NULL,
        is_deleted  INTEGER DEFAULT 0
      )
    ''');
    await txn.execute('''
      CREATE INDEX idx_trade_contact_date
        ON trade_ledger_entries(contact_id, entry_date)
    ''');
  }

  Future<void> _createRepayments(Transaction txn) async {
    await txn.execute('''
      CREATE TABLE repayments (
        id           TEXT PRIMARY KEY,
        source_type  TEXT NOT NULL CHECK(source_type IN ('direct_udhar','trade_ledger')),
        source_id    TEXT NOT NULL,
        amount       REAL NOT NULL,
        payment_mode TEXT REFERENCES payment_modes(code),
        paid_at      TEXT NOT NULL,
        memo         TEXT,
        created_at   TEXT NOT NULL,
        is_deleted   INTEGER DEFAULT 0
      )
    ''');
    await txn.execute('''
      CREATE INDEX idx_repayments_source
        ON repayments(source_type, source_id)
    ''');
    await txn.execute(
        'CREATE INDEX idx_repayments_paid_at ON repayments(paid_at)');
  }

  Future<void> _createCategories(Transaction txn) async {
    await txn.execute('''
      CREATE TABLE categories (
        id                 TEXT PRIMARY KEY,
        domain             TEXT NOT NULL CHECK(domain IN ('income','expense')),
        name               TEXT NOT NULL,
        parent_category_id TEXT REFERENCES categories(id),
        icon_key           TEXT,
        color_hex          TEXT,
        is_system_preset   INTEGER DEFAULT 0,
        sort_order         INTEGER DEFAULT 0,
        is_deleted         INTEGER DEFAULT 0
      )
    ''');
  }

  Future<void> _createAccounts(Transaction txn) async {
    await txn.execute('''
      CREATE TABLE accounts (
        id         TEXT PRIMARY KEY,
        name       TEXT NOT NULL,
        type       TEXT NOT NULL CHECK(type IN ('cash','bank')),
        is_deleted INTEGER DEFAULT 0
      )
    ''');
  }

  Future<void> _createFamilyTransactions(Transaction txn) async {
    await txn.execute('''
      CREATE TABLE family_transactions (
        id                 TEXT PRIMARY KEY,
        type               TEXT NOT NULL CHECK(type IN ('income','expense')),
        amount             REAL NOT NULL,
        category_id        TEXT NOT NULL REFERENCES categories(id),
        account_id         TEXT REFERENCES accounts(id),
        source_tag         TEXT,
        receipt_photo_path TEXT,
        transaction_date   TEXT NOT NULL,
        notes              TEXT,
        created_at         TEXT NOT NULL,
        updated_at         TEXT NOT NULL,
        is_deleted         INTEGER DEFAULT 0
      )
    ''');
    await txn.execute('''
      CREATE INDEX idx_family_txn_date
        ON family_transactions(transaction_date)
    ''');
    await txn.execute('''
      CREATE INDEX idx_family_txn_category
        ON family_transactions(category_id)
    ''');
  }

  Future<void> _createBudgets(Transaction txn) async {
    await txn.execute('''
      CREATE TABLE budgets (
        id                      TEXT PRIMARY KEY,
        category_id             TEXT NOT NULL REFERENCES categories(id),
        month                   TEXT NOT NULL,
        limit_amount            REAL NOT NULL,
        alert_threshold_percent REAL NOT NULL DEFAULT 80.0,
        created_at              TEXT NOT NULL,
        updated_at              TEXT NOT NULL,
        is_deleted              INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await txn.execute('''
      CREATE UNIQUE INDEX idx_budget_category_month
        ON budgets(category_id, month) WHERE is_deleted = 0
    ''');
  }

  Future<void> _createPaymentModes(Transaction txn) async {
    await txn.execute('''
      CREATE TABLE payment_modes (
        code      TEXT PRIMARY KEY,
        label     TEXT NOT NULL,
        is_active INTEGER DEFAULT 1
      )
    ''');
  }

  Future<void> _createMonthlySummary(Transaction txn) async {
    await txn.execute('''
      CREATE TABLE monthly_summary (
        id                   TEXT PRIMARY KEY,
        month                TEXT NOT NULL,
        category_id          TEXT REFERENCES categories(id),
        total_income         REAL DEFAULT 0,
        total_expense        REAL DEFAULT 0,
        total_udhar_given    REAL DEFAULT 0,
        total_udhar_received REAL DEFAULT 0
      )
    ''');
    await txn.execute('''
      CREATE UNIQUE INDEX idx_summary_month_category
        ON monthly_summary(month, category_id)
    ''');
  }

  Future<void> _createAuditLog(Transaction txn) async {
    await txn.execute('''
      CREATE TABLE audit_log (
        id                  TEXT PRIMARY KEY,
        entity_type         TEXT NOT NULL,
        entity_id           TEXT NOT NULL,
        action              TEXT NOT NULL CHECK(action IN ('create','update','delete')),
        changed_fields_json TEXT,
        performed_at        TEXT NOT NULL
      )
    ''');
    await txn.execute('''
      CREATE INDEX idx_audit_entity ON audit_log(entity_type, entity_id)
    ''');
  }


  // ─────────────────────────────────────────────
  // Fund Ledger Tables (Schema §2.1–2.2)
  // ─────────────────────────────────────────────

  Future<void> _createFLContacts(Transaction txn) async {
    await txn.execute('''
      CREATE TABLE IF NOT EXISTS fl_contacts (
        id             TEXT PRIMARY KEY,
        name           TEXT NOT NULL,
        mobile_number  TEXT NOT NULL,
        aadhaar_number TEXT,
        project        TEXT,
        created_at     TEXT NOT NULL,
        updated_at     TEXT NOT NULL,
        is_deleted     INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await txn.execute('''
      CREATE INDEX IF NOT EXISTS idx_fl_contacts_name
        ON fl_contacts(name)
    ''');
  }

  Future<void> _createFLTransactions(Transaction txn) async {
    await txn.execute('''
      CREATE TABLE IF NOT EXISTS fl_transactions (
        id                TEXT PRIMARY KEY,
        contact_id        TEXT NOT NULL REFERENCES fl_contacts(id),
        type              TEXT NOT NULL
                            CHECK(type IN ('received','utilized','returned')),
        amount            REAL NOT NULL,
        txn_date          TEXT NOT NULL,
        txn_time          TEXT,
        payment_mode      TEXT,
        payment_reference TEXT,
        title             TEXT,
        description       TEXT,
        note              TEXT,
        created_at        TEXT NOT NULL,
        updated_at        TEXT NOT NULL,
        is_deleted        INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await txn.execute('''
      CREATE INDEX IF NOT EXISTS idx_fl_txn_contact_date
        ON fl_transactions(contact_id, txn_date DESC)
    ''');
    await txn.execute('''
      CREATE INDEX IF NOT EXISTS idx_fl_txn_type
        ON fl_transactions(type)
    ''');
  }

  // ─────────────────────────────────────────────
  // Family Utilization Tables
  // ─────────────────────────────────────────────

  Future<void> _createFamilyUtilizations(Transaction txn) async {
    await txn.execute('''
      CREATE TABLE IF NOT EXISTS family_utilizations (
        id                TEXT PRIMARY KEY,
        amount            REAL NOT NULL,
        category          TEXT NOT NULL,
        title             TEXT NOT NULL,
        paid_to           TEXT,
        mobile_number     TEXT,
        description       TEXT,
        transaction_date  TEXT NOT NULL,
        payment_mode      TEXT,
        payment_reference TEXT,
        created_at        TEXT NOT NULL,
        updated_at        TEXT NOT NULL,
        is_deleted        INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await txn.execute('''
      CREATE INDEX IF NOT EXISTS idx_family_util_date
        ON family_utilizations(transaction_date DESC)
    ''');
    await txn.execute('''
      CREATE INDEX IF NOT EXISTS idx_family_util_category
        ON family_utilizations(category)
    ''');
  }

  // ─────────────────────────────────────────────
  // Seed Data (Kishanganj Presets)
  // ─────────────────────────────────────────────


  Future<void> _seedPaymentModes(Transaction txn) async {
    for (final mode in AppConstants.defaultPaymentModes) {
      await txn.insert('payment_modes', mode,
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<void> _seedCategories(Transaction txn) async {
    final incomePresets = [
      ('cat_sal', 'income', 'Salary', '💼', '#4CAF50'),
      ('cat_agri', 'income', 'Agricultural Yield', '🌾', '#8BC34A'),
      ('cat_biz', 'income', 'Business/Shop Earnings', '🏪', '#2196F3'),
      ('cat_rent', 'income', 'Property Rent', '🏠', '#9C27B0'),
      ('cat_remit', 'income', 'Remittances', '💸', '#FF9800'),
      ('cat_int', 'income', 'Loan Interest Income', '📈', '#00BCD4'),
    ];
    final expensePresets = [
      ('cat_groc', 'expense', 'Groceries & Ration', '🛒', '#F44336'),
      ('cat_agri_in', 'expense', 'Agriculture Inputs', '🌱', '#4CAF50'),
      ('cat_edu', 'expense', 'Education & Tuition', '📚', '#3F51B5'),
      ('cat_health', 'expense', 'Healthcare', '🏥', '#E91E63'),
      ('cat_util', 'expense', 'Utilities', '⚡', '#FF5722'),
      ('cat_trans', 'expense', 'Transportation', '🚗', '#607D8B'),
      ('cat_debt', 'expense', 'Debt Repayments', '💳', '#795548'),
    ];

    for (final (id, domain, name, icon, color)
        in [...incomePresets, ...expensePresets]) {
      await txn.insert(
        'categories',
        {
          'id': id,
          'domain': domain,
          'name': name,
          'icon_key': icon,
          'color_hex': color,
          'is_system_preset': 1,
          'sort_order': 0,
          'is_deleted': 0,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  Future<void> _seedAccounts(Transaction txn) async {
    final accounts = [
      {'id': 'acc_cash', 'name': 'Cash', 'type': 'cash', 'is_deleted': 0},
      {'id': 'acc_bank', 'name': 'Bank Account', 'type': 'bank', 'is_deleted': 0},
    ];
    for (final acc in accounts) {
      await txn.insert('accounts', acc,
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }
}
