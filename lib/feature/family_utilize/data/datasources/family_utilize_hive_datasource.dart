import 'package:hive/hive.dart';

import '../../../../core/db/audit/audit_logger.dart';
import '../../../../core/db/hive/hive_registrar.dart';
import '../../../../core/utils/app_date_utils.dart';
import '../models/family_utilize_model.dart';
import 'family_utilize_datasource.dart';

/// Hive datasource for Family Utilizations.
class FamilyUtilizeHiveDataSource implements FamilyUtilizeDataSource {
  const FamilyUtilizeHiveDataSource();

  Box<dynamic> get _box => HiveRegistrar.familyUtilizationsBox;

  List<FamilyUtilizeModel> _active() {
    return _box.values
        .whereType<Map>()
        .map((m) => FamilyUtilizeModel.fromMap(Map<String, dynamic>.from(m)))
        .where((t) => !t.isDeleted)
        .toList();
  }

  @override
  Future<List<FamilyUtilizeModel>> getAll({
    String? category,
    String? fromDate,
    String? toDate,
    String? searchQuery,
  }) async {
    var result = _active();

    if (category != null && category.isNotEmpty) {
      result = result
          .where((t) => t.category.toLowerCase() == category.toLowerCase())
          .toList();
    }
    if (fromDate != null) {
      result =
          result.where((t) => t.transactionDate.compareTo(fromDate) >= 0).toList();
    }
    if (toDate != null) {
      result =
          result.where((t) => t.transactionDate.compareTo(toDate) <= 0).toList();
    }
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.trim().toLowerCase();
      result = result.where((t) {
        return t.title.toLowerCase().contains(q) ||
            t.category.toLowerCase().contains(q) ||
            (t.paidTo?.toLowerCase().contains(q) ?? false) ||
            (t.description?.toLowerCase().contains(q) ?? false) ||
            (t.mobileNumber?.toLowerCase().contains(q) ?? false) ||
            (t.paymentMode?.toLowerCase().contains(q) ?? false) ||
            (t.paymentReference?.toLowerCase().contains(q) ?? false) ||
            t.amount.toString().contains(q);
      }).toList();
    }

    result.sort((a, b) {
      final dateCmp = b.transactionDate.compareTo(a.transactionDate);
      if (dateCmp != 0) return dateCmp;
      return b.createdAt.compareTo(a.createdAt);
    });

    return result;
  }

  @override
  Future<FamilyUtilizeModel?> getById(String id) async {
    final raw = _box.get(id);
    if (raw == null) return null;
    final model =
        FamilyUtilizeModel.fromMap(Map<String, dynamic>.from(raw as Map));
    return model.isDeleted ? null : model;
  }

  @override
  Future<void> insert(FamilyUtilizeModel model) async {
    await _box.put(model.id, model.toMap());
    await AuditLogger.record(
      entityType: 'family_utilizations',
      entityId: model.id,
      action: 'create',
      metadata: {
        'category': model.category,
        'title': model.title,
        'amount': model.amount,
        'paid_to': model.paidTo,
      },
    );
  }

  @override
  Future<void> update(FamilyUtilizeModel model) async {
    await _box.put(model.id, model.toMap());
    await AuditLogger.record(
      entityType: 'family_utilizations',
      entityId: model.id,
      action: 'update',
      metadata: {
        'category': model.category,
        'title': model.title,
        'amount': model.amount,
      },
    );
  }

  @override
  Future<void> softDelete(String id) async {
    final raw = _box.get(id);
    if (raw == null) return;
    final map = Map<String, dynamic>.from(raw as Map);
    map['is_deleted'] = 1;
    map['updated_at'] = AppDateUtils.toIso(DateTime.now());
    await _box.put(id, map);
    await AuditLogger.record(
      entityType: 'family_utilizations',
      entityId: id,
      action: 'delete',
    );
  }

  @override
  Future<double> getTotalFamilyUtilized({
    String? fromDate,
    String? toDate,
  }) async {
    var items = _active();
    if (fromDate != null) {
      items =
          items.where((t) => t.transactionDate.compareTo(fromDate) >= 0).toList();
    }
    if (toDate != null) {
      items =
          items.where((t) => t.transactionDate.compareTo(toDate) <= 0).toList();
    }
    return items.fold<double>(0.0, (sum, item) => sum + item.amount);
  }
}
