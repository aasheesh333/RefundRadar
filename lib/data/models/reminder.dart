import 'package:refund_radar/data/models/dispute.dart';
import 'package:refund_radar/shared/utils/date_codec.dart';

/// A scheduled reminder derived from a dispute's RBI-mandated timeline.
///
/// Stored at `users/{uid}/reminders/{id}` — one document per reminder.
/// The `id` is deterministic: `'<disputeId>_<stage>'` so that re-running
/// [ReminderGenerator.forDispute] is idempotent (no duplicate reminders).
///
/// Stages (spec §3.3 + §6.6):
///   - `l1_followup`   — bank TAT expiry (30 days after L1 filed)
///   - `l2_escalate`   — escalate to NPCI / acquirer if L1 unreplied
///   - `ombudsman`     — file at ombudsman (cosumer.rbi.org.in) — 90 days from L1
///   - `ombudsman_followup` — if ombudsman ticket unresolved for 30 days
class Reminder {
  /// `'<disputeId>_<stage>'` — deterministic id.
  final String id;
  final String uid;
  final String disputeId;

  /// Which stage of the dispute lifecycle this reminder is for.
  final ReminderStage stage;

  /// Dispute type snapshot — so the list UI doesn't need a join.
  final DisputeType disputeType;

  /// Short title, e.g. "Follow up with HDFC Bank — UPI P2P".
  final String title;

  /// One-line action description shown in the body of the notification.
  final String body;

  /// When the local notification should fire.
  final DateTime fireAt;

  /// Whether the user has dismissed / marked it done — terminal state.
  bool dismissed;

  /// When the reminder was created (for sorting + audit).
  final DateTime createdAt;

  Reminder({
    required this.id,
    this.uid = '',
    required this.disputeId,
    required this.stage,
    required this.disputeType,
    required this.title,
    required this.body,
    required this.fireAt,
    this.dismissed = false,
    required this.createdAt,
  });

  Reminder copyWith({
    String? id,
    String? uid,
    String? disputeId,
    ReminderStage? stage,
    DisputeType? disputeType,
    String? title,
    String? body,
    DateTime? fireAt,
    bool? dismissed,
    DateTime? createdAt,
  }) =>
      Reminder(
        id: id ?? this.id,
        uid: uid ?? this.uid,
        disputeId: disputeId ?? this.disputeId,
        stage: stage ?? this.stage,
        disputeType: disputeType ?? this.disputeType,
        title: title ?? this.title,
        body: body ?? this.body,
        fireAt: fireAt ?? this.fireAt,
        dismissed: dismissed ?? this.dismissed,
        createdAt: createdAt ?? this.createdAt,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'uid': uid,
        'disputeId': disputeId,
        'stage': stage.id,
        'disputeType': disputeType.id,
        'title': title,
        'body': body,
        'fireAt': toUtcIso(fireAt),
        'dismissed': dismissed,
        'createdAt': toUtcIso(createdAt),
      };

  factory Reminder.fromJson(Map<String, dynamic> json) => Reminder(
        id: json['id'] ?? '',
        uid: json['uid'] ?? '',
        disputeId: json['disputeId'] ?? '',
        stage: ReminderStage.fromId(json['stage'] ?? 'l1_followup'),
        disputeType: DisputeType.fromId(json['disputeType'] ?? 'upi_p2p'),
        title: json['title'] ?? '',
        body: json['body'] ?? '',
        fireAt: parseDate(json['fireAt'] as String?) ?? DateTime.now(),
        dismissed: json['dismissed'] ?? false,
        createdAt: parseDate(json['createdAt'] as String?) ?? DateTime.now(),
      );
}

/// Lifecycle stage a reminder belongs to.
enum ReminderStage {
  l1Followup('l1_followup', 'L1 follow-up'),
  l2Escalate('l2_escalate', 'L2 escalate'),
  ombudsman('ombudsman', 'Ombudsman filing'),
  ombudsmanFollowup('ombudsman_followup', 'Ombudsman follow-up');

  final String id;
  final String displayName;
  const ReminderStage(this.id, this.displayName);

  static ReminderStage fromId(String id) =>
      values.firstWhere((e) => e.id == id, orElse: () => ReminderStage.l1Followup);
}
