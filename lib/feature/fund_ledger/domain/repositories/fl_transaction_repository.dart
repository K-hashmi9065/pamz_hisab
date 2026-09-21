import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/fl_transaction.dart';

/// Abstract repository contract for Fund Ledger transactions.
abstract interface class FLTransactionRepository {
  /// Returns all non-deleted transactions for [contactId], newest first.
  Future<Either<Failure, List<FLTransaction>>> getByContact(String contactId);

  /// Returns all non-deleted transactions across all contacts,
  /// optionally filtered by [type], newest first.
  Future<Either<Failure, List<FLTransaction>>> getAll({
    FLTransactionType? type,
    String? contactId,
    DateTime? from,
    DateTime? to,
  });

  /// Inserts a new transaction.
  Future<Either<Failure, void>> insert(FLTransaction transaction);

  /// Soft-deletes a transaction.
  Future<Either<Failure, void>> softDelete(String id);

  /// Returns summed totals for a single contact.
  Future<Either<Failure, FLContactTotals>> getTotals(String contactId);

  /// Returns summed totals across ALL contacts.
  Future<Either<Failure, FLContactTotals>> getGlobalTotals();
}

/// Raw totals returned from the repository (no calculation logic here).
class FLContactTotals {
  const FLContactTotals({
    required this.totalReceived,
    required this.totalUtilized,
    required this.totalReturned,
  });

  final double totalReceived;
  final double totalUtilized;
  final double totalReturned;

  factory FLContactTotals.zero() => const FLContactTotals(
        totalReceived: 0,
        totalUtilized: 0,
        totalReturned: 0,
      );
}
