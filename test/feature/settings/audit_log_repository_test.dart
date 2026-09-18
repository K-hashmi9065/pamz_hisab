import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pamz_khata/core/db/hive/hive_registrar.dart';
import 'package:pamz_khata/core/db/sqlite/app_database.dart';
import 'package:pamz_khata/core/db/sqlite/database_helper.dart';
import 'package:pamz_khata/core/db/storage_config.dart';
import 'package:pamz_khata/feature/settings/data/repositories/audit_log_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('AuditLogRepository Storage Parity Tests', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('audit_log_test_');
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

    test('Hive mode (StorageType.hive) reads from Hive and returns newest-first', () async {
      AppStorageConfig.current = StorageType.hive;
      const repo = AuditLogRepositoryImpl();

      await HiveRegistrar.auditLogBox.put('log-1', {
        'id': 'log-1',
        'entity_type': 'contacts',
        'entity_id': 'c-1',
        'action': 'create',
        'performed_at': DateTime(2026, 9, 1, 10, 0).toIso8601String(),
      });

      await HiveRegistrar.auditLogBox.put('log-2', {
        'id': 'log-2',
        'entity_type': 'direct_udhar_loans',
        'entity_id': 'l-1',
        'action': 'update',
        'performed_at': DateTime(2026, 9, 5, 12, 0).toIso8601String(),
      });

      await HiveRegistrar.auditLogBox.put('log-3', {
        'id': 'log-3',
        'entity_type': 'family_transactions',
        'entity_id': 'f-1',
        'action': 'delete',
        'performed_at': DateTime(2026, 9, 10, 8, 30).toIso8601String(),
      });

      final logs = await repo.getAuditLogs();

      expect(logs.length, 3);
      expect(logs[0].id, 'log-3'); // 2026-09-10 (newest)
      expect(logs[0].entityType, 'family_transactions');
      expect(logs[0].action, 'delete');

      expect(logs[1].id, 'log-2'); // 2026-09-05
      expect(logs[1].entityType, 'direct_udhar_loans');

      expect(logs[2].id, 'log-1'); // 2026-09-01 (oldest)
      expect(logs[2].entityType, 'contacts');
    });

    test('SQLite mode (StorageType.sqlite) reads from SQLite and ignores Hive', () async {
      AppStorageConfig.current = StorageType.sqlite;

      final sqliteDb = await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, version) async {
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
        ),
      );

      AppDatabase.instance.overrideForTesting(sqliteDb);
      final helper = DatabaseHelper(AppDatabase.instance);
      final repo = AuditLogRepositoryImpl(helper);

      // Seed SQLite with multiple entries
      await sqliteDb.insert('audit_log', {
        'id': 'sql-log-1',
        'entity_type': 'contacts',
        'entity_id': 'c-10',
        'action': 'create',
        'changed_fields_json': '{"name":"Ramesh"}',
        'performed_at': DateTime(2026, 9, 2, 10, 0).toIso8601String(),
      });

      await sqliteDb.insert('audit_log', {
        'id': 'sql-log-2',
        'entity_type': 'repayments',
        'entity_id': 'r-20',
        'action': 'create',
        'changed_fields_json': '{"amount":5000}',
        'performed_at': DateTime(2026, 9, 8, 14, 0).toIso8601String(),
      });

      await sqliteDb.insert('audit_log', {
        'id': 'sql-log-3',
        'entity_type': 'budgets',
        'entity_id': 'b-30',
        'action': 'update',
        'changed_fields_json': '{"limit_amount":25000}',
        'performed_at': DateTime(2026, 9, 6, 11, 0).toIso8601String(),
      });

      // Seed conflicting/dummy records into Hive
      await HiveRegistrar.auditLogBox.put('hive-dummy-1', {
        'id': 'hive-dummy-1',
        'entity_type': 'dummy_entity',
        'entity_id': 'd-1',
        'action': 'create',
        'performed_at': DateTime(2026, 9, 20, 12, 0).toIso8601String(),
      });

      final logs = await repo.getAuditLogs();

      expect(logs.length, 3);
      // Verify newest-first ordering from SQLite
      expect(logs[0].id, 'sql-log-2'); // 2026-09-08 (newest)
      expect(logs[0].entityType, 'repayments');
      expect(logs[0].changedFieldsJson, '{"amount":5000}');

      expect(logs[1].id, 'sql-log-3'); // 2026-09-06
      expect(logs[1].entityType, 'budgets');

      expect(logs[2].id, 'sql-log-1'); // 2026-09-02 (oldest)
      expect(logs[2].entityType, 'contacts');

      // Verify no Hive dummy record is present
      expect(logs.any((l) => l.id == 'hive-dummy-1'), isFalse);
    });
  });
}
