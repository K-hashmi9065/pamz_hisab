import 'package:sqflite/sqflite.dart';

import '../../../../core/db/sqlite/database_helper.dart';
import '../../../../core/utils/app_date_utils.dart';
import '../../domain/entities/fl_transaction.dart';
import '../../domain/repositories/fl_transaction_repository.dart';
import '../models/fl_transaction_model.dart';
import 'fl_transaction_datasource.dart';

/// SQLite datasource for Fund Ledger transactions.
class FLTransactionSqliteDataSource implements FLTransactionDataSource {
  const FLTransactionSqliteDataSource(this._db);
  final DatabaseHelper _db;

  static const _table = 'fl_transactions';

  @override
  Future<List<FLTransactionModel>> getByContact(String contactId) async {
    final rows = await _db.query(
      _table,
      where: 'contact_id = ? AND is_deleted = 0',
      whereArgs: [contactId],
      orderBy: 'txn_date DESC, created_at DESC',
    );
    return rows.map(FLTransactionModel.fromMap).toList();
  }

  @override
  Future<List<FLTransactionModel>> getAll({
    FLTransactionType? type,
    String? contactId,
    String? fromDate,
    String? toDate,
  }) async {
    final conditions = <String>['is_deleted = 0'];
    final args = <Object?>[];

    if (type != null) {
      conditions.add('type = ?');
      args.add(type.dbValue);
    }
    if (contactId != null) {
      conditions.add('contact_id = ?');
      args.add(contactId);
    }
    if (fromDate != null) {
      conditions.add("txn_date >= ?");
      args.add(fromDate);
    }
    if (toDate != null) {
      conditions.add("txn_date <= ?");
      args.add(toDate);
    }

    final rows = await _db.query(
      _table,
      where: conditions.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'txn_date DESC, created_at DESC',
    );
    return rows.map(FLTransactionModel.fromMap).toList();
  }

  @override
  Future<void> insert(FLTransactionModel model) async {
    await _db.insert(
      _table,
      model.toMap(),
      conflictAlgorithm: ConflictAlgorithm.fail,
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

  @override
  Future<FLContactTotals> getTotals(String contactId) async {
    final rows = await _db.rawQuery(
      '''
      SELECT type, SUM(amount) as total
      FROM $_table
      WHERE contact_id = ? AND is_deleted = 0
      GROUP BY type
      ''',
      [contactId],
    );
    return _rowsToTotals(rows);
  }

  @override
  Future<FLContactTotals> getGlobalTotals() async {
    final rows = await _db.rawQuery(
      '''
      SELECT type, SUM(amount) as total
      FROM $_table
      WHERE is_deleted = 0
      GROUP BY type
      ''',
    );
    return _rowsToTotals(rows);
  }

  FLContactTotals _rowsToTotals(List<Map<String, dynamic>> rows) {
    double received = 0;
    double utilized = 0;
    double returned = 0;
    for (final row in rows) {
      final type = row['type'] as String;
      final total = (row['total'] as num?)?.toDouble() ?? 0;
      switch (type) {
        case 'received':
          received = total;
        case 'utilized':
          utilized = total;
        case 'returned':
          returned = total;
      }
    }
    return FLContactTotals(
      totalReceived: received,
      totalUtilized: utilized,
      totalReturned: returned,
    );
  }
}
