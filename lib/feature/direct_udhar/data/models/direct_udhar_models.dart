import '../../../../core/utils/app_date_utils.dart';
import '../../domain/entities/direct_udhar_loan.dart';

/// DTO for DirectUdharLoan ↔ SQLite row mapping.
class DirectUdharLoanModel {
  const DirectUdharLoanModel({
    required this.id,
    required this.contactId,
    required this.direction,
    required this.principalAmount,
    required this.interestType,
    this.interestRatePercent,
    this.dueDate,
    this.memo,
    required this.status,
    required this.outstandingBalance,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
  });

  final String id;
  final String contactId;
  final String direction;
  final double principalAmount;
  final String interestType;
  final double? interestRatePercent;
  final String? dueDate;
  final String? memo;
  final String status;
  final double outstandingBalance;
  final String createdAt;
  final String updatedAt;
  final bool isDeleted;

  factory DirectUdharLoanModel.fromMap(Map<String, dynamic> map) {
    return DirectUdharLoanModel(
      id: map['id'] as String,
      contactId: map['contact_id'] as String,
      direction: map['direction'] as String,
      principalAmount: (map['principal_amount'] as num).toDouble(),
      interestType: map['interest_type'] as String,
      interestRatePercent: (map['interest_rate_percent'] as num?)?.toDouble(),
      dueDate: map['due_date'] as String?,
      memo: map['memo'] as String?,
      status: map['status'] as String,
      outstandingBalance: (map['outstanding_balance'] as num).toDouble(),
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
      isDeleted: (map['is_deleted'] as int? ?? 0) == 1,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'contact_id': contactId,
        'direction': direction,
        'principal_amount': principalAmount,
        'interest_type': interestType,
        'interest_rate_percent': interestRatePercent,
        'due_date': dueDate,
        'memo': memo,
        'status': status,
        'outstanding_balance': outstandingBalance,
        'created_at': createdAt,
        'updated_at': updatedAt,
        'is_deleted': isDeleted ? 1 : 0,
      };

  DirectUdharLoan toEntity() => DirectUdharLoan(
        id: id,
        contactId: contactId,
        direction: direction == 'lent' ? LoanDirection.lent : LoanDirection.borrowed,
        principalAmount: principalAmount,
        interestType: interestType == 'simple'
            ? InterestType.simple
            : InterestType.interestFree,
        interestRatePercent: interestRatePercent,
        dueDate: AppDateUtils.parseIso(dueDate),
        memo: memo,
        status: _parseStatus(status),
        outstandingBalance: outstandingBalance,
        createdAt: AppDateUtils.parseIso(createdAt) ?? DateTime.now(),
        updatedAt: AppDateUtils.parseIso(updatedAt) ?? DateTime.now(),
        isDeleted: isDeleted,
      );

  factory DirectUdharLoanModel.fromEntity(DirectUdharLoan loan) {
    final now = AppDateUtils.toIso(DateTime.now());
    return DirectUdharLoanModel(
      id: loan.id,
      contactId: loan.contactId,
      direction: loan.direction.name,
      principalAmount: loan.principalAmount,
      interestType: loan.interestType == InterestType.simple ? 'simple' : 'interest_free',
      interestRatePercent: loan.interestRatePercent,
      dueDate: loan.dueDate != null ? AppDateUtils.toIso(loan.dueDate!) : null,
      memo: loan.memo,
      status: _statusString(loan.status),
      outstandingBalance: loan.outstandingBalance,
      createdAt: AppDateUtils.toIso(loan.createdAt),
      updatedAt: now,
      isDeleted: loan.isDeleted,
    );
  }

  static LoanStatus _parseStatus(String s) => switch (s) {
        'partially_paid' => LoanStatus.partiallyPaid,
        'closed' => LoanStatus.closed,
        _ => LoanStatus.open,
      };

  static String _statusString(LoanStatus s) => switch (s) {
        LoanStatus.partiallyPaid => 'partially_paid',
        LoanStatus.closed => 'closed',
        LoanStatus.open => 'open',
      };
}

/// DTO for Repayment ↔ SQLite row mapping.
class RepaymentModel {
  const RepaymentModel({
    required this.id,
    required this.sourceType,
    required this.sourceId,
    required this.amount,
    this.paymentMode,
    required this.paidAt,
    this.memo,
    required this.createdAt,
    this.isDeleted = false,
  });

  final String id;
  final String sourceType;
  final String sourceId;
  final double amount;
  final String? paymentMode;
  final String paidAt;
  final String? memo;
  final String createdAt;
  final bool isDeleted;

  factory RepaymentModel.fromMap(Map<String, dynamic> map) => RepaymentModel(
        id: map['id'] as String,
        sourceType: map['source_type'] as String,
        sourceId: map['source_id'] as String,
        amount: (map['amount'] as num).toDouble(),
        paymentMode: map['payment_mode'] as String?,
        paidAt: map['paid_at'] as String,
        memo: map['memo'] as String?,
        createdAt: map['created_at'] as String,
        isDeleted: (map['is_deleted'] as int? ?? 0) == 1,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'source_type': sourceType,
        'source_id': sourceId,
        'amount': amount,
        'payment_mode': paymentMode,
        'paid_at': paidAt,
        'memo': memo,
        'created_at': createdAt,
        'is_deleted': isDeleted ? 1 : 0,
      };

  Repayment toEntity() => Repayment(
        id: id,
        sourceType: sourceType == 'direct_udhar'
            ? RepaymentSourceType.directUdhar
            : RepaymentSourceType.tradeLedger,
        sourceId: sourceId,
        amount: amount,
        paymentMode: paymentMode,
        paidAt: AppDateUtils.parseIso(paidAt) ?? DateTime.now(),
        memo: memo,
        createdAt: AppDateUtils.parseIso(createdAt) ?? DateTime.now(),
        isDeleted: isDeleted,
      );

  factory RepaymentModel.fromEntity(Repayment r) => RepaymentModel(
        id: r.id,
        sourceType:
            r.sourceType == RepaymentSourceType.directUdhar ? 'direct_udhar' : 'trade_ledger',
        sourceId: r.sourceId,
        amount: r.amount,
        paymentMode: r.paymentMode,
        paidAt: AppDateUtils.toIso(r.paidAt),
        memo: r.memo,
        createdAt: AppDateUtils.toIso(r.createdAt),
        isDeleted: r.isDeleted,
      );
}
