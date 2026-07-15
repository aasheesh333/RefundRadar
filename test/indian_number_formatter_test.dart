import 'package:flutter_test/flutter_test.dart';
import 'package:refund_radar/shared/utils/indian_number_formatter.dart';

void main() {
  group('IndianNumberFormatter', () {
    test('small numbers have no grouping', () {
      expect(IndianNumberFormatter.format(0), '0');
      expect(IndianNumberFormatter.format(5), '5');
      expect(IndianNumberFormatter.format(999), '999');
    });

    test('thousands group with Indian pattern', () {
      expect(IndianNumberFormatter.format(1000), '1,000');
      expect(IndianNumberFormatter.format(1234), '1,234');
      expect(IndianNumberFormatter.format(12345), '12,345');
      expect(IndianNumberFormatter.format(123456), '1,23,456');
      expect(IndianNumberFormatter.format(1234567), '12,34,567');
      expect(IndianNumberFormatter.format(500000), '5,00,000');
    });

    test('cap value renders without imbalance', () {
      expect(IndianNumberFormatter.format(5_00_000), '5,00,000');
    });
  });
}
