import 'package:flutter/material.dart';
import '../../core/theme/app_theme_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/status_kind_theme.dart';

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

  /// Convenience builder using brightness-aware [StatusKind] softs.
  factory StatusPill.kind({
    Key? key,
    required BuildContext context,
    required String label,
    required StatusKind kind,
    String? prefix,
  }) {
    final tc = AppThemeColors.of(context);
    return StatusPill(
      key: key,
      label: label,
      prefix: prefix,
      fg: kind.fgFor(tc),
      bg: kind.bgFor(tc),
    );
  }

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
