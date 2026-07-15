import 'package:flutter_test/flutter_test.dart';
import 'package:refund_radar/core/router/app_routes.dart';

void main() {
  group('AppRoutes.paywallWithParams', () {
    test('encodes all params correctly', () {
      final url = AppRoutes.paywallWithParams(
        trigger: 'template_locked',
        returnPath: '/disputes/abc-123',
        templateId: 'upi_ombudsman_l2',
        templateTitle: 'Ombudsman L2 Complaint',
      );
      // Uri.encodeComponent is used for query values — spaces become %20
      // and slashes in the return path become %2F.
      expect(url, contains('trigger=template_locked'));
      expect(url, contains('return=%2Fdisputes%2Fabc-123'));
      expect(url, contains('templateId=upi_ombudsman_l2'));
      expect(url, contains('templateTitle=Ombudsman%20L2%20Complaint'));
    });

    test('omits optional params when null', () {
      final url = AppRoutes.paywallWithParams(
        trigger: 'home_banner',
        returnPath: '/home',
      );
      expect(url, contains('trigger=home_banner'));
      expect(url, contains('return=%2Fhome'));
      expect(url, isNot(contains('templateId')));
      expect(url, isNot(contains('templateTitle')));
    });

    test('works with trigger only (no return path)', () {
      final url = AppRoutes.paywallWithParams(
        trigger: 'generic',
      );
      expect(url, '/paywall?trigger=generic');
    });
  });

  group('AppRoutes.paywallWithReturn', () {
    test('encodes return path and trigger', () {
      final url = AppRoutes.paywallWithReturn('/disputes/x', 'free_second_dispute');
      expect(url, contains('trigger=free_second_dispute'));
      expect(url, contains('return=%2Fdisputes%2Fx'));
    });
  });
}
