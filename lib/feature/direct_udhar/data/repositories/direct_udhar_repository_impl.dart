import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/db/sqlite/database_helper.dart';
import '../../../../core/error/error_mapper.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/utils/app_date_utils.dart';
import 'package:fpdart/fpdart.dart';

import '../../domain/entities/direct_udhar_loan.dart';
import '../../domain/repositories/direct_udhar_repository.dart';
import '../../domain/services/interest_calculator.dart';
import '../models/direct_udhar_models.dart';

/// SQLite implementation of DirectUdharRepository.
/// Key invariant: recordRepayment + balance update + audit_log are atomic.
class DirectUdharRepositoryImpl implements DirectUdharRepository {
  const DirectUdharRepositoryImpl(this._db);
  final DatabaseHelper _db;

  static const _loansTable = 'direct_udhar_loans';
  static const _repaymentsTable = 'repayments';
  static const _auditTable = 'audit_log';
  static const _summaryTable = 'monthly_summary';

  @override
  Future<Either<Failure, List<DirectUdharLoan>>> getByContact(
      String contactId) async {
    try {
      final rows = await _db.query(
        _loansTable,
        where: 'contact_id = ? AND is_deleted = 0',
        whereArgs: [contactId],
        orderBy: 'created_at DESC',
      );
      return right(rows.map((r) => DirectUdharLoanModel.fromMap(r).toEntity()).toList());
    } catch (e, st) {
      return left(ErrorMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, DirectUdharLoan?>> findById(String id) async {
    try {
      final row = await _db.queryFirst(
        _loansTable,
        where: 'id = ? AND is_deleted = 0',
        whereArgs: [id],
      );
      return right(row == null ? null : DirectUdharLoanModel.fromMap(row).toEntity());
    } catch (e, st) {
      return left(ErrorMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, DirectUdharLoan>> create(DirectUdharLoan loan) async {
    try {
      final now = DateTime.now();
      final createdAt = loan.createdAt;
      final model = DirectUdharLoanModel.fromEntity(
        loan.copyWith(
          id: loan.id.isEmpty ? const Uuid().v4() : loan.id,
          createdAt: createdAt,
          updatedAt: now,
        ),
      );
      await _db.runInTransaction((txn) async {
        await txn.insert(_loansTable, model.toMap());
        await txn.insert(_auditTable, _auditRow(
          entityType: 'direct_udhar_loans',
          entityId: model.id,
          action: 'create',
          changedJson: null,
        ));
        // Update monthly_summary for udhar_given/received
        await _upsertSummary(txn, createdAt, model.direction, model.principalAmount);
      });
      return right(model.toEntity());
    } catch (e, st) {
      return left(ErrorMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, DirectUdharLoan>> update(DirectUdharLoan loan) async {
    try {
      final model = DirectUdharLoanModel.fromEntity(
        loan.copyWith(updatedAt: DateTime.now()),
      );
      await _db.runInTransaction((txn) async {
        await txn.update(
          _loansTable,
          model.toMap(),
          where: 'id = ?',
          whereArgs: [model.id],
        );
        await txn.insert(_auditTable, _auditRow(
          entityType: 'direct_udhar_loans',
          entityId: model.id,
          action: 'update',
          changedJson: null,
        ));
      });
      return right(model.toEntity());
    } catch (e, st) {
      return left(ErrorMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, void>> delete(String id) async {
    try {
      await _db.runInTransaction((txn) async {
        await txn.update(
          _loansTable,
          {'is_deleted': 1, 'updated_at': AppDateUtils.toIso(DateTime.now())},
          where: 'id = ?',
          whereArgs: [id],
        );
        await txn.insert(_auditTable, _auditRow(
          entityType: 'direct_udhar_loans',
          entityId: id,
          action: 'delete',
          changedJson: null,
        ));
      });
      return right(null);
    } catch (e, st) {
      return left(ErrorMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, void>> recordRepayment(
    String loanId,
    Repayment repayment,
  ) async {
    try {
      await _db.runInTransaction((txn) async {
        // 1. Fetch current loan
        final rows = await txn.query(
          _loansTable,
          where: 'id = ?',
          whereArgs: [loanId],
          limit: 1,
        );
        if (rows.isEmpty) throw Exception('Loan not found');

        final loan = DirectUdharLoanModel.fromMap(rows.first).toEntity();

        // 2. Fetch existing repayments for this loan
        final repaymentRows = await txn.query(
          _repaymentsTable,
          where: 'source_type = ? AND source_id = ? AND is_deleted = 0',
          whereArgs: ['direct_udhar', loanId],
          orderBy: 'paid_at ASC',
        );
        final existingRepayments = repaymentRows
            .map((r) => RepaymentModel.fromMap(r).toEntity())
            .toList();

        // 3. Allocate repayment using domain InterestCalculator (Interest First -> Principal Second)
        final allocation = InterestCalculator.allocateRepayment(
          loan: loan,
          existingRepayments: existingRepayments,
          newRepayment: repayment,
        );

        // 4. Insert repayment
        final repaymentId = repayment.id.isEmpty ? const Uuid().v4() : repayment.id;
        final now = DateTime.now();
        await txn.insert(_repaymentsTable, {
          'id': repaymentId,
          'source_type': 'direct_udhar',
          'source_id': loanId,
          'amount': repayment.amount,
          'payment_mode': repayment.paymentMode,
          'paid_at': AppDateUtils.toIso(repayment.paidAt),
          'memo': repayment.memo,
          'created_at': AppDateUtils.toIso(now),
          'is_deleted': 0,
        });

        // 5. Update outstanding principal + status
        await txn.update(
          _loansTable,
          {
            'outstanding_balance': allocation.newOutstandingPrincipal,
            'status': allocation.newStatus.name == 'partiallyPaid'
                ? 'partially_paid'
                : allocation.newStatus.name,
            'updated_at': AppDateUtils.toIso(now),
          },
          where: 'id = ?',
          whereArgs: [loanId],
        );

        // 6. Audit log with interest and principal breakdown
        await txn.insert(_auditTable, _auditRow(
          entityType: 'repayment',
          entityId: repaymentId,
          action: 'create',
          changedJson:
              '{"loan_id":"$loanId","amount":${repayment.amount},"interest_paid":${allocation.interestPaid},"principal_paid":${allocation.principalPaid},"remaining_principal":${allocation.newOutstandingPrincipal},"remaining_interest":${allocation.remainingAccruedInterest}}',
        ));
      });
      return right(null);
    } catch (e, st) {
      return left(ErrorMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, void>> updateStatus(
      String loanId, LoanStatus status) async {
    try {
      await _db.update(
        _loansTable,
        {
          'status': DirectUdharLoanModel.fromEntity(
            DirectUdharLoan(
              id: loanId,
              contactId: '',
              direction: LoanDirection.lent,
              principalAmount: 0,
              interestType: InterestType.interestFree,
              status: status,
              outstandingBalance: 0,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          ).toMap()['status'],
          'updated_at': AppDateUtils.toIso(DateTime.now()),
        },
        where: 'id = ?',
        whereArgs: [loanId],
      );
      return right(null);
    } catch (e, st) {
      return left(ErrorMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, List<Repayment>>> getRepayments(
      String loanId) async {
    try {
      final rows = await _db.query(
        _repaymentsTable,
        where: 'source_type = ? AND source_id = ? AND is_deleted = 0',
        whereArgs: ['direct_udhar', loanId],
        orderBy: 'paid_at DESC',
      );
      return right(rows.map((r) => RepaymentModel.fromMap(r).toEntity()).toList());
    } catch (e, st) {
      return left(ErrorMapper.map(e, st));
    }
  }

  Map<String, dynamic> _auditRow({
    required String entityType,
    required String entityId,
    required String action,
    String? changedJson,
  }) {
    return {
      'id': const Uuid().v4(),
      'entity_type': entityType,
      'entity_id': entityId,
      'action': action,
      'changed_fields_json': changedJson,
      'performed_at': AppDateUtils.toIso(DateTime.now()),
    };
  }

  Future<void> _upsertSummary(
    Transaction txn,
    DateTime date,
    String direction,
    double amount,
  ) async {
    final month = AppDateUtils.toMonthKey(date);
    final summaryId = const Uuid().v4();
    final isGiven = direction == 'lent';

    await txn.rawInsert('''
      INSERT INTO $_summaryTable (id, month, category_id, total_udhar_given, total_udhar_received)
      VALUES (?, ?, NULL, ?, ?)
      ON CONFLICT(month, category_id) DO UPDATE SET
        total_udhar_given = total_udhar_given + excluded.total_udhar_given,
        total_udhar_received = total_udhar_received + excluded.total_udhar_received
    ''', [
      summaryId,
      month,
      isGiven ? amount : 0,
      isGiven ? 0 : amount,
    ]);
  }
}
