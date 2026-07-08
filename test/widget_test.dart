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

    test('UPI P2P T+1: 5 days expired, owes 500', () {
      final d = Dispute(
        id: 't2',
        type: DisputeType.upiP2p,
        amount: 500,
        txnDate: DateTime(2025, 1, 10),
        txnId: 'UTR123',
        createdAt: DateTime(2025, 1, 10),
      );
      final comp = CompensationCalculator.compute(d, now: DateTime(2025, 1, 16));
      expect(comp.daysElapsed, 5);
      expect(comp.compensationDue, 500);
      expect(comp.isExpired, true);
    });

    test('UPI P2M T+5: 1 day expired, owes 100', () {
      final d = Dispute(
        id: 't3',
        type: DisputeType.upiP2m,
        amount: 1000,
        txnDate: DateTime(2025, 1, 10),
        txnId: 'UTR456',
        createdAt: DateTime(2025, 1, 10),
      );
      final comp = CompensationCalculator.compute(d, now: DateTime(2025, 1, 16));
      expect(comp.daysElapsed, 1);
      expect(comp.compensationDue, 100);
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
