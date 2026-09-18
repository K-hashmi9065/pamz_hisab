import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/db/sqlite/database_helper.dart';
import '../../../../core/utils/app_date_utils.dart';
import '../../../direct_udhar/data/models/direct_udhar_models.dart';
import '../../../direct_udhar/domain/entities/direct_udhar_loan.dart';
import '../../../direct_udhar/domain/services/interest_calculator.dart';
import '../models/contact_model.dart';
import 'contact_datasource.dart';

/// SQLite datasource for contacts — raw DB operations only, no business logic.
class ContactSqliteDataSource implements ContactDataSource {
  const ContactSqliteDataSource(this._db);

  final DatabaseHelper _db;

  static const _table = 'contacts';
  static const _auditTable = 'audit_log';

  @override
  Future<List<ContactModel>> getAll({String? type}) async {
    final rows = await _db.query(
      _table,
      where: type != null
          ? 'is_deleted = 0 AND type = ?'
          : 'is_deleted = 0',
      whereArgs: type != null ? [type] : null,
      orderBy: 'name ASC',
    );
    return rows.map(ContactModel.fromMap).toList();
  }

  @override
  Future<ContactModel?> findById(String id) async {
    final row = await _db.queryFirst(
      _table,
      where: 'id = ? AND is_deleted = 0',
      whereArgs: [id],
    );
    return row == null ? null : ContactModel.fromMap(row);
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
  Future<void> insert(ContactModel model) async {
    await _db.runInTransaction((txn) async {
      await txn.insert(_table, model.toMap(), conflictAlgorithm: ConflictAlgorithm.fail);
      await txn.insert(_auditTable, {
        'id': const Uuid().v4(),
        'entity_type': 'contacts',
        'entity_id': model.id,
        'action': 'create',
        'changed_fields_json':
            '{"name":"${model.name}","mobile_number":"${model.mobileNumber}","type":"${model.type}"}',
        'performed_at': AppDateUtils.toIso(DateTime.now()),
      });
    });
  }

  @override
  Future<void> update(ContactModel model) async {
    await _db.runInTransaction((txn) async {
      await txn.update(
        _table,
        model.toMap(),
        where: 'id = ?',
        whereArgs: [model.id],
      );
      await txn.insert(_auditTable, {
        'id': const Uuid().v4(),
        'entity_type': 'contacts',
        'entity_id': model.id,
        'action': 'update',
        'changed_fields_json':
            '{"name":"${model.name}","mobile_number":"${model.mobileNumber}","credit_limit":${model.creditLimit}}',
        'performed_at': AppDateUtils.toIso(DateTime.now()),
      });
    });
  }

  @override
  Future<void> softDelete(String id) async {
    final now = DateTime.now();
    await _db.runInTransaction((txn) async {
      await txn.update(
        _table,
        {
          'is_deleted': 1,
          'updated_at': AppDateUtils.toIso(now),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      await txn.insert(_auditTable, {
        'id': const Uuid().v4(),
        'entity_type': 'contacts',
        'entity_id': id,
        'action': 'delete',
        'changed_fields_json': null,
        'performed_at': AppDateUtils.toIso(now),
      });
    });
  }

  @override
  Future<double> getTotalBalance(String contactId) async {
    // Fetch active (non-deleted, non-closed) loans for the contact
    final loanRows = await _db.query(
      'direct_udhar_loans',
      where: 'contact_id = ? AND is_deleted = 0 AND status != ?',
      whereArgs: [contactId, 'closed'],
    );

    if (loanRows.isEmpty) return 0.0;

    final now = DateTime.now();
    double net = 0.0;

    for (final row in loanRows) {
      final loan = DirectUdharLoanModel.fromMap(row).toEntity();

      // Fetch active repayments for this loan
      final repRows = await _db.query(
        'repayments',
        where: 'source_type = ? AND source_id = ? AND is_deleted = 0',
        whereArgs: ['direct_udhar', loan.id],
      );
      final repayments =
          repRows.map((r) => RepaymentModel.fromMap(r).toEntity()).toList();

      final summary = InterestCalculator.calculateSummary(
        loan: loan,
        repayments: repayments,
        asOfDate: now,
      );

      if (loan.direction == LoanDirection.lent) {
        net += summary.totalOutstanding;
      } else {
        net -= summary.totalOutstanding;
      }
    }

    return net;
  }
}
