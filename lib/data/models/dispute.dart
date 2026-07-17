import 'activity_log_entry.dart';
import 'package:refund_radar/shared/utils/date_codec.dart';

enum DisputeType {
  upiP2p('upi_p2p', 1, 100, 'T+1'),
  upiP2m('upi_p2m', 5, 100, 'T+5'),
  atm('atm', 5, 100, 'T+5'),
  imps('imps', 1, 100, 'T+1'),
  fastag('fastag', null, null, '30-day window'),
  bankCharge('bank_charge', null, null, '30+90'),
  wrongTransfer('wrong_transfer', null, null, 'guidance only');

  final String id;
  final int? tatDays;
  final int? compensationPerDay;
  final String tatBasis;
  const DisputeType(this.id, this.tatDays, this.compensationPerDay, this.tatBasis);

  static DisputeType fromId(String id) =>
      values.firstWhere((e) => e.id == id, orElse: () => DisputeType.upiP2p);
}

enum DisputeStatus {
  draft('draft'),
  filedL1('filed_l1'),
  filedL2('filed_l2'),
  ombudsman('ombudsman'),
  resolved('resolved'),
  expired('expired');

  final String value;
  const DisputeStatus(this.value);

  static DisputeStatus fromValue(String v) =>
      values.firstWhere((e) => e.value == v, orElse: () => DisputeStatus.draft);
}

class Dispute {
  final String id;
  final String uid;
  final DisputeType type;
  final DisputeStatus status;
  final double amount;
  final DateTime txnDate;
  final String txnId;
  final String? entityName;
  final String? entityId;
  final Map<String, DateTime?> filedDates;
  final Map<String, String?> ticketNumbers;
  final double? resolvedAmount;
  final DateTime? resolvedAt;
  final List<String> evidence;
  final DateTime createdAt;
  final String? description;
  final List<ActivityLogEntry> activityLog;

  const Dispute({
    required this.id,
    this.uid = '',
    required this.type,
    this.status = DisputeStatus.draft,
    required this.amount,
    required this.txnDate,
    required this.txnId,
    this.entityName,
    this.entityId,
    this.filedDates = const {},
    this.ticketNumbers = const {},
    this.resolvedAmount,
    this.resolvedAt,
    this.evidence = const [],
    required this.createdAt,
    this.description,
    this.activityLog = const [],
  });

  static const Object _unset = Object();

  Dispute copyWith({
    String? id,
    String? uid,
    DisputeType? type,
    DisputeStatus? status,
    double? amount,
    DateTime? txnDate,
    String? txnId,
    String? entityName,
    String? entityId,
    Map<String, DateTime?>? filedDates,
    Map<String, String?>? ticketNumbers,
    Object? resolvedAmount = _unset,
    Object? resolvedAt = _unset,
    List<String>? evidence,
    DateTime? createdAt,
    Object? description = _unset,
    List<ActivityLogEntry>? activityLog,
  }) =>
      Dispute(
        id: id ?? this.id,
        uid: uid ?? this.uid,
        type: type ?? this.type,
        status: status ?? this.status,
        amount: amount ?? this.amount,
        txnDate: txnDate ?? this.txnDate,
        txnId: txnId ?? this.txnId,
        entityName: entityName ?? this.entityName,
        entityId: entityId ?? this.entityId,
        filedDates: filedDates ?? this.filedDates,
        ticketNumbers: ticketNumbers ?? this.ticketNumbers,
        resolvedAmount: identical(resolvedAmount, _unset)
            ? this.resolvedAmount
            : (resolvedAmount == null
                ? null
                : (resolvedAmount as num).toDouble()),
        resolvedAt: identical(resolvedAt, _unset)
            ? this.resolvedAt
            : resolvedAt as DateTime?,
        evidence: evidence ?? this.evidence,
        createdAt: createdAt ?? this.createdAt,
        description: identical(description, _unset)
            ? this.description
            : description as String?,
        activityLog: activityLog ?? this.activityLog,
      );

  DisputeStatus reopenTarget() {
    if (status == DisputeStatus.expired) {
      if (filedDates['ombudsman'] != null) return DisputeStatus.ombudsman;
      if (filedDates['l2'] != null) return DisputeStatus.filedL2;
      if (filedDates['l1'] != null) return DisputeStatus.filedL1;
      return DisputeStatus.draft;
    }
    if (filedDates['ombudsman'] != null) return DisputeStatus.ombudsman;
    if (filedDates['l2'] != null) return DisputeStatus.filedL2;
    if (filedDates['l1'] != null) return DisputeStatus.filedL1;
    return DisputeStatus.draft;
  }

  /// The most recent activity date for this dispute. Used to compute the
  /// 90-day inactivity auto-expiry window.
  DateTime get lastActivityDate {
    final dates = filedDates.values.whereType<DateTime>().toList();
    if (dates.isEmpty) return createdAt;
    return dates.reduce((a, b) => a.isAfter(b) ? a : b);
  }

  /// True if this dispute should be marked expired due to 90 days of
  /// inactivity. Terminal statuses and drafts are never auto-expired.
  bool shouldAutoExpire(DateTime now) {
    if (status == DisputeStatus.resolved ||
        status == DisputeStatus.expired ||
        status == DisputeStatus.draft) {
      return false;
    }
    return now.difference(lastActivityDate).inDays > 90;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'uid': uid,
        'type': type.id,
        'status': status.value,
        'amount': amount,
        'txnDate': toUtcIso(txnDate),
        'txnId': txnId,
        'entityName': entityName,
        'entityId': entityId,
        'filedDates':
            filedDates.map((k, v) => MapEntry(k, v == null ? null : toUtcIso(v))),
        'ticketNumbers': ticketNumbers,
        'resolvedAmount': resolvedAmount,
        'resolvedAt': resolvedAt == null ? null : toUtcIso(resolvedAt!),
        'evidence': evidence,
        'createdAt': toUtcIso(createdAt),
        'description': description,
        'activityLog': activityLog.map((e) => e.toJson()).toList(),
      };

  factory Dispute.fromJson(Map<String, dynamic> json) => Dispute(
        id: json['id'] ?? '',
        uid: json['uid'] ?? '',
        type: DisputeType.fromId(json['type'] ?? 'upi_p2p'),
        status: DisputeStatus.fromValue(json['status'] ?? 'draft'),
        amount: (json['amount'] as num? ?? 0).toDouble(),
        // parseDate handles both UTC (Z) and legacy offset-less local
        // strings. Fallback to now() only on truly unparseable input so
        // the model stays non-nullable; the UTC write path prevents future
        // corruption, and a corrupt legacy txnDate no longer silently
        // zeros compensation (it falls back to "today" which yields ₹0 —
        // surfaced as a ₹0 estimate the user will notice and re-enter).
        txnDate: parseDate(json['txnDate'] as String?) ?? DateTime.now(),
        txnId: json['txnId'] ?? '',
        entityName: json['entityName'],
        entityId: json['entityId'],
        filedDates:
            (json['filedDates'] as Map<String, dynamic>?)?.map((k, v) =>
                    MapEntry(k, v == null ? null : parseDate(v as String?))) ??
                <String, DateTime?>{},
        ticketNumbers: (json['ticketNumbers'] as Map<String, dynamic>?)?.map(
                (k, v) => MapEntry(k, v as String?)) ??
            <String, String?>{},
        resolvedAmount: json['resolvedAmount'] == null
            ? null
            : (json['resolvedAmount'] as num).toDouble(),
        resolvedAt: parseDate(json['resolvedAt'] as String?),
        evidence: List<String>.from(json['evidence'] ?? []),
        createdAt: parseDate(json['createdAt'] as String?) ?? DateTime.now(),
        description: json['description'] as String?,
        activityLog: (json['activityLog'] as List?)
                ?.map((e) => ActivityLogEntry.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}
