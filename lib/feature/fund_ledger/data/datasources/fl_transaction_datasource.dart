import '../models/fl_transaction_model.dart';
import '../../domain/entities/fl_transaction.dart';
import '../../domain/repositories/fl_transaction_repository.dart';

/// Abstract datasource interface for Fund Ledger transactions.
abstract interface class FLTransactionDataSource {
  /// Returns all non-deleted transactions for a contact, newest first.
  Future<List<FLTransactionModel>> getByContact(String contactId);

  /// Returns non-deleted transactions with optional filters.
  Future<List<FLTransactionModel>> getAll({
    FLTransactionType? type,
    String? contactId,
    String? fromDate,
    String? toDate,
  });

  /// Inserts a new transaction.
  Future<void> insert(FLTransactionModel model);

  /// Soft-deletes a transaction.
  Future<void> softDelete(String id);

  /// Returns aggregated totals for a contact (sum queries).
  Future<FLContactTotals> getTotals(String contactId);

  /// Returns aggregated totals across all contacts.
  Future<FLContactTotals> getGlobalTotals();
}
