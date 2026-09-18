import '../../../../core/db/hive/hive_registrar.dart';
import '../../../../core/db/sqlite/app_database.dart';
import '../../../../core/db/sqlite/database_helper.dart';
import '../../../../core/db/storage_config.dart';

class AuditLogEntry {
  const AuditLogEntry({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.action,
    this.changedFieldsJson,
    required this.performedAt,
  });

  final String id;
  final String entityType;
  final String entityId;
  final String action; // 'create', 'update', 'delete'
  final String? changedFieldsJson;
  final DateTime performedAt;

  factory AuditLogEntry.fromMap(Map<String, dynamic> map) {
    return AuditLogEntry(
      id: map['id'] as String? ?? '',
      entityType: map['entity_type'] as String? ?? 'unknown',
      entityId: map['entity_id'] as String? ?? '',
      action: map['action'] as String? ?? 'update',
      changedFieldsJson: map['changed_fields_json'] as String?,
      performedAt: DateTime.tryParse(map['performed_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'entity_type': entityType,
      'entity_id': entityId,
      'action': action,
      'changed_fields_json': changedFieldsJson,
      'performed_at': performedAt.toIso8601String(),
    };
  }
}

abstract class AuditLogRepository {
  Future<List<AuditLogEntry>> getAuditLogs();
}

class AuditLogRepositoryImpl implements AuditLogRepository {
  final DatabaseHelper? _dbHelper;
  const AuditLogRepositoryImpl([this._dbHelper]);

  DatabaseHelper get _helper =>
      _dbHelper ?? DatabaseHelper(AppDatabase.instance);

  @override
  Future<List<AuditLogEntry>> getAuditLogs() async {
    if (AppStorageConfig.isHive) {
      final box = HiveRegistrar.auditLogBox;
      final List<AuditLogEntry> list = [];

      for (final key in box.keys) {
        final data = box.get(key);
        if (data is Map) {
          list.add(AuditLogEntry.fromMap(Map<String, dynamic>.from(data)));
        }
      }

      list.sort((a, b) => b.performedAt.compareTo(a.performedAt));
      return list;
    } else {
      final rows = await _helper.query(
        'audit_log',
        orderBy: 'performed_at DESC',
      );
      return rows.map((r) => AuditLogEntry.fromMap(r)).toList();
    }
  }
}
