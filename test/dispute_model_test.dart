import 'package:flutter_test/flutter_test.dart';
import 'package:refund_radar/data/models/dispute.dart';

void main() {
  final fixedCreated = DateTime(2025, 1, 1);
  final fixedTxn = DateTime(2025, 1, 10);

  Dispute base({
    String id = 'd1',
    String uid = 'u1',
    DisputeType type = DisputeType.upiP2p,
    DisputeStatus status = DisputeStatus.draft,
    double amount = 1500,
    Map<String, DateTime?>? filedDates,
    Map<String, String?>? ticketNumbers,
    double? resolvedAmount,
    DateTime? resolvedAt,
    List<String>? evidence,
    DateTime? createdAt,
    DateTime? txnDate,
    String txnId = 'UTR12345',
    String? description,
  }) =>
      Dispute(
        id: id,
        uid: uid,
        type: type,
        status: status,
        amount: amount,
        txnDate: txnDate ?? fixedTxn,
        txnId: txnId,
        filedDates: filedDates ?? const {},
        ticketNumbers: ticketNumbers ?? const {},
        resolvedAmount: resolvedAmount,
        resolvedAt: resolvedAt,
        evidence: evidence ?? const [],
        createdAt: createdAt ?? fixedCreated,
        description: description,
      );

  group('Dispute.toJson / fromJson round-trip', () {
    test('minimal dispute (draft, no filed dates)', () {
      final d = base();
      final j = d.toJson();
      expect(j['id'], 'd1');
      expect(j['type'], 'upi_p2p');
      expect(j['status'], 'draft');
      expect(j['amount'], 1500);

      final back = Dispute.fromJson(j);
      expect(back.id, 'd1');
      expect(back.type, DisputeType.upiP2p);
      expect(back.status, DisputeStatus.draft);
      expect(back.amount, 1500);
      expect(back.txnId, 'UTR12345');
      expect(back.filedDates, isEmpty);
      expect(back.ticketNumbers, isEmpty);
    });

    test('preserves all DisputeType ids', () {
      for (final t in DisputeType.values) {
        final d = base(type: t);
        final j = d.toJson();
        expect(j['type'], t.id);
        expect(Dispute.fromJson(j).type, t);
      }
    });

    test('preserves all DisputeStatus values', () {
      for (final s in DisputeStatus.values) {
        final d = base(status: s);
        final j = d.toJson();
        expect(j['status'], s.value);
        expect(Dispute.fromJson(j).status, s);
      }
    });

    test('round-trips filedDates + ticketNumbers', () {
      final d = base(
        status: DisputeStatus.filedL1,
        filedDates: {'l1': DateTime(2025, 3, 12)},
        ticketNumbers: {'l1': 'HDFC-001'},
      );
      final j = d.toJson();
      final back = Dispute.fromJson(j);
      expect(back.filedDates['l1'], DateTime(2025, 3, 12));
      expect(back.ticketNumbers['l1'], 'HDFC-001');
    });

    test('round-trips null filedDates values (sentinel: explicit null)', () {
      final d = base(filedDates: {'l1': null, 'l2': DateTime(2025, 4, 1)});
      final j = d.toJson();
      expect(j['filedDates']['l1'], isNull);
      expect(j['filedDates']['l2'], isNotNull);
      final back = Dispute.fromJson(j);
      expect(back.filedDates['l1'], isNull);
      expect(back.filedDates['l2'], DateTime(2025, 4, 1));
    });

    test('round-trips resolved + evidence', () {
      final d = base(
        status: DisputeStatus.resolved,
        resolvedAmount: 1450,
        resolvedAt: DateTime(2025, 5, 1),
        evidence: ['doc1.pdf', 'doc2.jpg'],
      );
      final j = d.toJson();
      final back = Dispute.fromJson(j);
      expect(back.resolvedAmount, 1450);
      expect(back.resolvedAt, DateTime(2025, 5, 1));
      expect(back.evidence, ['doc1.pdf', 'doc2.jpg']);
    });

    test('round-trips description when set', () {
      final d = base(description: 'Unauthorized UPI debit');
      final j = d.toJson();
      expect(j['description'], 'Unauthorized UPI debit');
      final back = Dispute.fromJson(j);
      expect(back.description, 'Unauthorized UPI debit');
    });

    test('round-trips description when null', () {
      final d = base(description: null);
      final j = d.toJson();
      expect(j['description'], isNull);
      final back = Dispute.fromJson(j);
      expect(back.description, isNull);
    });

    test('round-trips DateTime ISO strings (no microsecond loss)', () {
      final t = DateTime(2025, 7, 4, 14, 30, 15);
      final d = base(txnDate: t, createdAt: t);
      final j = d.toJson();
      // ISO 8601 string round-trip — DateTime== is exact for the
      // constructor components but toIso8601String preserves
      // only down to microseconds; here we use second-level.
      final back = Dispute.fromJson(j);
      expect(back.txnDate, t);
      expect(back.createdAt, t);
    });
  });

  group('Dispute.fromJson defensive parsing', () {
    test('empty map → safe defaults', () {
      final d = Dispute.fromJson({});
      expect(d.id, '');
      expect(d.uid, '');
      expect(d.type, DisputeType.upiP2p);
      expect(d.status, DisputeStatus.draft);
      expect(d.amount, 0);
      expect(d.txnId, '');
      expect(d.evidence, isEmpty);
    });

    test('unknown type id → falls back to upi_p2p', () {
      final d = Dispute.fromJson({'type': 'unknown_xyz'});
      expect(d.type, DisputeType.upiP2p);
    });

    test('unknown status → falls back to draft', () {
      final d = Dispute.fromJson({'status': 'wat'});
      expect(d.status, DisputeStatus.draft);
    });

    test('tx UTC ISO 8601 parses without UTC drift', () {
      // The "Z" suffix used by Firestore timestamps must not clock-drift
      // when read back. (Regression for spec §4 "Firestore security rules".)
      final j = {
        'txnDate': '2025-06-15T12:30:00.000Z',
        'createdAt': '2025-06-15T12:30:00.000Z',
      };
      final d = Dispute.fromJson(j);
      expect(d.txnDate.toUtc(), DateTime.utc(2025, 6, 15, 12, 30));
      expect(d.createdAt.toUtc(), DateTime.utc(2025, 6, 15, 12, 30));
    });

    test('amount returned as int from Firestore is coerced to double', () {
      // Firestore can hand us either int or double for the same field;
      // fromJson must always normalise to double.
      final d = Dispute.fromJson({'amount': 1200});
      expect(d.amount, 1200);
      expect(d.amount, isA<double>());
    });
  });

  group('Dispute.copyWith', () {
    test('only changes specified fields, keeps rest', () {
      final d = base();
      final d2 = d.copyWith(status: DisputeStatus.resolved, resolvedAmount: 900);
      expect(d2.status, DisputeStatus.resolved);
      expect(d2.resolvedAmount, 900);
      expect(d2.id, d.id);
      expect(d2.uid, d.uid);
      expect(d2.amount, d.amount);
    });

    test('can clear optional fields via copyWith not setting them', () {
      // When resolvedAt is not passed at all, the sentinel keeps the old
      // value — this is the "preserve" path.
      final d = base(resolvedAt: DateTime(2025, 2, 2));
      final d2 = d.copyWith(status: DisputeStatus.draft);
      // resolvedAt preserved, not cleared
      expect(d2.resolvedAt, d.resolvedAt);
    });

    test('copyWith(resolvedAt: null) clears the field (sentinel)', () {
      final d = base(resolvedAt: DateTime(2025, 2, 2));
      final d2 = d.copyWith(resolvedAt: null);
      expect(d2.resolvedAt, isNull);
      // original untouched
      expect(d.resolvedAt, DateTime(2025, 2, 2));
    });

    test('copyWith(resolvedAmount: 500) sets it', () {
      final d = base(resolvedAmount: 0);
      final d2 = d.copyWith(resolvedAmount: 500.0);
      expect(d2.resolvedAmount, 500.0);
    });
  });

  group('Dispute.reopenTarget', () {
    test('ombudsman filedDates → ombudsman status', () {
      final d = base(
        status: DisputeStatus.resolved,
        filedDates: {
          'l1': DateTime(2025, 3, 1),
          'l2': DateTime(2025, 3, 5),
          'ombudsman': DateTime(2025, 3, 10),
        },
      );
      expect(d.reopenTarget(), DisputeStatus.ombudsman);
    });

    test('l2 only → filedL2 status', () {
      final d = base(
        status: DisputeStatus.resolved,
        filedDates: {'l1': DateTime(2025, 3, 1), 'l2': DateTime(2025, 3, 5)},
      );
      expect(d.reopenTarget(), DisputeStatus.filedL2);
    });

    test('l1 only → filedL1 status', () {
      final d = base(
        status: DisputeStatus.resolved,
        filedDates: {'l1': DateTime(2025, 3, 1)},
      );
      expect(d.reopenTarget(), DisputeStatus.filedL1);
    });

    test('no filed dates → draft status', () {
      final d = base(status: DisputeStatus.resolved, filedDates: {});
      expect(d.reopenTarget(), DisputeStatus.draft);
    });
  });

  group('DisputeType TAT + compensation invariants', () {
    test('UPI P2P: T+1, ₹100/day', () {
      expect(DisputeType.upiP2p.tatDays, 1);
      expect(DisputeType.upiP2p.compensationPerDay, 100);
      expect(DisputeType.upiP2p.tatBasis, 'T+1');
    });

    test('UPI P2M + ATM + IMPS: T+5', () {
      expect(DisputeType.upiP2m.tatDays, 5);
      expect(DisputeType.atm.tatDays, 5);
      // IMPS is the higher-stakes exception; verified in spec §3.3.
      expect(DisputeType.imps.tatDays, 1);
    });

    test('FASTag / bank_charge / wrong_transfer: no compounding comp', () {
      for (final t in [DisputeType.fastag, DisputeType.bankCharge, DisputeType.wrongTransfer]) {
        expect(t.tatDays, isNull);
        expect(t.compensationPerDay, isNull);
      }
    });

    test('fromId round-trips every id', () {
      for (final t in DisputeType.values) {
        expect(DisputeType.fromId(t.id), t);
      }
    });

    test('fromId default => upi_p2p for unknown', () {
      expect(DisputeType.fromId('does-not-exist'), DisputeType.upiP2p);
    });
  });

  group('DisputeStatus.fromValue', () {
    test('round-trips every value', () {
      for (final s in DisputeStatus.values) {
        expect(DisputeStatus.fromValue(s.value), s);
      }
    });

    test('unknown → draft', () {
      expect(DisputeStatus.fromValue('xxx'), DisputeStatus.draft);
    });
  });
}
