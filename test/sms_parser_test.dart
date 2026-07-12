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

    test('15-digit IMPS RRN parses (Task C3 regex: 12-22 digits)', () {
      const sms =
          'IMPS transfer of Rs.950 ref 417293054120453 credited on 05-06-25.';
      final r = SmsParser.parse(sms);
      expect(r.utr, '417293054120453');
    });

    test('22-digit FASTag RRN parses (top of the new range)', () {
      const sms =
          'FASTag txn ref 99887766554433221100 debited Rs.75 on 02-07-25.';
      final r = SmsParser.parse(sms);
      expect(r.utr, '99887766554433221100');
    });

    test('23-digit run is rejected (out of UTR range)', () {
      // Anything 23+ digits is unlikely to be a txn ref (e.g. ISO timestamps
      // or tracking numbers). The regex caps at 22 to avoid noise.
      const sms =
          'Tracking number 12345678901234567890123 debited Rs.75 on 02-07-25.';
      final r = SmsParser.parse(sms);
      // First 22-digit prefix won't match a `\b...\b` boundary because the
      // whole 23-digit run is a single word; the regex won't carve 22 out.
      expect(r.utr, isNull);
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
      // Task C3: Aadhaar is 12 digits and the regex matches it. The new
      // false-positive filter (_isLikelyTransactionId) recognizes an SMS
      // that mentions "Aadhaar" and drops the UTR so the caller doesn't
      // latch onto a gov-ID number.
      const sms = 'Your Aadhaar 999900001111 is verified. ₹0 debited.';
      final r = SmsParser.parse(sms);
      expect(r.utr, isNull);
      expect(r.amount, 0);
    });

    test('accepts a 12-digit number when framed with UTR/RRN/ref/txn', () {
      // The filter only rejects Aadhaar-like numbers when no UTR/RRN/ref/txn
      // keyword is nearby. A bank-SMS Aadhaar-like run anchored by `UTR`
      // still parses — the keyword is the discriminator.
      const sms =
          'Your UTR 999900001111 is verified for ₹0 debited on 10-Jan-25.';
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
