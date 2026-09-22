import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../hive/hive_registrar.dart';
import '../sqlite/database_helper.dart';
import '../sqlite/app_database.dart';
import '../storage_config.dart';

/// Persists mutation history for both supported local storage backends.
abstract final class AuditLogger {
  static Future<void> record({
    required String entityType,
    required String entityId,
    required String action,
    Map<String, dynamic>? metadata,
  }) async {
    final performedAt = DateTime.now().toIso8601String();
    final values = <String, dynamic>{
      'id': const Uuid().v4(),
      'entity_type': entityType,
      'entity_id': entityId,
      'action': action,
      'changed_fields_json': metadata == null ? null : jsonEncode(metadata),
      'performed_at': performedAt,
    };

    if (AppStorageConfig.isHive) {
      await HiveRegistrar.auditLogBox.put(values['id'], values);
      return;
    }

    await DatabaseHelper(AppDatabase.instance).insert('audit_log', values);
  }
}
