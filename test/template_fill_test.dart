import 'package:flutter_test/flutter_test.dart';
import 'package:refund_radar/data/models/dispute.dart';
import 'package:refund_radar/data/models/template.dart';
import 'package:refund_radar/data/models/template_fill.dart';

void main() {
  group('fillValuesForDispute', () {
    test('null dispute empties known tokens', () {
      final m = fillValuesForDispute(null);
      expect(m['UTR'], '');
      expect(m['BANK_NAME'], '');
      expect(m['COMPENSATION_DUE'], '');
    });

    test('fills core and alias tokens from dispute', () {
      final d = Dispute(
        id: 'd1',
        uid: 'u1',
        type: DisputeType.upiP2p,
        amount: 500,
        txnDate: DateTime(2026, 1, 10),
        txnId: '123456789012',
        entityName: 'HDFC Bank',
        ticketNumbers: const {'l1': 'TKT-9'},
        filedDates: {'l1': DateTime(2026, 1, 12)},
        createdAt: DateTime(2026, 1, 11),
      );
      final m = fillValuesForDispute(d);
      expect(m['UTR'], '123456789012');
      expect(m['TXN_ID'], '123456789012');
      expect(m['AMOUNT'], '500');
      expect(m['amount'], '500');
      expect(m['BANK_NAME'], 'HDFC Bank');
      expect(m['ENTITY_NAME'], 'HDFC Bank');
      expect(m['TICKET_NO'], 'TKT-9');
      expect(m['TXN_DATE'], '10/01/2026');
      expect(m['DATE'], '10/01/2026');
    });

    test('filledBody replaces asset-style tokens', () {
      final d = Dispute(
        id: 'd1',
        type: DisputeType.upiP2m,
        amount: 100,
        txnDate: DateTime(2026, 3, 1),
        txnId: '999988887777',
        entityName: 'SBI',
        createdAt: DateTime(2026, 3, 2),
      );
      const body =
          'UTR: {UTR} Bank: {BANK_NAME} Amt: {AMOUNT} Date: {TXN_DATE}';
      final out = filledBody(body, d);
      expect(out, contains('999988887777'));
      expect(out, contains('SBI'));
      expect(out, isNot(contains('{UTR}')));
      expect(out, isNot(contains('{BANK_NAME}')));
    });

    test('Template.fill leaves unknown tokens', () {
      expect(Template.fill('X {FOO} Y', {'UTR': '1'}), 'X {FOO} Y');
    });
  });

  group('wizardLevelFromDispute', () {
    Dispute base({
      DisputeStatus status = DisputeStatus.draft,
      Map<String, DateTime?> filed = const {},
    }) =>
        Dispute(
          id: 'x',
          type: DisputeType.upiP2p,
          amount: 1,
          txnDate: DateTime(2026, 1, 1),
          txnId: '1',
          status: status,
          filedDates: filed,
          createdAt: DateTime(2026, 1, 1),
        );

    test('draft with no filings → 0', () {
      expect(wizardLevelFromDispute(base()), 0);
    });

    test('filedL1 → 1 (next L2)', () {
      expect(
        wizardLevelFromDispute(base(
          status: DisputeStatus.filedL1,
          filed: {'l1': DateTime(2026, 1, 2)},
        )),
        1,
      );
    });

    test('filedL2 → 2 (next ombudsman)', () {
      expect(
        wizardLevelFromDispute(base(status: DisputeStatus.filedL2)),
        2,
      );
    });

    test('ombudsman → 2', () {
      expect(
        wizardLevelFromDispute(base(status: DisputeStatus.ombudsman)),
        2,
      );
    });

    test('legacy l3 filed date → 2', () {
      expect(
        wizardLevelFromDispute(base(
          status: DisputeStatus.filedL1,
          filed: {'l3': DateTime(2026, 2, 1)},
        )),
        2,
      );
    });
  });
}
