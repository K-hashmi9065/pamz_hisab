import '../models/contact_model.dart';

/// Abstract datasource contract for contacts (implemented by SQLite and Hive).
abstract class ContactDataSource {
  Future<List<ContactModel>> getAll({String? type});
  Future<ContactModel?> findById(String id);
  Future<bool> existsByMobile(String mobile, {String? excludeId});
  Future<void> insert(ContactModel model);
  Future<void> update(ContactModel model);
  Future<void> softDelete(String id);
  Future<double> getTotalBalance(String contactId);
}
