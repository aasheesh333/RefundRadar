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

  // -- Category-specific data (Wave 2 - Extended) ---------------------------
  // Captured at dispute-create time so escalation-email merge tokens are
  // pre-filled and the user only has to tap Send. All optional.
  final String? vpa;
  final String? vpaPayee;
  final String? vehicleNo;
  final String? plazaName;
  final String? atmId;
  final String? cardLast4;
  final String? beneficiaryAccountNo;
  final String? beneficiaryIfsc;
  // Advanced/Legal-specific fields (for advanced/legal templates)
  final String? fdReceiptNo;
  final String? lockerNo;
  final DateTime? nocDate;
  final String? tagId;
  final String? loanAgreementRef;
  final String? advocateName;
  final String? pioOffice;
  final String? localPoliceStation;
  final String? harassmentClaimAmount;
  final String? hoursLost;
  // Additional legal doc fields (appeals, court cases)
  final String? appealNo;
  final String? caseNo;
  final DateTime? agreementDate;
  final String? fdNumber;

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
    this.vpa,
    this.vpaPayee,
    this.vehicleNo,
    this.plazaName,
    this.atmId,
    this.cardLast4,
    this.beneficiaryAccountNo,
    this.beneficiaryIfsc,
    this.fdReceiptNo,
    this.lockerNo,
    this.nocDate,
    this.tagId,
    this.loanAgreementRef,
    this.advocateName,
    this.pioOffice,
    this.localPoliceStation,
    this.harassmentClaimAmount,
    this.hoursLost,
    this.appealNo,
    this.caseNo,
    this.agreementDate,
    this.fdNumber,
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
    Object? vpa = _unset,
    Object? vpaPayee = _unset,
    Object? vehicleNo = _unset,
    Object? plazaName = _unset,
    Object? atmId = _unset,
    Object? cardLast4 = _unset,
    Object? beneficiaryAccountNo = _unset,
    Object? beneficiaryIfsc = _unset,
    Object? fdReceiptNo = _unset,
    Object? lockerNo = _unset,
    Object? nocDate = _unset,
    Object? tagId = _unset,
    Object? loanAgreementRef = _unset,
    Object? advocateName = _unset,
    Object? pioOffice = _unset,
    Object? localPoliceStation = _unset,
    Object? harassmentClaimAmount = _unset,
    Object? hoursLost = _unset,
    Object? appealNo = _unset,
    Object? caseNo = _unset,
    Object? agreementDate = _unset,
    Object? fdNumber = _unset,
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
        vpa: identical(vpa, _unset) ? this.vpa : vpa as String?,
        vpaPayee: identical(vpaPayee, _unset)
            ? this.vpaPayee
            : vpaPayee as String?,
        vehicleNo: identical(vehicleNo, _unset)
            ? this.vehicleNo
            : vehicleNo as String?,
        plazaName: identical(plazaName, _unset)
            ? this.plazaName
            : plazaName as String?,
        atmId: identical(atmId, _unset) ? this.atmId : atmId as String?,
        cardLast4: identical(cardLast4, _unset)
            ? this.cardLast4
            : cardLast4 as String?,
        beneficiaryAccountNo: identical(beneficiaryAccountNo, _unset)
            ? this.beneficiaryAccountNo
            : beneficiaryAccountNo as String?,
        beneficiaryIfsc: identical(beneficiaryIfsc, _unset)
            ? this.beneficiaryIfsc
            : beneficiaryIfsc as String?,
        fdReceiptNo: identical(fdReceiptNo, _unset)
            ? this.fdReceiptNo
            : fdReceiptNo as String?,
        lockerNo: identical(lockerNo, _unset)
            ? this.lockerNo
            : lockerNo as String?,
        nocDate: identical(nocDate, _unset)
            ? this.nocDate
            : nocDate as DateTime?,
        tagId: identical(tagId, _unset) ? this.tagId : tagId as String?,
        loanAgreementRef: identical(loanAgreementRef, _unset)
            ? this.loanAgreementRef
            : loanAgreementRef as String?,
        advocateName: identical(advocateName, _unset)
            ? this.advocateName
            : advocateName as String?,
        pioOffice: identical(pioOffice, _unset)
            ? this.pioOffice
            : pioOffice as String?,
        localPoliceStation: identical(localPoliceStation, _unset)
            ? this.localPoliceStation
            : localPoliceStation as String?,
        harassmentClaimAmount: identical(harassmentClaimAmount, _unset)
            ? this.harassmentClaimAmount
            : harassmentClaimAmount as String?,
        hoursLost: identical(hoursLost, _unset)
            ? this.hoursLost
            : hoursLost as String?,
        appealNo: identical(appealNo, _unset)
            ? this.appealNo
            : appealNo as String?,
        caseNo: identical(caseNo, _unset)
            ? this.caseNo
            : caseNo as String?,
        agreementDate: identical(agreementDate, _unset)
            ? this.agreementDate
            : agreementDate as DateTime?,
        fdNumber: identical(fdNumber, _unset)
            ? this.fdNumber
            : fdNumber as String?,
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
        'vpa': vpa,
        'vpaPayee': vpaPayee,
        'vehicleNo': vehicleNo,
        'plazaName': plazaName,
        'atmId': atmId,
        'cardLast4': cardLast4,
        'beneficiaryAccountNo': beneficiaryAccountNo,
        'beneficiaryIfsc': beneficiaryIfsc,
        'fdReceiptNo': fdReceiptNo,
        'lockerNo': lockerNo,
        'nocDate': nocDate == null ? null : toUtcIso(nocDate!),
        'tagId': tagId,
        'loanAgreementRef': loanAgreementRef,
        'advocateName': advocateName,
        'pioOffice': pioOffice,
        'localPoliceStation': localPoliceStation,
        'harassmentClaimAmount': harassmentClaimAmount,
        'hoursLost': hoursLost,
        'appealNo': appealNo,
        'caseNo': caseNo,
        'agreementDate': agreementDate == null ? null : toUtcIso(agreementDate!),
        'fdNumber': fdNumber,
      };

  factory Dispute.fromJson(Map<String, dynamic> json) => Dispute(
        id: json['id'] ?? '',
        uid: json['uid'] ?? '',
        type: DisputeType.fromId(json['type'] ?? 'upi_p2p'),
        status: DisputeStatus.fromValue(json['status'] ?? 'draft'),
        amount: (json['amount'] as num? ?? 0).toDouble(),
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
        vpa: json['vpa'] as String?,
        vpaPayee: json['vpaPayee'] as String?,
        vehicleNo: json['vehicleNo'] as String?,
        plazaName: json['plazaName'] as String?,
        atmId: json['atmId'] as String?,
        cardLast4: json['cardLast4'] as String?,
        beneficiaryAccountNo: json['beneficiaryAccountNo'] as String?,
        beneficiaryIfsc: json['beneficiaryIfsc'] as String?,
        fdReceiptNo: json['fdReceiptNo'] as String?,
        lockerNo: json['lockerNo'] as String?,
        nocDate: parseDate(json['nocDate'] as String?),
        tagId: json['tagId'] as String?,
        loanAgreementRef: json['loanAgreementRef'] as String?,
        advocateName: json['advocateName'] as String?,
        pioOffice: json['pioOffice'] as String?,
        localPoliceStation: json['localPoliceStation'] as String?,
        harassmentClaimAmount: json['harassmentClaimAmount'] as String?,
        hoursLost: json['hoursLost'] as String?,
        appealNo: json['appealNo'] as String?,
        caseNo: json['caseNo'] as String?,
        agreementDate: parseDate(json['agreementDate'] as String?),
        fdNumber: json['fdNumber'] as String?,
      );
}
