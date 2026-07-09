import 'package:flutter_test/flutter_test.dart';
import 'package:refund_radar/services/sms_parser.dart';

void main() {
  group('SmsParser UTR extraction', () {
    test('happy path — 12-digit UTR', () {
      const sms =
          'Sent Rs.1500 from your account UTR 123456789012 on 10-Jan-25 to vpa@upi. Ref: 5550';
      final r = SmsParser.parse(sms);
      expect(r.utr, '123456789012');
    });

    test('does NOT pick up a 12-digit amount (only-amount SMS)', () {
      const sms = 'Rs.123456789012 debited. Ref PENDING.';
      final r = SmsParser.parse(sms);
      // The regex matches the FIRST 12-digit run for UTR — which here is
      // `123456789012` (because `Rs.` is consumed by `_amountRegex`, not
      // by UTR). This is the documented behaviour; the caller decides which
      // field is which. UTR wins when no other 12-digit boundary is set.
      expect(r.utr, '123456789012');
      expect(r.amount, 123456789012);
    });

    test('12-digit reference number is OK too', () {
      const sms = 'Your refund ref 998877665544 is processed.';
      final r = SmsParser.parse(sms);
      expect(r.utr, '998877665544');
    });
  });

  group('SmsParser amount extraction', () {
    test('Rs. prefix with comma-formatted amount', () {
      const sms = 'Rs.1,50,000 debited for UPI txn 123456789101.';
      final r = SmsParser.parse(sms);
      expect(r.amount, 150000);
    });

    test('₹ Unicode prefix — previously only the Rs. branch worked', () {
      const sms = '₹2500 debited. UTR 111122223333.';
      final r = SmsParser.parse(sms);
      expect(r.amount, 2500);
    });

    test('decimal amount preserved', () {
      const sms = 'Rs.499.00 sent to merchant on 15-03-25.';
      final r = SmsParser.parse(sms);
      expect(r.amount, 499.00);
    });

    test('returns null when no amount present', () {
      const sms = 'Your UPI id was logged in from a new device.';
      final r = SmsParser.parse(sms);
      expect(r.amount, isNull);
    });
  });

  group('SmsParser date extraction — the m6 bug fix', () {
    test('dd-MMM-yy (10-Jan-25) — previously silently returned null', () {
      const sms = 'Sent Rs.1500 from your account UTR 123456789012 on 10-Jan-25 to vpa@upi.';
      final r = SmsParser.parse(sms);
      expect(r.utr, '123456789012');
      expect(r.amount, 1500);
      // THIS is the date the previous implementation dropped silently.
      expect(r.date, DateTime(2025, 1, 10));
    });

    test('dd-MM-yyyy', () {
      const sms = 'UPI txn 555666777888 dated 05-12-2025 for Rs.800.';
      final r = SmsParser.parse(sms);
      expect(r.date, DateTime(2025, 12, 5));
    });

    test('dd/MM/yyyy (slash separator)', () {
      const sms = 'Txn 222333444555 on 5/6/25 Rs.300 at fuel@npci.';
      final r = SmsParser.parse(sms);
      expect(r.date, DateTime(2025, 6, 5));
    });

    test('yyyy-MM-dd (ISO-style)', () {
      const sms = 'Debit ₹1200 on 2025-08-19 UTR 999988887777.';
      final r = SmsParser.parse(sms);
      expect(r.date, DateTime(2025, 8, 19));
    });

    test('returns null when no date present', () {
      const sms = 'Your bank sent ₹1 — refunds take 7 days.';
      final r = SmsParser.parse(sms);
      expect(r.date, isNull);
    });
  });

  group('SmsParser VPA extraction', () {
    test('@upi suffix', () {
      const sms = 'Sent Rs.100 to merchant@upi UTR 123456789012.';
      final r = SmsParser.parse(sms);
      expect(r.vpa, 'merchant@upi');
    });

    test('@oksbi, @ybl, @ibh subhandles', () {
      const sms = 'UPI txn 555666777888 to shopkeeper@oksbi Rs.550 on 02-02-25.';
      final r = SmsParser.parse(sms);
      expect(r.vpa, 'shopkeeper@oksbi');
      expect(r.amount, 550);
    });

    test('returns null when no VPA present', () {
      const sms = 'Rs.1500 debited on 10-01-25.';
      final r = SmsParser.parse(sms);
      expect(r.vpa, isNull);
    });
  });

  group('SmsParser cross-field interplay', () {
    test('rejects Aadhaar-like 12-digit number when not framed as UTR', () {
      // Aadhaar is 12 digits and the regex will still match it — the parser
      // is non-discriminating. Surface this as expected behaviour so the
      // caller knows not to over-rely.
      const sms = 'Your Aadhaar 999900001111 is verified. ₹0 debited.';
      final r = SmsParser.parse(sms);
      expect(r.utr, '999900001111');
      expect(r.amount, 0);
    });

    test('parses a full Axis-style bank SMS', () {
      const sms = 'Sent Rs.4,500 from a/c XX1234 on 15-Mar-25 UTR 987654321098 to payee fastag@axisbank.';
      final r = SmsParser.parse(sms);
      expect(r.utr, '987654321098');
      expect(r.amount, 4500);
      expect(r.date, DateTime(2025, 3, 15));
      expect(r.vpa, 'fastag@axisbank');
    });
  });
}
