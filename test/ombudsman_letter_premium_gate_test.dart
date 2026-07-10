import 'package:flutter_test/flutter_test.dart';
import 'package:refund_radar/features/ombudsman/ombudsman_letter_page.dart';

void main() {
  group('ombudsmanLetterPaywallLocation', () {
    test('routes free users to paywall with dispute return + ombudsman trigger', () {
      expect(
        ombudsmanLetterPaywallLocation('abc-123'),
        '/paywall?return=/disputes/abc-123&trigger=ombudsman_letter',
      );
    });
  });

  group('shouldGateOmbudsmanLetter', () {
    test('gates free users', () {
      expect(shouldGateOmbudsmanLetter(false), isTrue);
    });

    test('does not gate premium users', () {
      expect(shouldGateOmbudsmanLetter(true), isFalse);
    });
  });
}
