import 'package:uuid/uuid.dart';

import '../../../../core/utils/app_date_utils.dart';
import '../../domain/entities/fl_transaction.dart';

/// Data model for Fund Ledger Transaction — handles DB row ↔ entity mapping.
class FLTransactionModel {
  const FLTransactionModel({
    required this.id,
    required this.contactId,
    required this.type,
    required this.amount,
    required this.txnDate,
    this.txnTime,
    this.paymentMode,
    this.paymentReference,
    this.title,
    this.description,
    this.note,
    required this.createdAt,
    required this.updatedAt,
    required this.isDeleted,
  });

  final String id;
  final String contactId;
  final String type; // 'received' | 'utilized' | 'returned'
  final double amount;
  final String txnDate;
  final String? txnTime;
  final String? paymentMode;
  final String? paymentReference;
  final String? title;
  final String? description;
  final String? note;
  final String createdAt;
  final String updatedAt;
  final bool isDeleted;

  /// Converts a DB row map to a [FLTransactionModel].
  factory FLTransactionModel.fromMap(Map<String, dynamic> map) {
    return FLTransactionModel(
      id: map['id'] as String,
      contactId: map['contact_id'] as String,
      type: map['type'] as String,
      amount: (map['amount'] as num).toDouble(),
      txnDate: map['txn_date'] as String,
      txnTime: map['txn_time'] as String?,
      paymentMode: map['payment_mode'] as String?,
      paymentReference: map['payment_reference'] as String?,
      title: map['title'] as String?,
      description: map['description'] as String?,
      note: map['note'] as String?,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
      isDeleted: (map['is_deleted'] as int? ?? 0) == 1,
    );
  }

  /// Converts to a DB row map for insert/update.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'contact_id': contactId,
      'type': type,
      'amount': amount,
      'txn_date': txnDate,
      'txn_time': txnTime,
      'payment_mode': paymentMode,
      'payment_reference': paymentReference,
      'title': title,
      'description': description,
      'note': note,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'is_deleted': isDeleted ? 1 : 0,
    };
  }

  /// Converts to the domain [FLTransaction] entity.
  FLTransaction toEntity() {
    return FLTransaction(
      id: id,
      contactId: contactId,
      type: FLTransactionType.fromDb(type),
      amount: amount,
      txnDate: txnDate,
      txnTime: txnTime,
      paymentMode: paymentMode,
      paymentReference: paymentReference,
      title: title,
      description: description,
      note: note,
      createdAt: AppDateUtils.parseIso(createdAt) ?? DateTime.now(),
      updatedAt: AppDateUtils.parseIso(updatedAt) ?? DateTime.now(),
      isDeleted: isDeleted,
    );
  }

  /// Creates a [FLTransactionModel] from a domain [FLTransaction] entity.
  factory FLTransactionModel.fromEntity(FLTransaction txn) {
    return FLTransactionModel(
      id: txn.id.isEmpty ? const Uuid().v4() : txn.id,
      contactId: txn.contactId,
      type: txn.type.dbValue,
      amount: txn.amount,
      txnDate: txn.txnDate,
      txnTime: txn.txnTime,
      paymentMode: txn.paymentMode,
      paymentReference: txn.paymentReference,
      title: txn.title,
      description: txn.description,
      note: txn.note,
      createdAt: AppDateUtils.toIso(txn.createdAt),
      updatedAt: AppDateUtils.toIso(txn.updatedAt),
      isDeleted: txn.isDeleted,
    );
  }

  FLTransactionModel copyWith({
    String? id,
    String? contactId,
    String? type,
    double? amount,
    String? txnDate,
    String? txnTime,
    String? paymentMode,
    String? paymentReference,
    String? title,
    String? description,
    String? note,
    String? createdAt,
    String? updatedAt,
    bool? isDeleted,
  }) {
    return FLTransactionModel(
      id: id ?? this.id,
      contactId: contactId ?? this.contactId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      txnDate: txnDate ?? this.txnDate,
      txnTime: txnTime ?? this.txnTime,
      paymentMode: paymentMode ?? this.paymentMode,
      paymentReference: paymentReference ?? this.paymentReference,
      title: title ?? this.title,
      description: description ?? this.description,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}
