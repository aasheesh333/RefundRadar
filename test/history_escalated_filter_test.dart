import 'package:flutter_test/flutter_test.dart';
import 'package:refund_radar/data/models/dispute.dart';
import 'package:refund_radar/features/history/history_page.dart';

void main() {
  final fixedCreated = DateTime(2025, 1, 1);
  final fixedTxn = DateTime(2025, 1, 10);

  Dispute base({
    String id = 'd1',
    DisputeStatus status = DisputeStatus.draft,
    Map<String, DateTime?>? filedDates,
    double? resolvedAmount,
  }) =>
      Dispute(
        id: id,
        type: DisputeType.upiP2p,
        status: status,
        amount: 1500,
        txnDate: fixedTxn,
        txnId: 'UTR123',
        filedDates: filedDates ?? const {},
        resolvedAmount: resolvedAmount,
        createdAt: fixedCreated,
      );

  group('isEscalatedDispute', () {
    test('includes open filedL2', () {
      expect(
        isEscalatedDispute(base(status: DisputeStatus.filedL2)),
        isTrue,
      );
    });

    test('includes open ombudsman', () {
      expect(
        isEscalatedDispute(base(status: DisputeStatus.ombudsman)),
        isTrue,
      );
    });

    test('includes past resolved with l2 filed date', () {
      expect(
        isEscalatedDispute(base(
          status: DisputeStatus.resolved,
          filedDates: {
            'l1': DateTime(2025, 3, 1),
            'l2': DateTime(2025, 3, 10),
          },
          resolvedAmount: 500,
        )),
        isTrue,
      );
    });

    test('includes past expired with ombudsman filed date', () {
      expect(
        isEscalatedDispute(base(
          status: DisputeStatus.expired,
          filedDates: {
            'l1': DateTime(2025, 3, 1),
            'ombudsman': DateTime(2025, 4, 1),
          },
        )),
        isTrue,
      );
    });

    test('includes past with legacy l3 filed date', () {
      expect(
        isEscalatedDispute(base(
          status: DisputeStatus.resolved,
          filedDates: {
            'l1': DateTime(2025, 3, 1),
            'l3': DateTime(2025, 4, 1),
          },
          resolvedAmount: 0,
        )),
        isTrue,
      );
    });

    test('excludes past with only l1', () {
      expect(
        isEscalatedDispute(base(
          status: DisputeStatus.resolved,
          filedDates: {'l1': DateTime(2025, 3, 1)},
          resolvedAmount: 100,
        )),
        isFalse,
      );
    });

    test('excludes open filedL1', () {
      expect(
        isEscalatedDispute(base(status: DisputeStatus.filedL1)),
        isFalse,
      );
    });

    test('excludes draft', () {
      expect(isEscalatedDispute(base()), isFalse);
    });
  });

  group('filterHistoryDisputes Escalated', () {
    test('pulls escalated from full list not only past', () {
      final disputes = [
        base(id: 'open-l2', status: DisputeStatus.filedL2),
        base(
          id: 'past-won',
          status: DisputeStatus.resolved,
          resolvedAmount: 200,
          filedDates: {'l1': DateTime(2025, 3, 1)},
        ),
        base(
          id: 'past-escalated',
          status: DisputeStatus.resolved,
          resolvedAmount: 0,
          filedDates: {
            'l1': DateTime(2025, 3, 1),
            'l2': DateTime(2025, 3, 15),
          },
        ),
      ];

      final result = filterHistoryDisputes(disputes, 'Escalated');
      expect(result.map((d) => d.id).toList(), ['open-l2', 'past-escalated']);
    });

    test('All still shows only past disputes', () {
      final disputes = [
        base(id: 'open-l2', status: DisputeStatus.filedL2),
        base(
          id: 'past',
          status: DisputeStatus.resolved,
          resolvedAmount: 100,
        ),
      ];
      final result = filterHistoryDisputes(disputes, 'All');
      expect(result.map((d) => d.id).toList(), ['past']);
    });
  });
}
