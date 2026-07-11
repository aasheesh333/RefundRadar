import 'package:flutter/material.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_theme_colors.dart';
import '../../data/models/activity_log_entry.dart';

/// A single activity-log entry — matches mockup Screen 7.
///
/// `type` is optional so legacy computed entries (without a persisted
/// [ActivityLogEntry]) still render. When [type] is provided, the widget
/// shows a type-specific icon; otherwise it falls back to a neutral dot.
class ActivityEntry {
  final String label;
  final String meta;
  final bool highlighted;
  final String? type;
  const ActivityEntry({
    required this.label,
    required this.meta,
    this.highlighted = false,
    this.type,
  });

  /// Convenience factory that adapts a persisted [ActivityLogEntry] into the
  /// display model the widget expects.
  factory ActivityEntry.fromLogEntry(ActivityLogEntry e) => ActivityEntry(
        label: e.label,
        meta: e.meta,
        highlighted: e.highlighted,
        type: e.type,
      );
}

/// Activity-log card matching mockup Screen 7 ("Activity · N events").
class ActivityLog extends StatelessWidget {
  final String headerLabel;
  final List<ActivityEntry> entries;
  const ActivityLog({
    super.key,
    required this.headerLabel,
    required this.entries,
  });

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tc.surface,
        border: Border.all(color: tc.divider, width: 1),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            headerLabel.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: tc.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          if (entries.isEmpty)
            Text(
              '—',
              style: TextStyle(
                fontSize: 13,
                color: tc.textTertiary,
              ),
            )
          else
            ...List.generate(entries.length, (i) {
              final e = entries[i];
              final isLast = i == entries.length - 1;
              return Padding(
                padding: EdgeInsets.fromLTRB(0, 0, 0, isLast ? 0 : 10),
                child: _EntryRow(entry: e),
              );
            }),
        ],
      ),
    );
  }
}

/// Maps an activity-log event type to an icon. Falls back to a neutral
/// circle for unknown / legacy computed entries (no `type` set).
IconData _iconForType(String? type) {
  switch (type) {
    case ActivityLogEntry.disputeCreated:
      return Icons.add_circle_outline;
    case ActivityLogEntry.l1TicketFiled:
    case ActivityLogEntry.l2TicketFiled:
      return Icons.receipt_outlined;
    case ActivityLogEntry.escalationEmailSent:
      return Icons.email_outlined;
    case ActivityLogEntry.templateUsed:
      return Icons.description_outlined;
    case ActivityLogEntry.resolved:
      return Icons.check_circle_outline;
    case ActivityLogEntry.statusChanged:
      return Icons.swap_horiz;
    case ActivityLogEntry.reminderFired:
      return Icons.notifications_outlined;
    case ActivityLogEntry.utrDetected:
      return Icons.sms_outlined;
    default:
      return Icons.circle_outlined;
  }
}

class _EntryRow extends StatelessWidget {
  final ActivityEntry entry;
  const _EntryRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    final iconColor =
        entry.highlighted ? AppColors.accent : tc.textTertiary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(
            _iconForType(entry.type),
            size: 16,
            color: iconColor,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: tc.textPrimary,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                entry.meta,
                style: TextStyle(
                  fontSize: 11,
                  color: tc.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
