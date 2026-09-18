import 'package:flutter_test/flutter_test.dart';
import 'package:pamz_khata/core/utils/currency_formatter.dart';
import 'package:pamz_khata/core/utils/phone_validator.dart';

void main() {
  // ─── CurrencyFormatter ────────────────────────────────────────────────

  group('CurrencyFormatter.formatIndian', () {
    test('formats below 1,000 with no grouping', () {
      expect(CurrencyFormatter.formatIndian(500), '₹500');
    });

    test('formats exactly 1,000', () {
      expect(CurrencyFormatter.formatIndian(1000), '₹1,000');
    });

    test('formats below 1 lakh with standard grouping', () {
      expect(CurrencyFormatter.formatIndian(45000), '₹45,000');
    });

    test('formats 1 lakh with Indian grouping', () {
      expect(CurrencyFormatter.formatIndian(100000), '₹1,00,000');
    });

    test('formats 1.5 lakh using Lakhs grouping', () {
      expect(CurrencyFormatter.formatIndian(150000), '₹1,50,000');
    });

    test('formats 1 crore using Crores grouping', () {
      expect(CurrencyFormatter.formatIndian(10000000), '₹1,00,00,000');
    });

    test('formats 1.25 crore', () {
      expect(CurrencyFormatter.formatIndian(12500000), '₹1,25,00,000');
    });

    test('formats negative amounts with leading minus', () {
      expect(CurrencyFormatter.formatIndian(-2000), '-₹2,000');
    });

    test('formats zero', () {
      expect(CurrencyFormatter.formatIndian(0), '₹0');
    });

    test('includes + prefix when showSign=true and amount > 0', () {
      expect(CurrencyFormatter.formatIndian(1000, showSign: true), '+₹1,000');
    });

    test('no + prefix for zero even with showSign=true', () {
      expect(CurrencyFormatter.formatIndian(0, showSign: true), '₹0');
    });
  });

  group('CurrencyFormatter.formatCompact', () {
    test('formats amounts under 1K without abbreviation', () {
      expect(CurrencyFormatter.formatCompact(999), '₹999');
    });

    test('formats 1500 as 1.5K', () {
      expect(CurrencyFormatter.formatCompact(1500), '₹1.5K');
    });

    test('formats 150000 as 1.5L', () {
      expect(CurrencyFormatter.formatCompact(150000), '₹1.5L');
    });

    test('formats 15000000 as 1.5Cr', () {
      expect(CurrencyFormatter.formatCompact(15000000), '₹1.5Cr');
    });

    test('formats negative compact', () {
      expect(CurrencyFormatter.formatCompact(-150000), '-₹1.5L');
    });
  });

  group('CurrencyFormatter.parse', () {
    test('parses formatted string back to double', () {
      expect(CurrencyFormatter.parse('₹1,50,000'), 150000.0);
    });

    test('returns null for non-numeric string', () {
      expect(CurrencyFormatter.parse('invalid'), isNull);
    });
  });

  // ─── PhoneValidator ───────────────────────────────────────────────────

  group('PhoneValidator.isValidIndianMobile', () {
    test('accepts valid 10-digit number starting with 9', () {
      expect(PhoneValidator.isValidIndianMobile('9876543210'), true);
    });

    test('accepts valid 10-digit number starting with 6', () {
      expect(PhoneValidator.isValidIndianMobile('6012345678'), true);
    });

    test('accepts valid 10-digit number starting with 7', () {
      expect(PhoneValidator.isValidIndianMobile('7890123456'), true);
    });

    test('accepts valid 10-digit number starting with 8', () {
      expect(PhoneValidator.isValidIndianMobile('8123456789'), true);
    });

    test('rejects number with fewer than 10 digits', () {
      expect(PhoneValidator.isValidIndianMobile('98765'), false);
    });

    test('rejects number with more than 10 digits', () {
      expect(PhoneValidator.isValidIndianMobile('98765432109'), false);
    });

    test('rejects number starting with 0', () {
      expect(PhoneValidator.isValidIndianMobile('0876543210'), false);
    });

    test('rejects number starting with 5', () {
      expect(PhoneValidator.isValidIndianMobile('5876543210'), false);
    });

    test('rejects empty string', () {
      expect(PhoneValidator.isValidIndianMobile(''), false);
    });

    test('rejects number with letters', () {
      expect(PhoneValidator.isValidIndianMobile('98765ABCDE'), false);
    });
  });

  group('PhoneValidator.normalize', () {
    test('strips +91 prefix', () {
      expect(PhoneValidator.normalize('+919876543210'), '9876543210');
    });

    test('strips 91 prefix (12-digit)', () {
      expect(PhoneValidator.normalize('919876543210'), '9876543210');
    });

    test('leaves 10-digit number unchanged', () {
      expect(PhoneValidator.normalize('9876543210'), '9876543210');
    });

    test('strips spaces', () {
      expect(PhoneValidator.normalize('98765 43210'), '9876543210');
    });

    test('strips dashes', () {
      expect(PhoneValidator.normalize('98765-43210'), '9876543210');
    });
  });

  group('PhoneValidator.validate', () {
    test('returns null for valid number', () {
      expect(PhoneValidator.validate('9876543210'), isNull);
    });

    test('returns error for null', () {
      expect(PhoneValidator.validate(null), isNotNull);
    });

    test('returns error for empty string', () {
      expect(PhoneValidator.validate(''), isNotNull);
    });

    test('returns error for invalid number', () {
      expect(PhoneValidator.validate('12345'), isNotNull);
    });
  });
}
