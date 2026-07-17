import 'package:flutter_test/flutter_test.dart';
import 'package:refund_radar/services/compensation_calculator.dart';
import 'package:refund_radar/services/sms_parser.dart';
import 'package:refund_radar/data/models/dispute.dart';

void main() {
  group('CompensationCalculator', () {
    test('UPI P2P T+1: 0 days expired', () {
      final d = Dispute(
        id: 't1',
        type: DisputeType.upiP2p,
        amount: 500,
        txnDate: DateTime(2025, 1, 10),
        txnId: 'UTR123',
        createdAt: DateTime(2025, 1, 10),
      );
      final comp = CompensationCalculator.compute(d, now: DateTime(2025, 1, 11));
      expect(comp.compensationDue, 0);
      expect(comp.isExpired, false);
    });

    test('UPI P2P T+1 working-day deadline (Fri +1 → Mon)', () {
      // txn Fri Jan 10 2025. T+1 in working days: skip Sat Jan 11 (2nd
      // Saturday) + Sun Jan 12 → deadline Mon Jan 13. By Thu Jan 16 the
      // calendar-day delay is 3 → ₹300. This is the RBI-correct reading
      // (the bank gets until Monday, so by Thursday only 3 calendar days
      // of delay have accrued — not 5 as the old calendar-day TAT gave).
      final d = Dispute(
        id: 't2',
        type: DisputeType.upiP2p,
        amount: 500,
        txnDate: DateTime(2025, 1, 10),
        txnId: 'UTR123',
        createdAt: DateTime(2025, 1, 10),
      );
      final comp = CompensationCalculator.compute(d, now: DateTime(2025, 1, 16));
      expect(comp.daysElapsed, 3);
      expect(comp.compensationDue, 300);
      expect(comp.isExpired, true);
    });

    test('UPI P2M T+5 working-day deadline', () {
      // txn Fri Jan 10 2025. T+5 working days: Jan 13,14,15,16,17 (skip
      // 2nd Sat Jan 11 + Sun Jan 12) → deadline Fri Jan 17. By Mon Jan 20
      // the calendar-day delay is 3 → ₹300.
      final d = Dispute(
        id: 't3',
        type: DisputeType.upiP2m,
        amount: 1000,
        txnDate: DateTime(2025, 1, 10),
        txnId: 'UTR456',
        createdAt: DateTime(2025, 1, 10),
      );
      final comp = CompensationCalculator.compute(d, now: DateTime(2025, 1, 20));
      expect(comp.daysElapsed, 3);
      expect(comp.compensationDue, 300);
    });

    test('FASTag: no compensation', () {
      final d = Dispute(
        id: 't4',
        type: DisputeType.fastag,
        amount: 200,
        txnDate: DateTime(2025, 1, 10),
        txnId: 'TXN789',
        createdAt: DateTime(2025, 1, 10),
      );
      final comp = CompensationCalculator.compute(d, now: DateTime(2025, 3, 1));
      expect(comp.compensationDue, 0);
    });

    test('Chargeback expiry window 45 days', () {
      final d = Dispute(
        id: 't5',
        type: DisputeType.upiP2p,
        amount: 500,
        txnDate: DateTime(2025, 1, 10),
        txnId: 'A',
        createdAt: DateTime(2025, 1, 10),
      );
      final days = CompensationCalculator.daysUntilChargebackExpiry(
          d, now: DateTime(2025, 2, 10));
      expect(days, 14);
    });

    test('Display cap 90 days', () {
      final d = Dispute(
        id: 't6',
        type: DisputeType.upiP2p,
        amount: 500,
        txnDate: DateTime(2024, 1, 10),
        txnId: 'A',
        createdAt: DateTime(2024, 1, 10),
      );
      final comp = CompensationCalculator.compute(d, now: DateTime(2025, 6, 1));
      expect(comp.daysElapsed, 90);
      expect(comp.compensationDue, 9000);
      expect(comp.shouldEscalate, true);
    });

    test('Working-day deadline skips a declared holiday', () {
      // txn Thu Aug 14 2025. T+1 working day: Aug 15 is Independence Day
      // (declared holiday) → skip; Aug 16 is the 3rd Saturday (working)
      // → deadline Aug 16. By Mon Aug 18 the calendar-day delay is 2 → ₹200.
      final d = Dispute(
        id: 't7',
        type: DisputeType.upiP2p,
        amount: 500,
        txnDate: DateTime(2025, 8, 14),
        txnId: 'UTR999',
        createdAt: DateTime(2025, 8, 14),
      );
      final comp = CompensationCalculator.compute(
        d,
        now: DateTime(2025, 8, 18),
        holidays: {DateTime(2025, 8, 15)},
      );
      expect(comp.daysElapsed, 2);
      expect(comp.compensationDue, 200);
    });
  });

  group('SmsParser', () {
    test('parses UTR amount date', () {
      const sms =
          'Sent Rs.1500 from your account UTR 123456789012 on 10-Jan-25 to vpa@upi. Ref: 5550';
      final p = SmsParser.parse(sms);
      expect(p.utr, '123456789012');
      expect(p.amount, 1500);
    });
  });
}
