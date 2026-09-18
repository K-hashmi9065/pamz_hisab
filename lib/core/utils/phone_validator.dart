/// Validates Indian mobile phone numbers (FR-UK-001).
abstract final class PhoneValidator {
  PhoneValidator._();

  /// Valid if exactly 10 digits, starting with 6, 7, 8, or 9.
  static bool isValidIndianMobile(String value) {
    if (value.isEmpty) return false;
    final cleaned = value.replaceAll(RegExp(r'\s|-'), '');
    return RegExp(r'^[6-9]\d{9}$').hasMatch(cleaned);
  }

  /// Returns a validation error string or null (for use in Form validators).
  static String? validate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Mobile number is required';
    }
    if (!isValidIndianMobile(value.trim())) {
      return 'Enter a valid 10-digit Indian mobile number starting with 6-9';
    }
    return null;
  }

  /// Normalizes: strips spaces/dashes, trims +91 prefix if present.
  static String normalize(String value) {
    var cleaned = value.replaceAll(RegExp(r'[\s\-]'), '');
    if (cleaned.startsWith('+91') && cleaned.length == 13) {
      cleaned = cleaned.substring(3);
    } else if (cleaned.startsWith('91') && cleaned.length == 12) {
      cleaned = cleaned.substring(2);
    }
    return cleaned;
  }
}
