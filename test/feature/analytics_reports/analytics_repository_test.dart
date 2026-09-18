import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pamz_khata/core/db/hive/hive_registrar.dart';
import 'package:pamz_khata/core/db/sqlite/app_database.dart';
import 'package:pamz_khata/core/db/sqlite/database_helper.dart';
import 'package:pamz_khata/core/db/storage_config.dart';
import 'package:pamz_khata/feature/analytics_reports/data/models/analytics_models.dart';
import 'package:pamz_khata/feature/analytics_reports/data/repositories/analytics_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('LocalAnalyticsRepositoryImpl Storage Parity Tests', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('analytics_test_');
      await HiveRegistrar.initialize(tempDir.path);
    });

    tearDown(() async {
      await Hive.close();
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
      await AppDatabase.instance.close();
      AppStorageConfig.current = StorageType.hive;
    });

    test('Hive mode (StorageType.hive) aggregates data from Hive boxes', () async {
      AppStorageConfig.current = StorageType.hive;
      const repo = LocalAnalyticsRepositoryImpl();
      final now = DateTime.now();

      // Seed transaction data into Hive in the current month
      await HiveRegistrar.familyTransactionsBox.put('txn-1', {
        'id': 'txn-1',
        'transaction_date': DateTime(now.year, now.month, 10).toIso8601String(),
        'amount': 150000.0,
        'type': 'income',
        'category_id': 'cat-1',
        'is_deleted': 0,
      });

      await HiveRegistrar.familyTransactionsBox.put('txn-2', {
        'id': 'txn-2',
        'transaction_date': DateTime(now.year, now.month, 15).toIso8601String(),
        'amount': 45000.0,
        'type': 'expense',
        'category_id': 'cat-2',
        'is_deleted': 0,
      });

      await HiveRegistrar.categoriesBox.put('cat-1', {
        'id': 'cat-1',
        'name': 'Agriculture Sales',
        'icon_key': '🌾',
        'color_hex': '#4CAF50',
      });

      await HiveRegistrar.categoriesBox.put('cat-2', {
        'id': 'cat-2',
        'name': 'Seeds & Fertilizer',
        'icon_key': '🌱',
        'color_hex': '#FF9800',
      });

      await HiveRegistrar.directUdharBox.put('loan-1', {
        'id': 'loan-1',
        'created_at': DateTime(now.year, now.month, 5).toIso8601String(),
        'principal_amount': 50000.0,
        'direction': 'lent',
        'is_deleted': 0,
      });

      await HiveRegistrar.repaymentsBox.put('rep-1', {
        'id': 'rep-1',
        'source_id': 'loan-1',
        'paid_at': DateTime(now.year, now.month, 18).toIso8601String(),
        'amount': 15000.0,
        'is_deleted': 0,
      });

      final result = await repo.getReportData(
        horizon: AnalyticsTimeHorizon.monthly,
        fiscalYearStart: 'april',
      );

      expect(result.isRight(), isTrue);
      result.match(
        (l) => fail('Should have succeeded: ${l.message}'),
        (report) {
          expect(report.horizon, AnalyticsTimeHorizon.monthly);
          expect(report.summary.totalIncome, 150000.0);
          expect(report.summary.totalExpense, 45000.0);
          expect(report.summary.netSavings, 105000.0);
          expect(report.summary.totalUdharLent, 50000.0);
          expect(report.summary.totalUdharCollected, 15000.0);
          expect(report.summary.netUdharReceivable, 35000.0);

          expect(report.categoryBreakdown.length, 1);
          expect(report.categoryBreakdown.first.categoryName, 'Seeds & Fertilizer');
          expect(report.categoryBreakdown.first.amount, 45000.0);

          expect(report.quarterlyBreakdown.length, 4);
          expect(report.tenYearComparison.length, 10);
        },
      );
    });

    test('SQLite mode (StorageType.sqlite) aggregates data from SQLite tables and ignores Hive', () async {
      AppStorageConfig.current = StorageType.sqlite;
      final now = DateTime.now();

      final sqliteDb = await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE categories (
                id TEXT PRIMARY KEY,
                domain TEXT NOT NULL,
                name TEXT NOT NULL,
                parent_category_id TEXT,
                icon_key TEXT,
                color_hex TEXT,
                is_system_preset INTEGER DEFAULT 0,
                sort_order INTEGER DEFAULT 0,
                is_deleted INTEGER DEFAULT 0
              );
            ''');
            await db.execute('''
              CREATE TABLE family_transactions (
                id TEXT PRIMARY KEY,
                type TEXT NOT NULL,
                amount REAL NOT NULL,
                category_id TEXT NOT NULL,
                account_id TEXT,
                source_tag TEXT,
                receipt_photo_path TEXT,
                transaction_date TEXT NOT NULL,
                notes TEXT,
                created_at TEXT,
                updated_at TEXT,
                is_deleted INTEGER DEFAULT 0
              );
            ''');
            await db.execute('''
              CREATE TABLE direct_udhar_loans (
                id TEXT PRIMARY KEY,
                contact_id TEXT,
                direction TEXT NOT NULL,
                principal_amount REAL NOT NULL,
                interest_type TEXT,
                interest_rate_percent REAL,
                due_date TEXT,
                memo TEXT,
                status TEXT,
                outstanding_balance REAL,
                created_at TEXT NOT NULL,
                updated_at TEXT,
                is_deleted INTEGER DEFAULT 0
              );
            ''');
            await db.execute('''
              CREATE TABLE repayments (
                id TEXT PRIMARY KEY,
                source_type TEXT,
                source_id TEXT NOT NULL,
                amount REAL NOT NULL,
                payment_mode TEXT,
                paid_at TEXT NOT NULL,
                memo TEXT,
                created_at TEXT,
                is_deleted INTEGER DEFAULT 0
              );
            ''');
          },
        ),
      );

      AppDatabase.instance.overrideForTesting(sqliteDb);
      final helper = DatabaseHelper(AppDatabase.instance);
      final repo = LocalAnalyticsRepositoryImpl(helper);

      // Seed SQLite with unique data
      await sqliteDb.insert('categories', {
        'id': 'cat-sql-1',
        'domain': 'income',
        'name': 'Business Income',
        'icon_key': '🏪',
        'color_hex': '#2196F3',
        'is_deleted': 0,
      });

      await sqliteDb.insert('categories', {
        'id': 'cat-sql-2',
        'domain': 'expense',
        'name': 'Shop Utilities',
        'icon_key': '⚡',
        'color_hex': '#FF5722',
        'is_deleted': 0,
      });

      await sqliteDb.insert('family_transactions', {
        'id': 'sql-txn-1',
        'type': 'income',
        'amount': 200000.0,
        'category_id': 'cat-sql-1',
        'transaction_date': DateTime(now.year, now.month, 5).toIso8601String(),
        'is_deleted': 0,
      });

      await sqliteDb.insert('family_transactions', {
        'id': 'sql-txn-2',
        'type': 'expense',
        'amount': 60000.0,
        'category_id': 'cat-sql-2',
        'transaction_date': DateTime(now.year, now.month, 12).toIso8601String(),
        'is_deleted': 0,
      });

      await sqliteDb.insert('direct_udhar_loans', {
        'id': 'sql-loan-1',
        'direction': 'lent',
        'principal_amount': 80000.0,
        'created_at': DateTime(now.year, now.month, 2).toIso8601String(),
        'is_deleted': 0,
      });

      await sqliteDb.insert('repayments', {
        'id': 'sql-rep-1',
        'source_id': 'sql-loan-1',
        'amount': 30000.0,
        'paid_at': DateTime(now.year, now.month, 20).toIso8601String(),
        'is_deleted': 0,
      });

      // Put different data into Hive to prove SQLite is actually used
      await HiveRegistrar.familyTransactionsBox.put('hive-dummy-1', {
        'id': 'hive-dummy-1',
        'type': 'income',
        'amount': 999999.0,
        'transaction_date': DateTime(now.year, now.month, 1).toIso8601String(),
        'is_deleted': 0,
      });

      final result = await repo.getReportData(
        horizon: AnalyticsTimeHorizon.monthly,
        fiscalYearStart: 'april',
      );

      expect(result.isRight(), isTrue);
      result.match(
        (l) => fail('Should have succeeded: ${l.message}'),
        (report) {
          expect(report.summary.totalIncome, 200000.0);
          expect(report.summary.totalExpense, 60000.0);
          expect(report.summary.netSavings, 140000.0);
          expect(report.summary.totalUdharLent, 80000.0);
          expect(report.summary.totalUdharCollected, 30000.0);
          expect(report.summary.netUdharReceivable, 50000.0);

          expect(report.categoryBreakdown.length, 1);
          expect(report.categoryBreakdown.first.categoryName, 'Shop Utilities');
          expect(report.categoryBreakdown.first.amount, 60000.0);
        },
      );
    });
  });
}
