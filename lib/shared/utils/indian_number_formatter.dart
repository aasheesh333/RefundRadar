/// Formats a number using Indian grouping (lakhs/crores).
///
/// Examples:
///   1          -> "1"
///   1234       -> "1,234"
///   123456     -> "1,23,456"
///   1234567    -> "12,34,567"
///   12345678.9 -> "1,23,45,678.9"
class IndianNumberFormatter {
  static String format(double amount) {
    final integer = amount.toInt().toString();
    if (integer.length <= 3) return integer;

    final lastThree = integer.substring(integer.length - 3);
    final rest = integer.substring(0, integer.length - 3);

    final buffer = StringBuffer();
    for (int i = 0; i < rest.length; i++) {
      if (i > 0 && (rest.length - i) % 2 == 0) buffer.write(',');
      buffer.write(rest[i]);
    }
    buffer.write(',');
    buffer.write(lastThree);

    final fraction = (amount - amount.truncateToDouble()).abs() > 0.0001
        ? amount.toStringAsFixed(2).split('.').last
        : null;

    if (fraction != null) {
      buffer.write('.');
      buffer.write(fraction);
    }

    return buffer.toString();
  }
}
