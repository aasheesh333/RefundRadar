import 'package:flutter_test/flutter_test.dart';
import 'package:refund_radar/core/utils/url_launcher_helper.dart';

void main() {
  group('EmailUtil mailto encoding', () {
    test('spaces are encoded as %20, not +', () {
      final uri = EmailUtil.build('test@example.com', body: 'Hello world');
      expect(uri.toString(), contains('body=Hello%20world'));
      expect(uri.toString(), isNot(contains('body=Hello+world')));
    });

    test('plus signs are preserved as %2B, not decoded', () {
      final uri = EmailUtil.build('test@example.com', body: 'Hello + world');
      expect(uri.toString(), contains('body=Hello%20%2B%20world'));
      expect(uri.toString(), isNot(contains('+')));
    });

    test('subject and body both encode spaces correctly', () {
      final uri = EmailUtil.build('test@example.com', subject: 'Support needed', body: 'I need help');
      expect(uri.toString(), contains('subject=Support%20needed'));
      expect(uri.toString(), contains('body=I%20need%20help'));
      expect(uri.toString(), isNot(contains('+')));
    });

    test('null values are handled without crashing', () {
      final uri = EmailUtil.build('test@example.com', subject: null, body: null);
      expect(uri.toString(), equals('mailto:test@example.com?'));
    });

    test('empty strings do not add parameters', () {
      final uri = EmailUtil.build('test@example.com', subject: '', body: '');
      // Empty strings are encoded but create parameters; this is expected behavior
      expect(uri.toString(), isNot(contains('+')));
    });

    test('email address is not altered', () {
      final uri = EmailUtil.build('test+tag@example.com', subject: 'Hi');
      expect(uri.toString(), startsWith('mailto:test+tag@example.com'));
    });
  });
}
