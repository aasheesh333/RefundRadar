import '../../shared/utils/date_codec.dart';

/// A locally-persisted, in-progress dispute the user started but never
/// submitted ("Save as draft" in the create flow). Drafts live ONLY in
/// SharedPreferences — they are device-local, never synced to Firestore —
/// and are discarded once the user completes (or abandons) the create
/// wizard.
///
/// [typeId] matches `DisputeType.id` (e.g. `'upi_p2p'`, `'fastag'`),
/// NOT the enum name. Nullable because a user can save a draft before
/// picking a type.
class DisputeDraft {
  final String id;
  final String? typeId;
  final String? bankId;
  final String? entityName;
  final String? utr;
  final double? amount;
  final DateTime? incidentDate;
  final String? description;
  final DateTime savedAt;

  const DisputeDraft({
    required this.id,
    this.typeId,
    this.bankId,
    this.entityName,
    this.utr,
    this.amount,
    this.incidentDate,
    this.description,
    required this.savedAt,
  });

  static const Object _unset = Object();

  DisputeDraft copyWith({
    String? id,
    Object? typeId = _unset,
    Object? bankId = _unset,
    Object? entityName = _unset,
    Object? utr = _unset,
    Object? amount = _unset,
    Object? incidentDate = _unset,
    Object? description = _unset,
    DateTime? savedAt,
  }) =>
      DisputeDraft(
        id: id ?? this.id,
        typeId: identical(typeId, _unset) ? this.typeId : typeId as String?,
        bankId: identical(bankId, _unset) ? this.bankId : bankId as String?,
        entityName: identical(entityName, _unset)
            ? this.entityName
            : entityName as String?,
        utr: identical(utr, _unset) ? this.utr : utr as String?,
        amount: identical(amount, _unset)
            ? this.amount
            : (amount == null ? null : (amount as num).toDouble()),
        incidentDate: identical(incidentDate, _unset)
            ? this.incidentDate
            : incidentDate as DateTime?,
        description: identical(description, _unset)
            ? this.description
            : description as String?,
        savedAt: savedAt ?? this.savedAt,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'typeId': typeId,
        'bankId': bankId,
        'entityName': entityName,
        'utr': utr,
        'amount': amount,
        'incidentDate':
            incidentDate == null ? null : toUtcIso(incidentDate!),
        'description': description,
        'savedAt': toUtcIso(savedAt),
      };

  factory DisputeDraft.fromJson(Map<String, dynamic> json) => DisputeDraft(
        id: json['id'] as String? ?? '',
        typeId: json['typeId'] as String?,
        bankId: json['bankId'] as String?,
        entityName: json['entityName'] as String?,
        utr: json['utr'] as String?,
        amount: (json['amount'] as num?)?.toDouble(),
        incidentDate: parseDate(json['incidentDate'] as String?),
        description: json['description'] as String?,
        savedAt: parseDate(json['savedAt'] as String?) ?? DateTime.now(),
      );
}
