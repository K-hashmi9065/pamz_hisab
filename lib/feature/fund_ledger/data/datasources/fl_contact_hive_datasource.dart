import 'package:hive/hive.dart';

import '../../../../core/db/hive/hive_registrar.dart';
import '../../../../core/utils/app_date_utils.dart';
import '../models/fl_contact_model.dart';
import 'fl_contact_datasource.dart';

/// Hive datasource for Fund Ledger contacts.
/// Stores records as Map<String, dynamic> keyed by contact ID.
class FLContactHiveDataSource implements FLContactDataSource {
  const FLContactHiveDataSource();

  Box<dynamic> get _box => HiveRegistrar.flContactsBox;

  @override
  Future<List<FLContactModel>> getAll() async {
    final all = _box.values
        .whereType<Map>()
        .map((m) => FLContactModel.fromMap(Map<String, dynamic>.from(m)))
        .where((c) => !c.isDeleted)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return all;
  }

  @override
  Future<FLContactModel?> findById(String id) async {
    final raw = _box.get(id);
    if (raw == null) return null;
    final model = FLContactModel.fromMap(Map<String, dynamic>.from(raw as Map));
    return model.isDeleted ? null : model;
  }

  @override
  Future<bool> existsByMobile(String mobile, {String? excludeId}) async {
    return _box.values.whereType<Map>().any((m) {
      final model = FLContactModel.fromMap(Map<String, dynamic>.from(m));
      if (model.isDeleted) return false;
      if (excludeId != null && model.id == excludeId) return false;
      return model.mobileNumber == mobile;
    });
  }

  @override
  Future<void> insert(FLContactModel model) async {
    await _box.put(model.id, model.toMap());
  }

  @override
  Future<void> update(FLContactModel model) async {
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
}
