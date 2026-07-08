import 'package:flutter/material.dart';
import '../../core/theme/app_tokens.dart';

/// InfoBanner — soft-bg r10 box with leading emoji + rich text.
/// `kind` controls background and emoji: success (✓ acc), warn (⚠ gold),
/// danger (⚠ err), info (✓ pri).
enum InfoKind { success, warn, danger, info }

class InfoBanner extends StatelessWidget {
  const InfoBanner({
    super.key,
    required this.kind,
    required this.message,
    this.padding,
  });

  final InfoKind kind;
  final InlineSpan message;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final fg = switch (kind) {
      InfoKind.success => AppColors.success,
      InfoKind.warn => AppColors.premiumGold,
      InfoKind.danger => AppColors.error,
      InfoKind.info => AppColors.success,
    };
    final bg = switch (kind) {
      InfoKind.success => AppColors.accentSoft,
      InfoKind.warn => AppColors.premiumGoldSoft,
      InfoKind.danger => AppColors.errorSoft,
      InfoKind.info => AppColors.accentSoft,
    };
    final prefix = switch (kind) {
      InfoKind.success => '✓',
      InfoKind.warn => '⚠',
      InfoKind.danger => '⚠',
      InfoKind.info => '✓',
    };
    return Container(
      padding: padding ?? const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Text(
              prefix,
              style: TextStyle(
                fontSize: 14,
                color: fg,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              message,
              style: const TextStyle(
                fontFamily: AppTypography.family,
                fontSize: 11,
                fontWeight: FontWeight.w500,
                height: 1.4,
                color: AppColors.textPrimaryLight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
