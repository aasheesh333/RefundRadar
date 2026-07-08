import 'package:flutter/material.dart';
import '../../core/theme/app_tokens.dart';

/// StatusPill — `.pi` mockup equiv. Fully rounded pill, 11px/600, with
/// optional emoji prefix. Default colours from [StatusKind]; override with
/// [fg]/[bg] for custom cases.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.fg,
    required this.bg,
    this.prefix,
  });

  /// Convenience builder using the existing `StatusKind` token pair.
  factory StatusPill.kind({
    Key? key,
    required String label,
    required StatusKind kind,
    String? prefix,
  }) =>
      StatusPill(
        key: key,
        label: label,
        prefix: prefix,
        fg: kind.fg,
        bg: kind.bg,
      );

  final String label;
  final String? prefix;
  final Color fg;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (prefix != null) ...[
            Text(prefix!, style: const TextStyle(fontSize: 11)),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontFamily: AppTypography.family,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
