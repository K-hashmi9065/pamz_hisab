import 'package:sqflite/sqflite.dart';

import '../../../../core/db/sqlite/database_helper.dart';
import '../../../../core/utils/app_date_utils.dart';
import '../models/fl_contact_model.dart';
import 'fl_contact_datasource.dart';

/// SQLite datasource for Fund Ledger contacts.
class FLContactSqliteDataSource implements FLContactDataSource {
  const FLContactSqliteDataSource(this._db);
  final DatabaseHelper _db;

  static const _table = 'fl_contacts';

  @override
  Future<List<FLContactModel>> getAll() async {
    final rows = await _db.query(
      _table,
      where: 'is_deleted = 0',
      orderBy: 'name ASC',
    );
    return rows.map(FLContactModel.fromMap).toList();
  }

  @override
  Future<FLContactModel?> findById(String id) async {
    final row = await _db.queryFirst(
      _table,
      where: 'id = ? AND is_deleted = 0',
      whereArgs: [id],
    );
    return row == null ? null : FLContactModel.fromMap(row);
  }

  @override
  Future<bool> existsByMobile(String mobile, {String? excludeId}) async {
    final where = excludeId != null
        ? 'mobile_number = ? AND is_deleted = 0 AND id != ?'
        : 'mobile_number = ? AND is_deleted = 0';
    final args = excludeId != null ? [mobile, excludeId] : [mobile];
    final row = await _db.queryFirst(_table, where: where, whereArgs: args);
    return row != null;
  }

  @override
  Future<void> insert(FLContactModel model) async {
    await _db.insert(
      _table,
      model.toMap(),
      conflictAlgorithm: ConflictAlgorithm.fail,
    );
  }

  @override
  Future<void> update(FLContactModel model) async {
    await _db.update(
      _table,
      model.toMap(),
      where: 'id = ?',
      whereArgs: [model.id],
    );
  }

  @override
  Future<void> softDelete(String id) async {
    await _db.update(
      _table,
      {
        'is_deleted': 1,
        'updated_at': AppDateUtils.toIso(DateTime.now()),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
