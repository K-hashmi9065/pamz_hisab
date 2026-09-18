/// Direct cash loan entity — money-only lending/borrowing (FR-DU-001/002).
class DirectUdharLoan {
  const DirectUdharLoan({
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
  final LoanDirection direction;
  final double principalAmount;
  final InterestType interestType;
  final double? interestRatePercent;
  final DateTime? dueDate;
  final String? memo;
  final LoanStatus status;
  final double outstandingBalance;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

  bool get isOpen => status == LoanStatus.open;
  bool get isClosed => status == LoanStatus.closed;
  bool get isOverdue =>
      dueDate != null && dueDate!.isBefore(DateTime.now()) && !isClosed;
  bool get isSimpleInterest =>
      interestType == InterestType.simple &&
      interestRatePercent != null &&
      interestRatePercent! > 0;
  bool get isInterestFree => !isSimpleInterest;

  DirectUdharLoan copyWith({
    String? id,
    String? contactId,
    LoanDirection? direction,
    double? principalAmount,
    InterestType? interestType,
    double? interestRatePercent,
    DateTime? dueDate,
    String? memo,
    LoanStatus? status,
    double? outstandingBalance,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
  }) {
    return DirectUdharLoan(
      id: id ?? this.id,
      contactId: contactId ?? this.contactId,
      direction: direction ?? this.direction,
      principalAmount: principalAmount ?? this.principalAmount,
      interestType: interestType ?? this.interestType,
      interestRatePercent: interestRatePercent ?? this.interestRatePercent,
      dueDate: dueDate ?? this.dueDate,
      memo: memo ?? this.memo,
      status: status ?? this.status,
      outstandingBalance: outstandingBalance ?? this.outstandingBalance,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is DirectUdharLoan && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

enum LoanDirection { lent, borrowed }
enum InterestType { simple, interestFree }
enum LoanStatus { open, partiallyPaid, closed }

/// Repayment (Jama) — partial or full payment against a loan or trade ledger.
class Repayment {
  const Repayment({
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
  final RepaymentSourceType sourceType;
  final String sourceId;
  final double amount;
  final String? paymentMode;
  final DateTime paidAt;
  final String? memo;
  final DateTime createdAt;
  final bool isDeleted;

  Repayment copyWith({
    String? id,
    RepaymentSourceType? sourceType,
    String? sourceId,
    double? amount,
    String? paymentMode,
    DateTime? paidAt,
    String? memo,
    DateTime? createdAt,
    bool? isDeleted,
  }) {
    return Repayment(
      id: id ?? this.id,
      sourceType: sourceType ?? this.sourceType,
      sourceId: sourceId ?? this.sourceId,
      amount: amount ?? this.amount,
      paymentMode: paymentMode ?? this.paymentMode,
      paidAt: paidAt ?? this.paidAt,
      memo: memo ?? this.memo,
      createdAt: createdAt ?? this.createdAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Repayment && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

enum RepaymentSourceType { directUdhar, tradeLedger }
