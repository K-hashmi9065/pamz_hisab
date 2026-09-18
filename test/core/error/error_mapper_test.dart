import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:pamz_khata/core/error/error_mapper.dart';
import 'package:pamz_khata/core/error/failure.dart';

void main() {
  setUpAll(() {
    Logger.level = Level.off;
  });

  group('ErrorMapper', () {
    test('maps UNIQUE constraint error to DuplicatePhoneFailure when mobile_number in message', () {
      final failure = ErrorMapper.map(
        Exception('UNIQUE constraint failed: contacts.mobile_number'),
      );
      expect(failure, isA<DuplicatePhoneFailure>());
    });

    test('maps UNIQUE constraint without mobile_number to DatabaseFailure', () {
      final failure = ErrorMapper.map(
        Exception('UNIQUE constraint failed: contacts.name'),
      );
      expect(failure, isA<DatabaseFailure>());
    });

    test('DuplicatePhoneFailure message does not expose the raw constraint detail', () {
      final failure = ErrorMapper.map(
        Exception('UNIQUE constraint failed: contacts.mobile_number'),
      );
      expect(failure.message, isNot(contains('UNIQUE constraint')));
    });

    test('maps unknown exception to UnknownFailure', () {
      final failure = ErrorMapper.map(Exception('some internal detail'));
      expect(failure, isA<UnknownFailure>());
    });

    test('UnknownFailure message is generic and does not expose raw exception', () {
      final failure = ErrorMapper.map(Exception('some internal detail'));
      expect(failure.message, 'Something went wrong. Please try again.');
      expect(failure.message, isNot(contains('some internal detail')));
    });

    test('maps "database is locked" to DatabaseFailure with busy-friendly message', () {
      final failure = ErrorMapper.map(Exception('database is locked'));
      expect(failure, isA<DatabaseFailure>());
      expect(failure.message, contains('busy'));
    });

    test('maps FormatException to ValidationFailure', () {
      final failure = ErrorMapper.map(const FormatException('bad format'));
      expect(failure, isA<ValidationFailure>());
    });

    test('ValidationFailure has a user-friendly message', () {
      final failure = ErrorMapper.map(const FormatException('bad format'));
      expect(failure.message, isNotEmpty);
      expect(failure.message, isNot(contains('bad format')));
    });

    test('technicalDetail is captured for debugging', () {
      final failure = ErrorMapper.map(Exception('debug info'));
      expect(failure.technicalDetail, isNotNull);
    });
  });
}
