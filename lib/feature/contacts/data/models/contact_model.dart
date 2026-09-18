import 'package:uuid/uuid.dart';

import '../../../../core/utils/app_date_utils.dart';
import '../../domain/entities/contact.dart';

/// Data Transfer Object for Contact — handles DB row ↔ entity mapping.
class ContactModel {
  const ContactModel({
    required this.id,
    required this.type,
    required this.name,
    required this.mobileNumber,
    this.address,
    this.villageTola,
    this.shopLocation,
    required this.creditLimit,
    required this.dueDateAlertEnabled,
    required this.createdAt,
    required this.updatedAt,
    required this.isDeleted,
  });

  final String id;
  final String type;
  final String name;
  final String mobileNumber;
  final String? address;
  final String? villageTola;
  final String? shopLocation;
  final double creditLimit;
  final bool dueDateAlertEnabled;
  final String createdAt;
  final String updatedAt;
  final bool isDeleted;

  /// Converts a DB row map to a [ContactModel].
  factory ContactModel.fromMap(Map<String, dynamic> map) {
    return ContactModel(
      id: map['id'] as String,
      type: map['type'] as String,
      name: map['name'] as String,
      mobileNumber: map['mobile_number'] as String,
      address: map['address'] as String?,
      villageTola: map['village_tola'] as String?,
      shopLocation: map['shop_location'] as String?,
      creditLimit: (map['credit_limit'] as num?)?.toDouble() ?? 0,
      dueDateAlertEnabled: (map['due_date_alert_enabled'] as int? ?? 0) == 1,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
      isDeleted: (map['is_deleted'] as int? ?? 0) == 1,
    );
  }

  /// Converts to a DB row map for insert/update.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'name': name,
      'mobile_number': mobileNumber,
      'address': address,
      'village_tola': villageTola,
      'shop_location': shopLocation,
      'credit_limit': creditLimit,
      'due_date_alert_enabled': dueDateAlertEnabled ? 1 : 0,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'is_deleted': isDeleted ? 1 : 0,
    };
  }

  /// Converts to a domain [Contact] entity.
  Contact toEntity() {
    return Contact(
      id: id,
      type: type == 'buyer' ? ContactType.buyer : ContactType.supplier,
      name: name,
      mobileNumber: mobileNumber,
      address: address,
      villageTola: villageTola,
      shopLocation: shopLocation,
      creditLimit: creditLimit,
      dueDateAlertEnabled: dueDateAlertEnabled,
      createdAt: AppDateUtils.parseIso(createdAt) ?? DateTime.now(),
      updatedAt: AppDateUtils.parseIso(updatedAt) ?? DateTime.now(),
      isDeleted: isDeleted,
    );
  }

  /// Creates a [ContactModel] from a domain [Contact] entity.
  factory ContactModel.fromEntity(Contact contact) {
    final now = AppDateUtils.toIso(DateTime.now());
    return ContactModel(
      id: contact.id.isEmpty ? const Uuid().v4() : contact.id,
      type: contact.type.name,
      name: contact.name,
      mobileNumber: contact.mobileNumber,
      address: contact.address,
      villageTola: contact.villageTola,
      shopLocation: contact.shopLocation,
      creditLimit: contact.creditLimit,
      dueDateAlertEnabled: contact.dueDateAlertEnabled,
      createdAt: AppDateUtils.toIso(contact.createdAt),
      updatedAt: now,
      isDeleted: contact.isDeleted,
    );
  }
}
