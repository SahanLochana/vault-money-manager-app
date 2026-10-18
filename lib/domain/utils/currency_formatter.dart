import 'package:intl/intl.dart';

class CurrencyFormatter {
  static const double maxAmount = 999999999.99;
  static const int maxCents = 99999999999;

  /// Formats amount in rupees with thousands separator.
  /// Decimals are omitted when integer, otherwise formatted to 2 decimals.
  /// Example: 1000 -> "Rs 1,000", -500 -> "-Rs 500", 12.5 -> "Rs 12.50"
  static String formatRs(double amount, {bool includeSymbol = true}) {
    final isNegative = amount < 0;
    final absAmount = amount.abs();
    final hasDecimals = (absAmount % 1.0) != 0.0;

    final formatter = hasDecimals
        ? NumberFormat('#,##0.00', 'en_US')
        : NumberFormat('#,##0', 'en_US');

    final formattedNumber = formatter.format(absAmount);

    if (!includeSymbol) {
      return isNegative ? '-$formattedNumber' : formattedNumber;
    }
    return isNegative ? '-Rs $formattedNumber' : 'Rs $formattedNumber';
  }

  /// Parses money input string into integer cents.
  /// Rejects negative numbers, NaN, numbers exceeding maxAmount, or invalid formats.
  /// Empty string returns 0 cents.
  /// Avoids floating point multiplication inaccuracy by parsing integer & fractional parts.
  static int? tryParseToCents(String input) {
    var cleaned = input.trim().replaceAll(',', '');
    if (cleaned.isEmpty) return 0;

    // Check negative
    if (cleaned.startsWith('-')) return null;

    final regExp = RegExp(r'^\d+(\.\d{1,2})?$');
    if (!regExp.hasMatch(cleaned)) return null;

    final parts = cleaned.split('.');
    final wholePart = int.tryParse(parts[0]);
    if (wholePart == null) return null;

    int cents = wholePart * 100;
    if (parts.length > 1) {
      final fracString = parts[1].padRight(2, '0').substring(0, 2);
      final fracPart = int.tryParse(fracString);
      if (fracPart == null) return null;
      cents += fracPart;
    }

    if (cents > maxCents) return null;
    return cents;
  }
}
