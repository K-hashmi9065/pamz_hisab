import 'package:sqflite/sqflite.dart';

import '../../../../core/db/audit/audit_logger.dart';
import '../../../../core/db/sqlite/database_helper.dart';
import '../../../../core/utils/app_date_utils.dart';
import '../models/family_utilize_model.dart';
import 'family_utilize_datasource.dart';

/// SQLite datasource for Family Utilizations.
class FamilyUtilizeSqliteDataSource implements FamilyUtilizeDataSource {
  const FamilyUtilizeSqliteDataSource(this._db);
  final DatabaseHelper _db;

  static const _table = 'family_utilizations';

  @override
  Future<List<FamilyUtilizeModel>> getAll({
    String? category,
    String? fromDate,
    String? toDate,
    String? searchQuery,
  }) async {
    final conditions = <String>['is_deleted = 0'];
    final args = <Object?>[];

    if (category != null && category.isNotEmpty) {
      conditions.add('LOWER(category) = LOWER(?)');
      args.add(category);
    }
    if (fromDate != null) {
      conditions.add('transaction_date >= ?');
      args.add(fromDate);
    }
    if (toDate != null) {
      conditions.add('transaction_date <= ?');
      args.add(toDate);
    }
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = '%${searchQuery.trim().toLowerCase()}%';
      conditions.add(
        '(LOWER(title) LIKE ? OR LOWER(category) LIKE ? OR LOWER(COALESCE(paid_to, "")) LIKE ? OR LOWER(COALESCE(description, "")) LIKE ? OR LOWER(COALESCE(mobile_number, "")) LIKE ? OR LOWER(COALESCE(payment_mode, "")) LIKE ? OR LOWER(COALESCE(payment_reference, "")) LIKE ? OR CAST(amount AS TEXT) LIKE ?)',
      );
      args.addAll([q, q, q, q, q, q, q, q]);
    }

    final rows = await _db.query(
      _table,
      where: conditions.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'transaction_date DESC, created_at DESC',
    );
    return rows.map(FamilyUtilizeModel.fromMap).toList();
  }

  @override
  Future<FamilyUtilizeModel?> getById(String id) async {
    final rows = await _db.query(
      _table,
      where: 'id = ? AND is_deleted = 0',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return FamilyUtilizeModel.fromMap(rows.first);
  }

  @override
  Future<void> insert(FamilyUtilizeModel model) async {
    await _db.insert(
      _table,
      model.toMap(),
      conflictAlgorithm: ConflictAlgorithm.fail,
    );
    await AuditLogger.record(
      entityType: 'family_utilizations',
      entityId: model.id,
      action: 'create',
      metadata: {
        'category': model.category,
        'title': model.title,
        'amount': model.amount,
        'paid_to': model.paidTo,
      },
    );
  }

  @override
  Future<void> update(FamilyUtilizeModel model) async {
    await _db.update(
      _table,
      model.toMap(),
      where: 'id = ?',
      whereArgs: [model.id],
    );
    await AuditLogger.record(
      entityType: 'family_utilizations',
      entityId: model.id,
      action: 'update',
      metadata: {
        'category': model.category,
        'title': model.title,
        'amount': model.amount,
      },
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
    await AuditLogger.record(
      entityType: 'family_utilizations',
      entityId: id,
      action: 'delete',
    );
  }

  @override
  Future<double> getTotalFamilyUtilized({
    String? fromDate,
    String? toDate,
  }) async {
    final conditions = <String>['is_deleted = 0'];
    final args = <Object?>[];

    if (fromDate != null) {
      conditions.add('transaction_date >= ?');
      args.add(fromDate);
    }
    if (toDate != null) {
      conditions.add('transaction_date <= ?');
      args.add(toDate);
    }

    final rows = await _db.rawQuery(
      '''
      SELECT SUM(amount) as total
      FROM $_table
      WHERE ${conditions.join(' AND ')}
      ''',
      args.isEmpty ? null : args,
    );

    if (rows.isEmpty || rows.first['total'] == null) {
      return 0.0;
    }
    return (rows.first['total'] as num).toDouble();
  }
}
