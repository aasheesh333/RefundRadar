import 'package:flutter_test/flutter_test.dart';
import 'package:refund_radar/data/models/dispute.dart';
import 'package:refund_radar/data/models/reminder.dart';
import 'package:refund_radar/data/repositories/reminder_generator.dart';

/// All tests pin `now` to `2025-04-15` so we can exercise both "before TAT
/// window" and "after TAT window" branches deterministically.
void main() {
  const gen = ReminderGenerator();
  final now = DateTime(2025, 4, 15);

  Dispute base({
    String id = 'd1',
    String uid = 'u1',
    DisputeType type = DisputeType.upiP2p,
    DisputeStatus status = DisputeStatus.filedL1,
    Map<String, DateTime?>? filedDates,
    DateTime? createdAt,
    DateTime? txnDate,
  }) =>
      Dispute(
        id: id,
        uid: uid,
        type: type,
        status: status,
        amount: 1500,
        txnDate: txnDate ?? DateTime(2025, 1, 1),
        txnId: 'UTR1',
        filedDates: filedDates ?? const {},
        createdAt: createdAt ?? DateTime(2025, 1, 1),
      );

  group('L1 follow-up (30d after L1 filing)', () {
    test('schedules L1 followup when due date is in future + status == filedL1', () {
      // L1 filed 2025-04-01 → fire 2025-05-01 (16 days from `now`)
      final d = base(
        status: DisputeStatus.filedL1,
        filedDates: {'l1': DateTime(2025, 4, 1)},
      );
      final out = gen.forDispute(d, now: now);
      expect(out, hasLength(1));
      expect(out.first.stage, ReminderStage.l1Followup);
      expect(out.first.fireAt, DateTime(2025, 5, 1));
      expect(out.first.id, 'd1_l1_followup');
      expect(out.first.disputeType, DisputeType.upiP2p);
      // Body references the bank (since type != fastag, no issuer override).
      expect(out.first.body, contains("bank hasn't replied"));
    });

    test('skips L1 followup when TAT already expired (fireDate <= now)', () {
      // L1 filed 2025-03-01 → fire 2025-03-31, which is BEFORE `now`.
      final d = base(
        status: DisputeStatus.filedL1,
        filedDates: {'l1': DateTime(2025, 3, 1)},
      );
      final out = gen.forDispute(d, now: now);
      expect(out, isEmpty);
    });

    test('skips when dispute is already resolved', () {
      final d = base(
        status: DisputeStatus.resolved,
        filedDates: {'l1': DateTime(2025, 4, 1)},
      );
      expect(gen.forDispute(d, now: now), isEmpty);
    });

    test('skips when dispute is expired', () {
      final d = base(
        status: DisputeStatus.expired,
        filedDates: {'l1': DateTime(2025, 4, 1)},
      );
      expect(gen.forDispute(d, now: now), isEmpty);
    });

    test('skips when status advanced past filedL1 (e.g. filedL2)', () {
      final d = base(
        status: DisputeStatus.filedL2,
        filedDates: {
          'l1': DateTime(2025, 4, 1),
          'l2': null, // not yet filed
        },
      );
      final out = gen.forDispute(d, now: now);
      // L1 followup suppressed (status advanced); L2 reminder also suppressed
      // because l2 filedDate is null.
      expect(out, isEmpty);
    });

    test('FASTag dispute mentions IHMCL / acquirer in body', () {
      final d = base(
        type: DisputeType.fastag,
        status: DisputeStatus.filedL1,
        filedDates: {'l1': DateTime(2025, 4, 1)},
      );
      final out = gen.forDispute(d, now: now);
      expect(out, hasLength(1));
      expect(out.first.body, contains('IHMCL / acquirer'));
    });
  });

  group('L2 escalation (7d after L2 filing)', () {
    test('schedules when L2 + 7d is in future + status == filedL2', () {
      final d = base(
        status: DisputeStatus.filedL2,
        filedDates: {
          'l1': DateTime(2025, 3, 1),
          'l2': DateTime(2025, 4, 12),
        },
      );
      final out = gen.forDispute(d, now: now);
      expect(out, hasLength(1));
      expect(out.first.stage, ReminderStage.l2Escalate);
      expect(out.first.fireAt, DateTime(2025, 4, 19));
      expect(out.first.body, contains('consumer.rbi.org.in'));
    });

    test('skips when L2 TAT already expired', () {
      final d = base(
        status: DisputeStatus.filedL2,
        filedDates: {
          'l1': DateTime(2025, 2, 1),
          'l2': DateTime(2025, 3, 1), // +7d = 2025-03-08, way past now
        },
      );
      expect(gen.forDispute(d, now: now), isEmpty);
    });

    test('skips when L2 not yet filed (filedDates[l2] == null)', () {
      final d = base(
        status: DisputeStatus.filedL2,
        filedDates: {'l1': DateTime(2025, 4, 1)},
      );
      // Even though status is filedL2, no L2 date → no reminder to schedule.
      expect(gen.forDispute(d, now: now), isEmpty);
    });
  });

  group('Ombudsman follow-up (30d after ombudsman filing)', () {
    test('schedules when status == ombudsman and fireDate is future', () {
      final d = base(
        status: DisputeStatus.ombudsman,
        filedDates: {
          'l1': DateTime(2025, 1, 1),
          'l2': DateTime(2025, 2, 1),
          'ombudsman': DateTime(2025, 4, 1),
        },
      );
      final out = gen.forDispute(d, now: now);
      expect(out, hasLength(1));
      expect(out.first.stage, ReminderStage.ombudsmanFollowup);
      expect(out.first.fireAt, DateTime(2025, 5, 1));
    });

    test('skips when resolved (status wins over ombudsman)', () {
      final d = base(
        status: DisputeStatus.resolved,
        filedDates: {'ombudsman': DateTime(2025, 4, 1)},
      );
      expect(gen.forDispute(d, now: now), isEmpty);
    });
  });

  group('Draft + no L1 filed yet — file-L1 draft reminder (7d from createdAt)', () {
    test('fires if createdAt + 7d > now and status == draft', () {
      final d = base(
        status: DisputeStatus.draft,
        filedDates: const {},
        createdAt: DateTime(2025, 4, 12), // +7d = 2025-04-19, after now
      );
      final out = gen.forDispute(d, now: now);
      expect(out, hasLength(1));
      expect(out.first.stage, ReminderStage.l1Followup);
      expect(out.first.title, 'File L1 complaint');
      expect(out.first.body, contains('bank'));
    });

    test('does not fire when 7-day draft window already expired', () {
      final d = base(
        status: DisputeStatus.draft,
        filedDates: const {},
        createdAt: DateTime(2025, 3, 1), // +7d = 2025-03-08, before now
      );
      final out = gen.forDispute(d, now: now);
      expect(out, isEmpty);
    });

    test('does not fire draft reminder if L1 already filed', () {
      final d = base(
        status: DisputeStatus.draft,
        filedDates: {'l1': DateTime(2025, 4, 10)},
        createdAt: DateTime(2025, 4, 12),
      );
      // filedDates['l1'] != null short-circuits the draft branch.
      // Also status = draft, so the L1-followup branch also doesn't fire
      // (it requires status == filedL1).
      expect(gen.forDispute(d, now: now), isEmpty);
    });

    test('FASTag draft reminder mentions the configured issuer', () {
      // When a FASTag draft has an `entityName` set (the issuer), the
      // body should mention it instead of the generic default.
      final d = Dispute(
        id: 'd1',
        uid: 'u1',
        type: DisputeType.fastag,
        status: DisputeStatus.draft,
        amount: 200,
        txnDate: DateTime(2025, 4, 1),
        txnId: 'UTR1',
        filedDates: const {},
        entityName: 'Paytm FASTag',
        createdAt: DateTime(2025, 4, 12),
      );
      final out = gen.forDispute(d, now: now);
      expect(out, hasLength(1));
      expect(out.first.body, contains('Paytm FASTag'));
    });

    test('draft reminder falls back to default issuer name when entityName is null', () {
      final d = Dispute(
        id: 'd1',
        uid: 'u1',
        type: DisputeType.fastag,
        status: DisputeStatus.draft,
        amount: 200,
        txnDate: DateTime(2025, 4, 1),
        txnId: 'UTR1',
        filedDates: const {},
        createdAt: DateTime(2025, 4, 12),
      );
      final out = gen.forDispute(d, now: now);
      expect(out, hasLength(1));
      expect(out.first.body, contains('FASTag issuer / IHMCL'));
    });
  });

  group('Idempotency + deterministic ids', () {
    test('same dispute yields same reminder ids across calls', () {
      final d = base(
        status: DisputeStatus.filedL1,
        filedDates: {'l1': DateTime(2025, 4, 1)},
      );
      final out1 = gen.forDispute(d, now: now);
      final out2 = gen.forDispute(d, now: now);
      expect(out1.map((r) => r.id), out2.map((r) => r.id));
      expect(out1.first.id, 'd1_l1_followup');
    });

    test('two distinct disputes produce distinct ids', () {
      final d1 = base(id: 'a', filedDates: {'l1': DateTime(2025, 4, 1)});
      final d2 = base(id: 'b', filedDates: {'l1': DateTime(2025, 4, 1)});
      final o1 = gen.forDispute(d1, now: now);
      final o2 = gen.forDispute(d2, now: now);
      expect(o1.first.id, 'a_l1_followup');
      expect(o2.first.id, 'b_l1_followup');
      expect(o1.first.id, isNot(o2.first.id));
    });
  });

  group('Reminder snapshot fields', () {
    test('reminder carries dispute uid + type for list UI', () {
      final d = Dispute(
        id: 'd1',
        uid: 'user-42',
        type: DisputeType.imps,
        status: DisputeStatus.filedL1,
        amount: 5000,
        txnDate: DateTime(2025, 1, 1),
        txnId: 'UTR',
        filedDates: {'l1': DateTime(2025, 4, 1)},
        createdAt: DateTime(2025, 1, 1),
      );
      final out = gen.forDispute(d, now: now);
      expect(out, hasLength(1));
      expect(out.first.uid, 'user-42');
      expect(out.first.disputeId, 'd1');
      expect(out.first.disputeType, DisputeType.imps);
    });

    test('createdAt uses the injected `now` (deterministic for tests)', () {
      final d = base(
        status: DisputeStatus.filedL1,
        filedDates: {'l1': DateTime(2025, 4, 1)},
      );
      final out = gen.forDispute(d, now: now);
      expect(out.first.createdAt, now);
    });

    test('dismissed defaults to false', () {
      final d = base(
        status: DisputeStatus.filedL1,
        filedDates: {'l1': DateTime(2025, 4, 1)},
      );
      final out = gen.forDispute(d, now: now);
      expect(out.first.dismissed, isFalse);
    });
  });
}
