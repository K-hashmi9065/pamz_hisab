/// Indian currency formatter using ₹ and Lakh/Crore grouping.
abstract final class CurrencyFormatter {
  CurrencyFormatter._();

  /// Formats [amount] using Indian number system (Lakhs/Crores).
  /// e.g. 1500000 → ₹15,00,000 | 45000 → ₹45,000 | -2000 → -₹2,000
  static String formatIndian(num amount, {bool showSign = false}) {
    final isNegative = amount < 0;
    final abs = amount.abs();

    final formatted = _applyIndianGrouping(abs);

    final sign = isNegative
        ? '-'
        : (showSign && amount > 0)
            ? '+'
            : '';

    return '$sign₹$formatted';
  }

  /// Returns formatted amount with + prefix for credit amounts.
  static String formatCredit(num amount) => formatIndian(amount, showSign: true);

  /// Formats exact amount using Indian number system without compact abbreviation.
  /// Retained as alias for backward compatibility.
  static String formatCompact(num amount) => formatIndian(amount);

  /// Parses a string like "₹1,50,000" back to a double.
  static double? parse(String value) {
    final cleaned = value.replaceAll('₹', '').replaceAll(',', '').trim();
    return double.tryParse(cleaned);
  }

  static String _applyIndianGrouping(num amount) {
    // Round to 2 decimal places to handle floating-point precision cleanly
    final rounded = double.parse(amount.abs().toStringAsFixed(2));
    final intPart = rounded.truncate();
    final decCents = ((rounded - intPart) * 100).round();

    final str = intPart.toString();

    if (str.length <= 3) {
      final result = str;
      return decCents > 0
          ? '$result.${decCents.toString().padLeft(2, '0')}'
          : result;
    }

    // Last 3 digits
    final last3 = str.substring(str.length - 3);
    // Remaining digits grouped by 2
    final remaining = str.substring(0, str.length - 3);
    final groups = <String>[];

    var i = remaining.length;
    while (i > 0) {
      final start = (i - 2).clamp(0, i);
      groups.insert(0, remaining.substring(start, i));
      i = start;
    }

    final formattedInt = '${groups.join(',')},$last3';
    return decCents > 0
        ? '$formattedInt.${decCents.toString().padLeft(2, '0')}'
        : formattedInt;
  }
}
