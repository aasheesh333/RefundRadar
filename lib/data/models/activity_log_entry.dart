/// A single entry in a dispute's activity log.
/// Stored as a list on the Dispute document in Firestore.
class ActivityLogEntry {
  final String type;
  final String label;
  final String meta;
  final DateTime timestamp;
  final bool highlighted;

  const ActivityLogEntry({
    required this.type,
    required this.label,
    required this.meta,
    required this.timestamp,
    this.highlighted = false,
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        'label': label,
        'meta': meta,
        'timestamp': timestamp.toIso8601String(),
        'highlighted': highlighted,
      };

  factory ActivityLogEntry.fromJson(Map<String, dynamic> json) {
    return ActivityLogEntry(
      type: json['type'] as String? ?? '',
      label: json['label'] as String? ?? '',
      meta: json['meta'] as String? ?? '',
      timestamp:
          DateTime.tryParse(json['timestamp'] as String? ?? '') ??
              DateTime.now(),
      highlighted: json['highlighted'] as bool? ?? false,
    );
  }

  /// Event type constants
  static const disputeCreated = 'dispute_created';
  static const l1TicketFiled = 'l1_ticket_filed';
  static const l2TicketFiled = 'l2_ticket_filed';
  static const escalationEmailSent = 'escalation_email_sent';
  static const templateUsed = 'template_used';
  static const statusChanged = 'status_changed';
  static const reminderFired = 'reminder_fired';
  static const resolved = 'resolved';
  static const utrDetected = 'utr_detected';
}
