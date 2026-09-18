import 'package:uuid/uuid.dart';

import '../../../../core/db/hive/hive_registrar.dart';
import '../../../../core/utils/app_date_utils.dart';
import '../../../direct_udhar/data/models/direct_udhar_models.dart';
import '../../../direct_udhar/domain/entities/direct_udhar_loan.dart';
import '../../../direct_udhar/domain/services/interest_calculator.dart';
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
    final loanBox = HiveRegistrar.directUdharBox;
    final repBox = HiveRegistrar.repaymentsBox;
    final now = DateTime.now();
    double net = 0.0;

    for (final key in loanBox.keys) {
      final data = loanBox.get(key);
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        final isDeleted = (map['is_deleted'] as int? ?? 0) == 1;
        final isClosed = map['status'] == 'closed';
        if (!isDeleted && !isClosed && map['contact_id'] == contactId) {
          final loan = DirectUdharLoanModel.fromMap(map).toEntity();

          // Fetch repayments for this loan from Hive
          final List<Repayment> repayments = [];
          for (final repKey in repBox.keys) {
            final repData = repBox.get(repKey);
            if (repData is Map) {
              final repMap = Map<String, dynamic>.from(repData);
              final repDeleted = (repMap['is_deleted'] as int? ?? 0) == 1;
              if (!repDeleted &&
                  repMap['source_type'] == 'direct_udhar' &&
                  repMap['source_id'] == loan.id) {
                repayments.add(RepaymentModel.fromMap(repMap).toEntity());
              }
            }
          }

          final summary = InterestCalculator.calculateSummary(
            loan: loan,
            repayments: repayments,
            asOfDate: now,
          );

          if (loan.direction == LoanDirection.lent) {
            net += summary.totalOutstanding;
          } else {
            net -= summary.totalOutstanding;
          }
        }
      }
    }
    return net;
  }
}
