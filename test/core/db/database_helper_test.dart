import 'package:flutter_test/flutter_test.dart';
import 'package:pamz_khata/core/db/sqlite/app_database.dart';
import 'package:pamz_khata/core/db/sqlite/database_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
  late DatabaseHelper helper;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await db.execute('''
      CREATE TABLE contacts (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        name TEXT NOT NULL,
        phone TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    AppDatabase.instance.overrideForTesting(db);
    helper = DatabaseHelper(AppDatabase.instance);
  });

  tearDown(() async {
    await AppDatabase.instance.close();
  });

  group('DatabaseHelper Unit Tests', () {
    test('insert, queryFirst, query, update, rawQuery, runInTransaction operate correctly', () async {
      final id = await helper.insert('contacts', {
        'id': 'c1',
        'type': 'buyer',
        'name': 'Ramesh Kumar',
        'phone': '9876543210',
        'is_active': 1,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      expect(id, isNonZero);

      final row = await helper.queryFirst(
        'contacts',
        where: 'id = ?',
        whereArgs: ['c1'],
      );
      expect(row, isNotNull);
      expect(row!['name'], 'Ramesh Kumar');

      // Update
      final count = await helper.update(
        'contacts',
        {'name': 'Ramesh Kumar Updated'},
        where: 'id = ?',
        whereArgs: ['c1'],
      );
      expect(count, 1);

      // Query
      final list = await helper.query(
        'contacts',
        where: 'id = ?',
        whereArgs: ['c1'],
      );
      expect(list.length, 1);
      expect(list.first['name'], 'Ramesh Kumar Updated');

      // RawQuery
      final raw = await helper.rawQuery('SELECT count(*) as total FROM contacts');
      expect(raw.first['total'], 1);

      // Transaction
      await helper.runInTransaction((txn) async {
        await txn.insert('contacts', {
          'id': 'c2',
          'type': 'supplier',
          'name': 'Suresh Trader',
          'phone': '9876543211',
          'is_active': 1,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      });

      final total = await helper.rawQuery('SELECT count(*) as total FROM contacts');
      expect(total.first['total'], 2);
    });
  });
}
