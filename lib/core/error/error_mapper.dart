import 'package:flutter/services.dart';
import 'package:logger/logger.dart';

import 'failure.dart';

final _log = Logger();

/// Maps raw platform/library exceptions → user-friendly [Failure] values.
/// Technical details are logged but NEVER surfaced in Failure.message.
abstract final class ErrorMapper {
  ErrorMapper._();

  static Failure map(Object error, [StackTrace? st]) {
    _log.e('ErrorMapper caught', error: error, stackTrace: st);

    // SQLite DatabaseException — check message string (class is abstract in sqflite)
    final errStr = error.toString().toLowerCase();

    if (errStr.contains('unique constraint') ||
        errStr.contains('unique_constraint')) {
      if (errStr.contains('mobile_number')) {
        return DuplicatePhoneFailure(technicalDetail: error.toString());
      }
      return DatabaseFailure(
        message: 'A duplicate entry already exists.',
        technicalDetail: error.toString(),
      );
    }

    if (errStr.contains('database is locked') ||
        errStr.contains('database_is_locked') ||
        errStr.contains('database is busy')) {
      return const DatabaseFailure(
        message: 'The app is busy. Please wait a moment and try again.',
      );
    }

    if (errStr.contains('database') ||
        errStr.contains('sqflite') ||
        errStr.contains('sqlite')) {
      return DatabaseFailure(technicalDetail: error.toString());
    }

    if (error is FormatException) {
      return ValidationFailure(
        message: 'Invalid input format. Please check your entries.',
        technicalDetail: error.message,
      );
    }

    if (error is PlatformException) {
      final code = error.code.toLowerCase();
      if (code.contains('auth_failed') || code.contains('biometric')) {
        return BiometricFailure(technicalDetail: '${error.code}: ${error.message}');
      }
      return UnknownFailure(technicalDetail: '${error.code}: ${error.message}');
    }

    return UnknownFailure(technicalDetail: error.toString());
  }
}
