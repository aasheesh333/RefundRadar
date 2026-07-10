import 'package:flutter_test/flutter_test.dart';
import 'package:refund_radar/services/sms_inbox_service.dart';

void main() {
  group('SmsInboxService.looksLikeBankSms', () {
    test('accepts UPI-style body', () {
      const m = InboxSms(
        id: '1',
        address: 'HDFCBK',
        body:
            'Rs.500.00 debited via UPI UTR 123456789012 on 10-01-26 to merchant@okhdfc',
      );
      expect(SmsInboxService.looksLikeBankSms(m), isTrue);
    });

    test('rejects short non-bank text', () {
      const m = InboxSms(id: '2', address: 'FRIEND', body: 'ok see you');
      expect(SmsInboxService.looksLikeBankSms(m), isFalse);
    });
  });

  group('ListSmsInboxBackend filter path', () {
    test('queryBankLikeMessages filters list', () async {
      // Permission may be denied in unit env — inject by skipping permission:
      // hasPermission uses permission_handler; we only unit-test filter helper.
      final bank = const InboxSms(
        id: 'b',
        address: 'SBI',
        body: 'Rs 100 debited UTR 111122223333 on 05/06/25',
      );
      final friend = const InboxSms(id: 'a', address: 'X', body: 'hi there friend');
      expect(SmsInboxService.looksLikeBankSms(bank), isTrue);
      expect(SmsInboxService.looksLikeBankSms(friend), isFalse);
    });
  });
}
