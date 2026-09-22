import 'package:fpdart/fpdart.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/error/failure.dart';
import '../entities/fl_transaction.dart';
import '../repositories/fl_transaction_repository.dart';
import 'fl_summary_calculator.dart';

// ─── Payment mode validation constants ────────────────────────────────────

/// Recognised payment mode codes for Fund Ledger.
class FLPaymentMode {
  FLPaymentMode._();
  static const String cash = 'cash';
  static const String upi = 'upi';
  static const String cheque = 'cheque';
  static const String draft = 'draft';

  static const List<String> all = [cash, upi, cheque, draft];

  static String label(String code) {
    switch (code) {
      case cash:
        return 'Cash';
      case upi:
        return 'UPI';
      case cheque:
        return 'Cheque';
      case draft:
        return 'Draft';
      default:
        return code;
    }
  }

  /// Returns the label for the required reference field, or null for Cash.
  static String? referenceLabel(String code) {
    switch (code) {
      case upi:
        return 'UTR Number';
      case cheque:
        return 'Cheque Number';
      case draft:
        return 'Draft Number';
      default:
        return null;
    }
  }

  static bool requiresReference(String code) =>
      code == upi || code == cheque || code == draft;
}

// ─── Add Transaction Use Case ──────────────────────────────────────────────

class AddFLTransactionUsecase {
  const AddFLTransactionUsecase(this._repository);
  final FLTransactionRepository _repository;

  Future<Either<Failure, void>> call(FLTransaction transaction) async {
    // Amount validation
    if (transaction.amount <= 0) {
      return const Left(ValidationFailure(
        message: 'Amount must be greater than zero.',
        field: 'amount',
      ));
    }

    // Payment mode / reference validation for received and returned
    if (transaction.type == FLTransactionType.received ||
        transaction.type == FLTransactionType.returned) {
      final mode = transaction.paymentMode?.trim().toLowerCase() ?? '';
      if (mode.isEmpty || !FLPaymentMode.all.contains(mode)) {
        return const Left(ValidationFailure(
          message: 'Payment mode is required.',
          field: 'paymentMode',
        ));
      }
    }

    // Utilized: title required
    if (transaction.type == FLTransactionType.utilized) {
      if ((transaction.title?.trim() ?? '').isEmpty) {
        return const Left(ValidationFailure(
          message: 'Title is required for utilization.',
          field: 'title',
        ));
      }
    }

    // Return amount <= Available validation
    if (transaction.type == FLTransactionType.returned) {
      final totalsResult = await _repository.getTotals(transaction.contactId);
      final canContinue = totalsResult.fold(
        (_) => true, // let DB constraints catch it on failure
        (totals) {
          final available =
              FLSummaryCalculator.availableAmount(totals) - transaction.amount;
          return available >= -0.001; // allow floating-point tolerance
        },
      );
      if (!canContinue) {
        return const Left(ValidationFailure(
          message: 'Return amount exceeds the available balance. '
              'Available = Total Received − Total Returned.',
          field: 'amount',
        ));
      }
    }

    final now = DateTime.now();
    final finalTxn = transaction.copyWith(
      id: transaction.id.isEmpty ? const Uuid().v4() : transaction.id,
      createdAt: now,
      updatedAt: now,
    );

    return _repository.insert(finalTxn);
  }
}

// ─── Get Transactions By Contact ─────────────────────────────────────────

class GetFLTransactionsByContactUsecase {
  const GetFLTransactionsByContactUsecase(this._repository);
  final FLTransactionRepository _repository;

  Future<Either<Failure, List<FLTransaction>>> call(String contactId) =>
      _repository.getByContact(contactId);
}

// ─── Get All Transactions (Reports) ─────────────────────────────────────

class GetAllFLTransactionsUsecase {
  const GetAllFLTransactionsUsecase(this._repository);
  final FLTransactionRepository _repository;

  Future<Either<Failure, List<FLTransaction>>> call({
    FLTransactionType? type,
    String? contactId,
    DateTime? from,
    DateTime? to,
  }) =>
      _repository.getAll(
        type: type,
        contactId: contactId,
        from: from,
        to: to,
      );
}

// ─── Delete Transaction ───────────────────────────────────────────────────

class DeleteFLTransactionUsecase {
  const DeleteFLTransactionUsecase(this._repository);
  final FLTransactionRepository _repository;

  Future<Either<Failure, void>> call(String id) => _repository.softDelete(id);
}
