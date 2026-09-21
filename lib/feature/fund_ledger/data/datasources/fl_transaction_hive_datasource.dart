import 'package:hive/hive.dart';

import '../../../../core/db/hive/hive_registrar.dart';
import '../../../../core/utils/app_date_utils.dart';
import '../../domain/entities/fl_transaction.dart';
import '../../domain/repositories/fl_transaction_repository.dart';
import '../models/fl_transaction_model.dart';
import 'fl_transaction_datasource.dart';

/// Hive datasource for Fund Ledger transactions.
/// Stores records as Map<String, dynamic> keyed by transaction ID.
class FLTransactionHiveDataSource implements FLTransactionDataSource {
  const FLTransactionHiveDataSource();

  Box<dynamic> get _box => HiveRegistrar.flTransactionsBox;

  List<FLTransactionModel> _active() {
    return _box.values
        .whereType<Map>()
        .map((m) => FLTransactionModel.fromMap(Map<String, dynamic>.from(m)))
        .where((t) => !t.isDeleted)
        .toList();
  }

  @override
  Future<List<FLTransactionModel>> getByContact(String contactId) async {
    final result = _active()
        .where((t) => t.contactId == contactId)
        .toList()
      ..sort((a, b) {
        final dateCmp = b.txnDate.compareTo(a.txnDate);
        if (dateCmp != 0) return dateCmp;
        return b.createdAt.compareTo(a.createdAt);
      });
    return result;
  }

  @override
  Future<List<FLTransactionModel>> getAll({
    FLTransactionType? type,
    String? contactId,
    String? fromDate,
    String? toDate,
  }) async {
    var result = _active();

    if (type != null) result = result.where((t) => t.type == type.dbValue).toList();
    if (contactId != null) result = result.where((t) => t.contactId == contactId).toList();
    if (fromDate != null) result = result.where((t) => t.txnDate.compareTo(fromDate) >= 0).toList();
    if (toDate != null) result = result.where((t) => t.txnDate.compareTo(toDate) <= 0).toList();

    result.sort((a, b) {
      final dateCmp = b.txnDate.compareTo(a.txnDate);
      if (dateCmp != 0) return dateCmp;
      return b.createdAt.compareTo(a.createdAt);
    });

    return result;
  }

  @override
  Future<void> insert(FLTransactionModel model) async {
    await _box.put(model.id, model.toMap());
  }

  @override
  Future<void> softDelete(String id) async {
    final raw = _box.get(id);
    if (raw == null) return;
    final map = Map<String, dynamic>.from(raw as Map);
    map['is_deleted'] = 1;
    map['updated_at'] = AppDateUtils.toIso(DateTime.now());
    await _box.put(id, map);
  }

  @override
  Future<FLContactTotals> getTotals(String contactId) async {
    final txns = _active().where((t) => t.contactId == contactId);
    return _aggregate(txns.toList());
  }

  @override
  Future<FLContactTotals> getGlobalTotals() async {
    return _aggregate(_active());
  }

  FLContactTotals _aggregate(List<FLTransactionModel> txns) {
    double received = 0, utilized = 0, returned = 0;
    for (final t in txns) {
      switch (t.type) {
        case 'received':
          received += t.amount;
        case 'utilized':
          utilized += t.amount;
        case 'returned':
          returned += t.amount;
      }
    }
    return FLContactTotals(
      totalReceived: received,
      totalUtilized: utilized,
      totalReturned: returned,
    );
  }
}
