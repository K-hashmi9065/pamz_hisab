/// Sealed failure hierarchy — returned from all repository/usecase calls.
/// Technical details are NEVER exposed; [message] is always user-friendly.
/// Uses native Dart sealed classes (no code-gen required).
sealed class Failure {
  const Failure({required this.message, this.technicalDetail});

  final String message;
  final String? technicalDetail; // for logging only — never show in UI

  @override
  String toString() => 'Failure(${runtimeType.toString()}): $message';
}

/// Failures from SQLite / Hive operations.
final class DatabaseFailure extends Failure {
  const DatabaseFailure({
    super.message = 'A database error occurred. Please try again.',
    super.technicalDetail,
  });
}

/// Input does not pass validation rules (phone format, amount > 0, etc.).
final class ValidationFailure extends Failure {
  const ValidationFailure({
    required super.message,
    this.field,
    super.technicalDetail,
  });

  final String? field;
}

/// Mobile number already registered for another non-deleted contact (FR-UK-001).
final class DuplicatePhoneFailure extends Failure {
  const DuplicatePhoneFailure({
    super.message =
        'This mobile number is already registered. Please use a different number.',
    super.technicalDetail,
  });
}

/// Biometric / local_auth failures (FR-SEC-001).
final class BiometricFailure extends Failure {
  const BiometricFailure({
    super.message = 'Authentication failed. Please try your passcode.',
    super.technicalDetail,
  });
}

/// PDF generation failure (FR-AN-003).
final class PdfGenerationFailure extends Failure {
  const PdfGenerationFailure({
    super.message = 'Could not generate the PDF report. Please try again.',
    super.technicalDetail,
  });
}

/// Sharing/export dispatch failure.
final class ShareDispatchFailure extends Failure {
  const ShareDispatchFailure({
    super.message = 'Could not share the file. Please try again.',
    super.technicalDetail,
  });
}

/// Catch-all for unexpected failures.
final class UnknownFailure extends Failure {
  const UnknownFailure({
    super.message = 'Something went wrong. Please try again.',
    super.technicalDetail,
  });
}
