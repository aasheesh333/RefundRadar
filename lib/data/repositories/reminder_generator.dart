import 'package:refund_radar/data/models/dispute.dart';
import 'package:refund_radar/data/models/reminder.dart';

/// Derives the set of [Reminder]s a given dispute should produce, based on
/// its current lifecycle stage and the spec's RBI-mandated TAT windows
/// (spec §3.3 + §6.6 timeline table).
///
/// Idempotent: for the same dispute, [forDispute] always returns the same
/// set of reminder ids (`'<disputeId>_<stage>'`). The repository's
/// `syncForDispute()` upserts only — it never creates duplicates.
class ReminderGenerator {
  const ReminderGenerator();

  /// Returns the reminders that are still *actionable* for [d]:
  /// we stop emitting future-stage reminders once the dispute has
  /// progressed past them (e.g. once `status == ombudsman`, we no
  /// longer schedule `l1_followup` — it's already past).
  List<Reminder> forDispute(Dispute d, {DateTime? now}) {
    final effectiveNow = now ?? DateTime.now();
    final out = <Reminder>[];

    // ----- L1 follow-up: 30 days after filing L1 (bank charge / UPI / etc.) -----
    final l1Filed = d.filedDates['l1'];
    if (l1Filed != null && d.status != DisputeStatus.resolved && d.status != DisputeStatus.expired) {
      final fire = l1Filed.add(const Duration(days: 30));
      if (fire.isAfter(effectiveNow) && d.status == DisputeStatus.filedL1) {
        out.add(_make(
          d,
          ReminderStage.l1Followup,
          fire,
          'L1 follow-up due',
          "${d.type == DisputeType.fastag ? 'IHMCL / acquirer' : 'bank'} hasn't replied in 30 days. Escalate to L2.",
          now: effectiveNow,
        ));
      }
    }

    // ----- L2 escalation: 7 days after L2 filing (or 37 days after L1) -----
    final l2Filed = d.filedDates['l2'];
    if (l2Filed != null && d.status != DisputeStatus.resolved && d.status != DisputeStatus.expired) {
      final fire = l2Filed.add(const Duration(days: 7));
      if (fire.isAfter(effectiveNow) && d.status == DisputeStatus.filedL2) {
        out.add(_make(
          d,
          ReminderStage.l2Escalate,
          fire,
          'Escalate to Ombudsman',
          'L2 unresolved for 7 days. File at consumer.rbi.org.in (L3 / Ombudsman).',
          now: effectiveNow,
        ));
      }
    }

    // ----- Ombudsman follow-up: 30 days after ombudsman filing -----
    final ombudsmanFiled = d.filedDates['ombudsman'];
    if (ombudsmanFiled != null &&
        d.status == DisputeStatus.ombudsman &&
        d.status != DisputeStatus.resolved) {
      final fire = ombudsmanFiled.add(const Duration(days: 30));
      if (fire.isAfter(effectiveNow)) {
        out.add(_make(
          d,
          ReminderStage.ombudsmanFollowup,
          fire,
          'Ombudsman follow-up',
          'Ombudsman complaint unresolved for 30 days. Check status at consumer.rbi.org.in.',
          now: effectiveNow,
        ));
      }
    }

    // ----- FASTag / wrong-transfer special: if no L1 yet and TAT window
    //       is open, remind user to file L1 within 7 days of dispute creation. -----
    if (d.filedDates['l1'] == null && d.status == DisputeStatus.draft) {
      final fire = d.createdAt.add(const Duration(days: 7));
      if (fire.isAfter(effectiveNow)) {
        out.add(_make(
          d,
          ReminderStage.l1Followup,
          fire,
          'File L1 complaint',
          'File your initial complaint with the ${_targetName(d)} within your TAT window.',
          now: effectiveNow,
        ));
      }
    }

    return out;
  }

  Reminder _make(Dispute d, ReminderStage stage, DateTime fire, String title, String body, {DateTime? now}) {
    return Reminder(
      id: '${d.id}_${stage.id}',
      uid: d.uid,
      disputeId: d.id,
      stage: stage,
      disputeType: d.type,
      title: title,
      body: body,
      fireAt: fire,
      createdAt: now ?? DateTime.now(),
    );
  }

  String _targetName(Dispute d) {
    switch (d.type) {
      case DisputeType.fastag:
        return d.entityName ?? 'FASTag issuer / IHMCL';
      case DisputeType.upiP2p:
      case DisputeType.upiP2m:
      case DisputeType.atm:
      case DisputeType.imps:
      case DisputeType.wrongTransfer:
        return d.entityName ?? 'bank';
      case DisputeType.bankCharge:
        return d.entityName ?? 'bank';
    }
  }
}
