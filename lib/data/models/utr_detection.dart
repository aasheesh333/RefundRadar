/// One UTR auto-detected from an incoming SMS (Task C4).
///
/// Emitted by [utrDetectionProvider] every time the live SMS receiver
/// (Kotlin `SmsReceiver` → `refund_radar/sms_events` MethodChannel) hands
/// us an SMS whose body [SmsParser] can extract a UTR from. The UI keeps
/// a list of these so unclaimed detections show a banner on Home; tapping
/// the banner opens the dispute form pre-filled.
///
/// `claimed` is flipped true on the in-memory copy once the user starts a
/// dispute from this detection (or dismisses it). Persisting the model is
/// out of scope for Track C — only the live session list is kept.
class UtrDetection {
  final String utr;
  final double? amount;
  final DateTime? date;
  final String sender;
  final String smsBody;
  final bool claimed;
  final DateTime detectedAt;

  const UtrDetection({
    required this.utr,
    this.amount,
    this.date,
    required this.sender,
    required this.smsBody,
    this.claimed = false,
    required this.detectedAt,
  });

  Map<String, dynamic> toJson() => {
        'utr': utr,
        'amount': amount,
        'date': date?.toIso8601String(),
        'sender': sender,
        'smsBody': smsBody,
        'claimed': claimed,
        'detectedAt': detectedAt.toIso8601String(),
      };

  factory UtrDetection.fromJson(Map<String, dynamic> json) => UtrDetection(
        utr: json['utr'] as String? ?? '',
        amount: (json['amount'] as num?)?.toDouble(),
        date: json['date'] != null
            ? DateTime.tryParse(json['date'] as String)
            : null,
        sender: json['sender'] as String? ?? '',
        smsBody: json['smsBody'] as String? ?? '',
        claimed: json['claimed'] as bool? ?? false,
        detectedAt:
            DateTime.tryParse(json['detectedAt'] as String? ?? '') ??
                DateTime.now(),
      );

  UtrDetection copyWith({
    String? utr,
    double? amount,
    DateTime? date,
    String? sender,
    String? smsBody,
    bool? claimed,
    DateTime? detectedAt,
  }) =>
      UtrDetection(
        utr: utr ?? this.utr,
        amount: amount ?? this.amount,
        date: date ?? this.date,
        sender: sender ?? this.sender,
        smsBody: smsBody ?? this.smsBody,
        claimed: claimed ?? this.claimed,
        detectedAt: detectedAt ?? this.detectedAt,
      );

  @override
  String toString() =>
      'UtrDetection(utr=$utr, amount=$amount, sender=$sender, claimed=$claimed)';
}
