import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Service for managing persistent storage of Family Expense receipt photos (FR-FE-002).
///
/// Ensures receipt photos are copied from temporary/cache directories (e.g. from ImagePicker)
/// into persistent app-private storage (Documents/receipts), and handles safe deletion
/// upon replacement or removal.
class ReceiptStorageService {
  const ReceiptStorageService({this.baseDirectoryProvider});

  /// Optional directory provider override for testing.
  final Future<Directory> Function()? baseDirectoryProvider;

  /// Returns the persistent directory where receipts are stored.
  Future<Directory> getReceiptsDirectory() async {
    final baseDir = baseDirectoryProvider != null
        ? await baseDirectoryProvider!()
        : await getApplicationDocumentsDirectory();

    final receiptsDir = Directory(p.join(baseDir.path, 'receipts'));
    if (!await receiptsDir.exists()) {
      await receiptsDir.create(recursive: true);
    }
    return receiptsDir;
  }

  /// Copies an image file from [sourcePath] into persistent storage.
  /// Returns the absolute path of the persisted image file.
  Future<String> persistReceiptImage(String sourcePath) async {
    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      throw FileSystemException('Source receipt image not found', sourcePath);
    }

    final receiptsDir = await getReceiptsDirectory();
    final ext = p.extension(sourcePath).toLowerCase();
    final validExt = ext.isNotEmpty ? ext : '.jpg';
    final fileName = 'receipt_${const Uuid().v4()}$validExt';
    final targetPath = p.join(receiptsDir.path, fileName);

    final targetFile = await sourceFile.copy(targetPath);
    return targetFile.path;
  }

  /// Safely deletes a persisted receipt image file at [filePath] if it exists.
  Future<void> deleteReceiptImage(String? filePath) async {
    if (filePath == null || filePath.trim().isEmpty) return;
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Gracefully ignore deletion failures
    }
  }

  /// Replaces an existing receipt by persisting [newSourcePath] first,
  /// and then deleting [oldPersistentPath] upon successful persistence.
  Future<String> replaceReceiptImage({
    required String newSourcePath,
    String? oldPersistentPath,
  }) async {
    final newPersistentPath = await persistReceiptImage(newSourcePath);

    if (oldPersistentPath != null &&
        oldPersistentPath.isNotEmpty &&
        oldPersistentPath != newPersistentPath) {
      await deleteReceiptImage(oldPersistentPath);
    }

    return newPersistentPath;
  }
}
