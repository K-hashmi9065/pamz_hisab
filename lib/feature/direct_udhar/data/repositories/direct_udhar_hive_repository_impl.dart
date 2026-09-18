import 'package:fpdart/fpdart.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/db/hive/hive_registrar.dart';
import '../../../../core/error/error_mapper.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/utils/app_date_utils.dart';
import '../../domain/entities/direct_udhar_loan.dart';
import '../../domain/repositories/direct_udhar_repository.dart';
import '../../domain/services/interest_calculator.dart';
import '../models/direct_udhar_models.dart';

/// Hive implementation of DirectUdharRepository.
class DirectUdharHiveRepositoryImpl implements DirectUdharRepository {
  const DirectUdharHiveRepositoryImpl();

  @override
  Future<Either<Failure, List<DirectUdharLoan>>> getByContact(
      String contactId) async {
    try {
      final box = HiveRegistrar.directUdharBox;
      final List<DirectUdharLoanModel> list = [];

      for (final key in box.keys) {
        final data = box.get(key);
        if (data is Map) {
          final map = Map<String, dynamic>.from(data);
          final isDeleted = (map['is_deleted'] as int? ?? 0) == 1;
          if (!isDeleted && map['contact_id'] == contactId) {
            list.add(DirectUdharLoanModel.fromMap(map));
          }
        }
      }

      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return right(list.map((m) => m.toEntity()).toList());
    } catch (e, st) {
      return left(ErrorMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, DirectUdharLoan?>> findById(String id) async {
    try {
      final box = HiveRegistrar.directUdharBox;
      final data = box.get(id);
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        final isDeleted = (map['is_deleted'] as int? ?? 0) == 1;
        if (!isDeleted) {
          return right(DirectUdharLoanModel.fromMap(map).toEntity());
        }
      }
      return right(null);
    } catch (e, st) {
      return left(ErrorMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, DirectUdharLoan>> create(DirectUdharLoan loan) async {
    try {
      final now = DateTime.now();
      final id = loan.id.isEmpty ? const Uuid().v4() : loan.id;
      final createdAt = loan.createdAt;
      final model = DirectUdharLoanModel.fromEntity(
        loan.copyWith(id: id, createdAt: createdAt, updatedAt: now),
      );

      final box = HiveRegistrar.directUdharBox;
      await box.put(id, model.toMap());

      // Audit Log
      await HiveRegistrar.auditLogBox.put(const Uuid().v4(), {
        'id': const Uuid().v4(),
        'entity_type': 'direct_udhar_loans',
        'entity_id': id,
        'action': 'create',
        'changed_fields_json': null,
        'performed_at': AppDateUtils.toIso(now),
      });

      // Update monthly summary
      await _upsertSummary(createdAt, model.direction, model.principalAmount);

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
      final box = HiveRegistrar.directUdharBox;
      await box.put(model.id, model.toMap());

      await HiveRegistrar.auditLogBox.put(const Uuid().v4(), {
        'id': const Uuid().v4(),
        'entity_type': 'direct_udhar_loans',
        'entity_id': model.id,
        'action': 'update',
        'changed_fields_json': null,
        'performed_at': AppDateUtils.toIso(DateTime.now()),
      });

      return right(model.toEntity());
    } catch (e, st) {
      return left(ErrorMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, void>> delete(String id) async {
    try {
      final box = HiveRegistrar.directUdharBox;
      final data = box.get(id);
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        map['is_deleted'] = 1;
        map['updated_at'] = AppDateUtils.toIso(DateTime.now());
        await box.put(id, map);

        await HiveRegistrar.auditLogBox.put(const Uuid().v4(), {
          'id': const Uuid().v4(),
          'entity_type': 'direct_udhar_loans',
          'entity_id': id,
          'action': 'delete',
          'changed_fields_json': null,
          'performed_at': AppDateUtils.toIso(DateTime.now()),
        });
      }
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
      final loanBox = HiveRegistrar.directUdharBox;
      final loanData = loanBox.get(loanId);
      if (loanData == null || loanData is! Map) {
        throw Exception('Loan not found');
      }

      final loanMap = Map<String, dynamic>.from(loanData);
      final loan = DirectUdharLoanModel.fromMap(loanMap).toEntity();

      // 1. Fetch existing active repayments for this loan
      final repaymentsBox = HiveRegistrar.repaymentsBox;
      final List<Repayment> existingRepayments = [];
      for (final key in repaymentsBox.keys) {
        final data = repaymentsBox.get(key);
        if (data is Map) {
          final map = Map<String, dynamic>.from(data);
          final isDeleted = (map['is_deleted'] as int? ?? 0) == 1;
          if (!isDeleted &&
              map['source_type'] == 'direct_udhar' &&
              map['source_id'] == loanId) {
            existingRepayments.add(RepaymentModel.fromMap(map).toEntity());
          }
        }
      }

      // 2. Allocate repayment using domain InterestCalculator (Interest First -> Principal Second)
      final allocation = InterestCalculator.allocateRepayment(
        loan: loan,
        existingRepayments: existingRepayments,
        newRepayment: repayment,
      );

      final repaymentId = repayment.id.isEmpty ? const Uuid().v4() : repayment.id;
      final now = DateTime.now();

      // 3. Save repayment
      await repaymentsBox.put(repaymentId, {
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

      // 4. Update loan outstanding principal + status
      loanMap['outstanding_balance'] = allocation.newOutstandingPrincipal;
      loanMap['status'] = allocation.newStatus.name == 'partiallyPaid'
          ? 'partially_paid'
          : allocation.newStatus.name;
      loanMap['updated_at'] = AppDateUtils.toIso(now);
      await loanBox.put(loanId, loanMap);

      // 5. Audit Log with interest and principal breakdown
      await HiveRegistrar.auditLogBox.put(const Uuid().v4(), {
        'id': const Uuid().v4(),
        'entity_type': 'repayment',
        'entity_id': repaymentId,
        'action': 'create',
        'changed_fields_json':
            '{"loan_id":"$loanId","amount":${repayment.amount},"interest_paid":${allocation.interestPaid},"principal_paid":${allocation.principalPaid},"remaining_principal":${allocation.newOutstandingPrincipal},"remaining_interest":${allocation.remainingAccruedInterest}}',
        'performed_at': AppDateUtils.toIso(now),
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
      final box = HiveRegistrar.directUdharBox;
      final data = box.get(loanId);
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        map['status'] = status.name;
        map['updated_at'] = AppDateUtils.toIso(DateTime.now());
        await box.put(loanId, map);
      }
      return right(null);
    } catch (e, st) {
      return left(ErrorMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, List<Repayment>>> getRepayments(
      String loanId) async {
    try {
      final box = HiveRegistrar.repaymentsBox;
      final List<RepaymentModel> list = [];

      for (final key in box.keys) {
        final data = box.get(key);
        if (data is Map) {
          final map = Map<String, dynamic>.from(data);
          final isDeleted = (map['is_deleted'] as int? ?? 0) == 1;
          if (!isDeleted &&
              map['source_type'] == 'direct_udhar' &&
              map['source_id'] == loanId) {
            list.add(RepaymentModel.fromMap(map));
          }
        }
      }

      list.sort((a, b) => b.paidAt.compareTo(a.paidAt));
      return right(list.map((m) => m.toEntity()).toList());
    } catch (e, st) {
      return left(ErrorMapper.map(e, st));
    }
  }

  Future<void> _upsertSummary(
    DateTime date,
    String direction,
    double amount,
  ) async {
    final month = AppDateUtils.toMonthKey(date);
    final box = HiveRegistrar.monthlySummaryBox;
    final isGiven = direction == 'lent';

    Map<String, dynamic> summary = {};
    for (final key in box.keys) {
      final data = box.get(key);
      if (data is Map && data['month'] == month && data['category_id'] == null) {
        summary = Map<String, dynamic>.from(data);
        break;
      }
    }

    final id = summary['id'] as String? ?? const Uuid().v4();
    final totalGiven = ((summary['total_udhar_given'] as num?)?.toDouble() ?? 0.0) + (isGiven ? amount : 0);
    final totalReceived = ((summary['total_udhar_received'] as num?)?.toDouble() ?? 0.0) + (isGiven ? 0 : amount);

    await box.put(id, {
      'id': id,
      'month': month,
      'category_id': null,
      'total_udhar_given': totalGiven,
      'total_udhar_received': totalReceived,
    });
  }
}
