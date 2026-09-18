import 'package:flutter_test/flutter_test.dart';
import 'package:pamz_khata/core/utils/phone_validator.dart';

void main() {
  group('PhoneValidator Unit Tests', () {
    test('isValidIndianMobile verifies 10-digit numbers starting with 6-9', () {
      expect(PhoneValidator.isValidIndianMobile('9876543210'), isTrue);
      expect(PhoneValidator.isValidIndianMobile('8123456789'), isTrue);
      expect(PhoneValidator.isValidIndianMobile('7000000000'), isTrue);
      expect(PhoneValidator.isValidIndianMobile('6999999999'), isTrue);

      // Invalid start digit
      expect(PhoneValidator.isValidIndianMobile('5876543210'), isFalse);
      expect(PhoneValidator.isValidIndianMobile('1234567890'), isFalse);
      expect(PhoneValidator.isValidIndianMobile('0987654321'), isFalse);

      // Invalid length
      expect(PhoneValidator.isValidIndianMobile('987654321'), isFalse);
      expect(PhoneValidator.isValidIndianMobile('98765432100'), isFalse);
      expect(PhoneValidator.isValidIndianMobile(''), isFalse);
    });

    test('validate returns error message or null for form validation', () {
      expect(PhoneValidator.validate(null), 'Mobile number is required');
      expect(PhoneValidator.validate(''), 'Mobile number is required');
      expect(PhoneValidator.validate('   '), 'Mobile number is required');
      expect(PhoneValidator.validate('12345'), contains('Enter a valid 10-digit Indian mobile number'));
      expect(PhoneValidator.validate('9876543210'), isNull);
    });

    test('normalize removes spaces, dashes, and +91/91 prefix', () {
      expect(PhoneValidator.normalize('98765 43210'), '9876543210');
      expect(PhoneValidator.normalize('98765-43210'), '9876543210');
      expect(PhoneValidator.normalize('+919876543210'), '9876543210');
      expect(PhoneValidator.normalize('919876543210'), '9876543210');
    });
  });
}
