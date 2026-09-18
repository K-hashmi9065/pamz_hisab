import 'package:flutter/foundation.dart';

/// Enum representing available local storage backends.
enum StorageType {
  hive,
  sqlite,
}

/// Global configuration for selecting the active storage engine.
/// Defaults to [StorageType.sqlite] on native platforms and [StorageType.hive] on Web.
class AppStorageConfig {
  AppStorageConfig._();

  /// Active storage engine: [StorageType.hive] on web, and [StorageType.sqlite] on native platforms.
  static StorageType current =
      kIsWeb ? StorageType.hive : StorageType.sqlite;

  static bool get isHive => current == StorageType.hive;
  static bool get isSqlite => current == StorageType.sqlite;
}
