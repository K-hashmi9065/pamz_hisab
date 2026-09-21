import 'package:uuid/uuid.dart';

import '../../../../core/db/hive/hive_registrar.dart';
import '../../../../core/utils/app_date_utils.dart';
import '../models/contact_model.dart';
import 'contact_datasource.dart';

/// Hive datasource for contacts — persists in Hive contactsBox.
class ContactHiveDataSource implements ContactDataSource {
  const ContactHiveDataSource();

  @override
  Future<List<ContactModel>> getAll({String? type}) async {
    final box = HiveRegistrar.contactsBox;
    final List<ContactModel> list = [];

    for (final key in box.keys) {
      final data = box.get(key);
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        final isDeleted = (map['is_deleted'] as int? ?? 0) == 1;
        if (!isDeleted) {
          if (type == null || map['type'] == type) {
            list.add(ContactModel.fromMap(map));
          }
        }
      }
    }

    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  @override
  Future<ContactModel?> findById(String id) async {
    final box = HiveRegistrar.contactsBox;
    final data = box.get(id);
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      final isDeleted = (map['is_deleted'] as int? ?? 0) == 1;
      if (!isDeleted) {
        return ContactModel.fromMap(map);
      }
    }
    return null;
  }

  @override
  Future<bool> existsByMobile(String mobile, {String? excludeId}) async {
    final box = HiveRegistrar.contactsBox;
    for (final key in box.keys) {
      final data = box.get(key);
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        final isDeleted = (map['is_deleted'] as int? ?? 0) == 1;
        if (!isDeleted && map['mobile_number'] == mobile) {
          if (excludeId == null || map['id'] != excludeId) {
            return true;
          }
        }
      }
    }
    return false;
  }

  @override
  Future<void> insert(ContactModel model) async {
    final box = HiveRegistrar.contactsBox;
    await box.put(model.id, model.toMap());

    await HiveRegistrar.auditLogBox.put(const Uuid().v4(), {
      'id': const Uuid().v4(),
      'entity_type': 'contacts',
      'entity_id': model.id,
      'action': 'create',
      'changed_fields_json':
          '{"name":"${model.name}","mobile_number":"${model.mobileNumber}","type":"${model.type}"}',
      'performed_at': AppDateUtils.toIso(DateTime.now()),
    });
  }

  @override
  Future<void> update(ContactModel model) async {
    final box = HiveRegistrar.contactsBox;
    await box.put(model.id, model.toMap());

    await HiveRegistrar.auditLogBox.put(const Uuid().v4(), {
      'id': const Uuid().v4(),
      'entity_type': 'contacts',
      'entity_id': model.id,
      'action': 'update',
      'changed_fields_json':
          '{"name":"${model.name}","mobile_number":"${model.mobileNumber}","credit_limit":${model.creditLimit}}',
      'performed_at': AppDateUtils.toIso(DateTime.now()),
    });
  }

  @override
  Future<void> softDelete(String id) async {
    final box = HiveRegistrar.contactsBox;
    final data = box.get(id);
    if (data is Map) {
      final now = DateTime.now();
      final map = Map<String, dynamic>.from(data);
      map['is_deleted'] = 1;
      map['updated_at'] = AppDateUtils.toIso(now);
      await box.put(id, map);

      await HiveRegistrar.auditLogBox.put(const Uuid().v4(), {
        'id': const Uuid().v4(),
        'entity_type': 'contacts',
        'entity_id': id,
        'action': 'delete',
        'changed_fields_json': null,
        'performed_at': AppDateUtils.toIso(now),
      });
    }
  }

  @override
  Future<double> getTotalBalance(String contactId) async {
    // Udhar Khata loan calculations have been retired. Balance is now
    // tracked exclusively through the Fund Ledger feature.
    return 0.0;
  }
}
