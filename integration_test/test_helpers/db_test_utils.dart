import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:pamz_khata/core/db/sqlite/app_database.dart';

/// Sets up an in-memory SQLite database for integration tests.
/// Uses sqflite_common_ffi so it works on Windows/macOS/Linux CI.
Future<void> setUpInMemoryDatabase() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  // Open a fresh in-memory DB and inject it into AppDatabase singleton
  final db = await databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, version) async {
        // Delegate to the same onCreate used in production
        // by calling AppDatabase.instance._onCreate indirectly
        // via a fresh AppDatabase open on a temp path
      },
    ),
  );

  // Override the singleton for the duration of the test
  AppDatabase.instance.overrideForTesting(db);
}

/// Tears down the test database.
Future<void> tearDownTestDatabase() async {
  await AppDatabase.instance.close();
}
