import 'package:flutter/material.dart';
import '../../core/theme/app_tokens.dart';

/// A single activity-log entry — matches mockup Screen 7.
class ActivityEntry {
  final String label;
  final String meta;
  final bool highlighted;
  const ActivityEntry({
    required this.label,
    required this.meta,
    this.highlighted = false,
  });
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        border: Border.all(color: AppColors.dividerLight, width: 1),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            headerLabel.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 10),
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

class _EntryRow extends StatelessWidget {
  final ActivityEntry entry;
  const _EntryRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final dotColor =
        entry.highlighted ? AppColors.accent : AppColors.textTertiaryLight;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(top: 6),
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                entry.meta,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
