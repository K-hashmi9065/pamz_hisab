import 'package:uuid/uuid.dart';

import '../../../../core/utils/app_date_utils.dart';
import '../../domain/entities/fl_contact.dart';

/// Data model for Fund Ledger Contact — handles DB row ↔ entity mapping.
class FLContactModel {
  const FLContactModel({
    required this.id,
    required this.name,
    required this.mobileNumber,
    this.aadhaarNumber,
    this.project,
    required this.createdAt,
    required this.updatedAt,
    required this.isDeleted,
  });

  final String id;
  final String name;
  final String mobileNumber;
  final String? aadhaarNumber;
  final String? project;
  final String createdAt;
  final String updatedAt;
  final bool isDeleted;

  /// Converts a DB row map to a [FLContactModel].
  factory FLContactModel.fromMap(Map<String, dynamic> map) {
    return FLContactModel(
      id: map['id'] as String,
      name: map['name'] as String,
      mobileNumber: map['mobile_number'] as String,
      aadhaarNumber: map['aadhaar_number'] as String?,
      project: map['project'] as String?,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
      isDeleted: (map['is_deleted'] as int? ?? 0) == 1,
    );
  }

  /// Converts to a DB row map for insert/update.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'mobile_number': mobileNumber,
      'aadhaar_number': aadhaarNumber,
      'project': project,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'is_deleted': isDeleted ? 1 : 0,
    };
  }

  /// Converts to the domain [FLContact] entity.
  FLContact toEntity() {
    return FLContact(
      id: id,
      name: name,
      mobileNumber: mobileNumber,
      aadhaarNumber: aadhaarNumber,
      project: project,
      createdAt: AppDateUtils.parseIso(createdAt) ?? DateTime.now(),
      updatedAt: AppDateUtils.parseIso(updatedAt) ?? DateTime.now(),
      isDeleted: isDeleted,
    );
  }

  /// Creates a [FLContactModel] from a domain [FLContact] entity.
  factory FLContactModel.fromEntity(FLContact contact) {
    return FLContactModel(
      id: contact.id.isEmpty ? const Uuid().v4() : contact.id,
      name: contact.name,
      mobileNumber: contact.mobileNumber,
      aadhaarNumber: contact.aadhaarNumber,
      project: contact.project,
      createdAt: AppDateUtils.toIso(contact.createdAt),
      updatedAt: AppDateUtils.toIso(contact.updatedAt),
      isDeleted: contact.isDeleted,
    );
  }

  FLContactModel copyWith({
    String? id,
    String? name,
    String? mobileNumber,
    String? aadhaarNumber,
    String? project,
    String? createdAt,
    String? updatedAt,
    bool? isDeleted,
  }) {
    return FLContactModel(
      id: id ?? this.id,
      name: name ?? this.name,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      aadhaarNumber: aadhaarNumber ?? this.aadhaarNumber,
      project: project ?? this.project,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}
