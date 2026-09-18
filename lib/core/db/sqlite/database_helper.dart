import 'package:sqflite/sqflite.dart';

import 'app_database.dart';

/// Convenience wrapper for running operations inside a SQLite transaction.
/// All financial writes MUST use this — atomic with audit_log + monthly_summary.
class DatabaseHelper {
  final AppDatabase _appDb;

  DatabaseHelper(this._appDb);

  Future<Database> get _db => _appDb.database;

  /// Executes [action] inside a SQLite transaction.
  /// Rolls back automatically on any exception.
  Future<T> runInTransaction<T>(
    Future<T> Function(Transaction txn) action,
  ) async {
    final db = await _db;
    return db.transaction(action);
  }

  /// Inserts a row. Returns the row id.
  Future<int> insert(
    String table,
    Map<String, dynamic> values, {
    ConflictAlgorithm conflictAlgorithm = ConflictAlgorithm.fail,
  }) async {
    final db = await _db;
    return db.insert(table, values, conflictAlgorithm: conflictAlgorithm);
  }

  /// Updates rows matching [where] / [whereArgs].
  Future<int> update(
    String table,
    Map<String, dynamic> values, {
    required String where,
    required List<Object?> whereArgs,
  }) async {
    final db = await _db;
    return db.update(table, values, where: where, whereArgs: whereArgs);
  }

  /// Queries [table] with optional filters, ordering, limit.
  Future<List<Map<String, dynamic>>> query(
    String table, {
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final db = await _db;
    return db.query(
      table,
      columns: columns,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
  }

  /// Executes a raw SQL query and returns results.
  Future<List<Map<String, dynamic>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) async {
    final db = await _db;
    return db.rawQuery(sql, arguments);
  }

  /// Returns a single row or null.
  Future<Map<String, dynamic>?> queryFirst(
    String table, {
    List<String>? columns,
    required String where,
    required List<Object?> whereArgs,
  }) async {
    final results = await query(
      table,
      columns: columns,
      where: where,
      whereArgs: whereArgs,
      limit: 1,
    );
    return results.isEmpty ? null : results.first;
  }
}
