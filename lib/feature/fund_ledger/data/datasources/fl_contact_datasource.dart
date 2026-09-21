import '../models/fl_contact_model.dart';

/// Abstract datasource interface for Fund Ledger contacts.
abstract interface class FLContactDataSource {
  Future<List<FLContactModel>> getAll();
  Future<FLContactModel?> findById(String id);
  Future<bool> existsByMobile(String mobile, {String? excludeId});
  Future<void> insert(FLContactModel model);
  Future<void> update(FLContactModel model);
  Future<void> softDelete(String id);
}
