import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:refund_radar/core/theme/app_theme_colors.dart';
import 'package:refund_radar/core/theme/app_tokens.dart';
import 'package:refund_radar/data/models/dispute.dart';
import 'package:refund_radar/l10n/app_localizations.dart';
import 'package:refund_radar/shared/widgets/status_pill.dart';

/// F4 — success dialog shown after the escalation email is sent.
/// Premium users get a direct "Open Ombudsman letter →" CTA; free users see
/// the L3 notice behind a Pro badge with a paywall CTA.
class EscalatePostSendDialog {
  /// Shows the post-escalation "What's next?" dialog.
  static void show(
    BuildContext context,
    Dispute dispute,
    bool isPremiumUser,
  ) {
    final tc = AppThemeColors.of(context);
    final l10n = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: tc.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: AppColors.accent, size: 28),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Escalation sent!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: tc.textPrimary,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "What's next?",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: tc.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "If the bank doesn't resolve within 30 days, escalate to the Banking Ombudsman.",
              style: TextStyle(fontSize: 13, color: tc.textSecondary),
            ),
            const SizedBox(height: 12),
            // Level 3 preview card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: tc.accentSoft,
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              child: Row(
                children: [
                  const Icon(Icons.gavel, size: 20, color: AppColors.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Level 3: Ombudsman notice',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: tc.textPrimary,
                      ),
                    ),
                  ),
                  if (!isPremiumUser)
                    StatusPill(
                      label: l10n?.templateProBadge ?? 'Pro',
                      fg: AppColors.premiumGold,
                      bg: tc.premiumGoldSoft,
                      prefix: '🔒',
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text(
              'Later',
              style: TextStyle(color: tc.textSecondary),
            ),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(c);
              if (isPremiumUser) {
                context.push('/ombudsman/${dispute.id}');
              } else {
                context.push(
                  '/paywall?return=/home&trigger=post_escalation',
                );
              }
            },
            child: Text(
              isPremiumUser
                  ? 'Open Ombudsman letter →'
                  : 'Unlock Ombudsman templates →',
            ),
          ),
        ],
      ),
    );
  }
}
