import 'dart:math';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/app_constants.dart';

/// Manages the SQLCipher database encryption key.
/// The key is generated on first launch and stored in iOS Keychain
/// via flutter_secure_storage. Never stored in Hive or plaintext.
class EncryptionKeyManager {
  final FlutterSecureStorage _storage;

  EncryptionKeyManager({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  /// Returns the existing DB encryption key, or generates and stores one.
  Future<String> getOrCreateKey() async {
    final existing = await _storage.read(
      key: AppConstants.dbEncryptionKeyStorageKey,
    );
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final newKey = _generateKey();
    await _storage.write(
      key: AppConstants.dbEncryptionKeyStorageKey,
      value: newKey,
    );
    return newKey;
  }

  /// Deletes the key — use only on app reset/wipe. This renders the DB unreadable!
  Future<void> deleteKey() async {
    await _storage.delete(key: AppConstants.dbEncryptionKeyStorageKey);
  }

  static String _generateKey() {
    final rng = Random.secure();
    final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
    return base64Url.encode(bytes);
  }
}
