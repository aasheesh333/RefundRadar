import 'package:flutter_test/flutter_test.dart';
import 'package:refund_radar/data/models/dispute.dart';
import 'package:refund_radar/data/models/template.dart';
import 'package:refund_radar/features/templates/template_library_page.dart';

void main() {
  const body =
      'UTR {UTR} AMOUNT {AMOUNT} INR {AMOUNT_INR} DATE {DATE} '
      'BANK {BANK} ENTITY {ENTITY} TICKET {TICKET}';

  group('templateFillValues', () {
    test('empty strings when no dispute', () {
      final values = templateFillValues(null);
      expect(values['UTR'], '');
      expect(values['AMOUNT'], '');
      expect(values['AMOUNT_INR'], '');
      expect(values['DATE'], '');
      expect(values['BANK'], '');
      expect(values['ENTITY'], '');
      expect(values['TICKET'], '');
    });

    test('maps dispute fields into common tokens', () {
      final d = Dispute(
        id: 'd1',
        type: DisputeType.upiP2p,
        amount: 1500,
        txnDate: DateTime(2025, 3, 12),
        txnId: 'UTR999',
        entityName: 'HDFC Bank',
        ticketNumbers: const {'l1': 'TKT-42'},
        createdAt: DateTime(2025, 1, 1),
      );
      final values = templateFillValues(d);
      expect(values['UTR'], 'UTR999');
      expect(values['AMOUNT'], '1500');
      expect(values['AMOUNT_INR'], '1500');
      expect(values['DATE'], '12/3/2025');
      expect(values['BANK'], 'HDFC Bank');
      expect(values['ENTITY'], 'HDFC Bank');
      expect(values['TICKET'], 'TKT-42');
    });

    test('ticket empty when none present', () {
      final d = Dispute(
        id: 'd1',
        type: DisputeType.upiP2p,
        amount: 100,
        txnDate: DateTime(2025, 1, 1),
        txnId: 'X',
        createdAt: DateTime(2025, 1, 1),
      );
      expect(templateFillValues(d)['TICKET'], '');
    });
  });

  group('filled template body', () {
    test('fill with empty values strips common placeholders', () {
      final filled = Template.fill(body, templateFillValues(null));
      expect(filled, 'UTR  AMOUNT  INR  DATE  BANK  ENTITY  TICKET ');
      expect(filled.contains('{UTR}'), isFalse);
      expect(filled.contains('{AMOUNT}'), isFalse);
      expect(filled.contains('{DATE}'), isFalse);
    });

    test('fill with dispute substitutes values', () {
      final d = Dispute(
        id: 'd1',
        type: DisputeType.upiP2p,
        amount: 2500,
        txnDate: DateTime(2025, 6, 1),
        txnId: 'UTRABC',
        entityName: 'SBI',
        ticketNumbers: const {'l1': 'N-1'},
        createdAt: DateTime(2025, 1, 1),
      );
      final filled = Template.fill(body, templateFillValues(d));
      expect(filled, contains('UTRABC'));
      expect(filled, contains('2500'));
      expect(filled, contains('1/6/2025'));
      expect(filled, contains('SBI'));
      expect(filled, contains('N-1'));
    });
  });
}
