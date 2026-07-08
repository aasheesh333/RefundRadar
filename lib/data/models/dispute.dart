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
  });

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
    double? resolvedAmount,
    DateTime? resolvedAt,
    List<String>? evidence,
    DateTime? createdAt,
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
        resolvedAmount: resolvedAmount ?? this.resolvedAmount,
        resolvedAt: resolvedAt ?? this.resolvedAt,
        evidence: evidence ?? this.evidence,
        createdAt: createdAt ?? this.createdAt,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'uid': uid,
        'type': type.id,
        'status': status.value,
        'amount': amount,
        'txnDate': txnDate.toIso8601String(),
        'txnId': txnId,
        'entityName': entityName,
        'entityId': entityId,
        'filedDates': filedDates.map((k, v) => MapEntry(k, v?.toIso8601String())),
        'ticketNumbers': ticketNumbers,
        'resolvedAmount': resolvedAmount,
        'resolvedAt': resolvedAt?.toIso8601String(),
        'evidence': evidence,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Dispute.fromJson(Map<String, dynamic> json) => Dispute(
        id: json['id'] ?? '',
        uid: json['uid'] ?? '',
        type: DisputeType.fromId(json['type'] ?? 'upi_p2p'),
        status: DisputeStatus.fromValue(json['status'] ?? 'draft'),
        amount: (json['amount'] ?? 0).toDouble(),
        txnDate: DateTime.tryParse(json['txnDate'] ?? '') ?? DateTime.now(),
        txnId: json['txnId'] ?? '',
        entityName: json['entityName'],
        entityId: json['entityId'],
        filedDates: (json['filedDates'] as Map<String, dynamic>?)?.map(
                (k, v) => MapEntry(k, v == null ? null : DateTime.tryParse(v))) ??
            <String, DateTime?>{},
        ticketNumbers: (json['ticketNumbers'] as Map<String, dynamic>?)?.map(
                (k, v) => MapEntry(k, v as String?)) ??
            <String, String?>{},
        resolvedAmount: (json['resolvedAmount'] ?? 0).toDouble(),
        resolvedAt: DateTime.tryParse(json['resolvedAt'] ?? ''),
        evidence: List<String>.from(json['evidence'] ?? []),
        createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      );
}
