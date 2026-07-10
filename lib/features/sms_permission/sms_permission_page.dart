import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:refund_radar/core/theme/app_tokens.dart';
import 'package:refund_radar/core/theme/app_theme_colors.dart';
import 'package:refund_radar/shared/widgets/onboarding_step_header.dart';

/// Onboarding SMS permission page (mockup Screen 12).
/// Explains on-device SMS parsing for failed-UPI auto-detection
/// and exposes the Android runtime SMS permission request.
class SmsPermissionPage extends StatelessWidget {
  const SmsPermissionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    return Scaffold(
      backgroundColor: tc.bg,
      body: SafeArea(
        child: Column(
          children: [
            // header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(
                children: [
                  Material(
                    color: tc.surface,
                    shape: CircleBorder(
                      side: BorderSide(color: tc.divider, width: 1),
                    ),
                    child: Tooltip(
                      message: 'Back',
                      child: Semantics(
                        button: true,
                        label: 'Back',
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => context.go('/onboard'),
                          child: SizedBox(
                            width: 48,
                            height: 48,
                            child: Center(
                              child: Icon(Icons.arrow_back,
                                  size: 22, color: tc.textPrimary),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: OnboardingStepHeader(
                      step: 'Setup',
                      title: 'Grant SMS permission',
                    ),
                  ),
                ],
              ),
            ),
            // body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(
                      child: _HeroPhone(),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Detect failed UPI automatically',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppTypography.family,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                        color: tc.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Reads bank SMS on-device to auto-detect UTR, date, and amount. '
                      'No messages sent to servers.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: tc.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const _HowItWorksCard(),
                    const SizedBox(height: 12),
                    const _PrivacyNote(),
                    const SizedBox(height: 12),
                    const _SampleSmsCard(),
                  ],
                ),
              ),
            ),
            // sticky footer
            const _SmsFooter(),
          ],
        ),
      ),
    );
  }
}

class _HeroPhone extends StatelessWidget {
  const _HeroPhone();
  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: tc.accentSoft,
        shape: BoxShape.circle,
      ),
      child: const Center(
        child: Text('📱', style: TextStyle(fontSize: 34)),
      ),
    );
  }
}

class _HowItWorksCard extends StatelessWidget {
  const _HowItWorksCard();
  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    final steps = const [
      ('1', 'Receive any bank SMS (debit failed, refund processed)'),
      ('2', 'Local regex parser extracts UTR and amount on-device'),
      ('3', 'Pre-filled dispute card appears — tap to confirm'),
    ];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tc.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: AppShadows.card,
        border: Border.all(color: tc.divider, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'HOW IT WORKS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              color: tc.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          for (final (n, txt) in steps) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: tc.accentSoft,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      n,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    txt,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                      color: tc.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            if (n != '3') const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();
  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: tc.premiumGoldSoft,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Text('⚠️',
                style: TextStyle(fontSize: 12, color: AppColors.premiumGold)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Android allows only Financial SMS from approved bank sender IDs — no personal SMS read.',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                height: 1.4,
                color: tc.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SampleSmsCard extends StatelessWidget {
  const _SampleSmsCard();
  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    final labelColor = tc.isDark ? AppColors.accent : AppColors.primary;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: tc.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: tc.divider, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Sample auto-detected event',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: tc.textPrimary,
                ),
              ),
              Text(
                'SMS detected',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: labelColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: tc.surface,
              borderRadius: BorderRadius.circular(AppRadii.xs),
            ),
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 11,
                  height: 1.45,
                  fontFamily: 'monospace',
                  color: tc.textSecondary,
                ),
                children: [
                  const TextSpan(text: 'From: '),
                  TextSpan(
                    text: 'HD-HDFCBK',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, color: labelColor),
                  ),
                  const TextSpan(
                      text:
                          ' · 08 Jul 2026\nBody: ₹400 debited from A/c ✱✱✱✱1234 for UPI txn. UTR '),
                  TextSpan(
                    text: '412981901234',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, color: labelColor),
                  ),
                  const TextSpan(
                      text: '. If failed, complain within 5 days.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SmsFooter extends StatelessWidget {
  const _SmsFooter();
  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      decoration: BoxDecoration(
        color: tc.surface,
        border: Border(
          top: BorderSide(color: tc.divider, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Grant permission (primary)
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: () async {
                  // Runtime SMS permission (declared in AndroidManifest).
                  // On non-Android or denial we still continue — user can
                  // paste SMS later on the dispute form.
                  try {
                    final status = await Permission.sms.request();
                    if (!context.mounted) return;
                    if (status.isGranted || status.isLimited) {
                      context.go('/onboard/banks');
                      return;
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'SMS permission denied — you can still paste SMS later.',
                        ),
                      ),
                    );
                  } catch (_) {
                    // Plugin missing / desktop — continue onboarding.
                  }
                  if (context.mounted) context.go('/onboard/banks');
                },
                style: FilledButton.styleFrom(
                  backgroundColor: tc.ctaBackground,
                  foregroundColor: tc.ctaForeground,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                  ),
                ),
                child: const Text(
                  'Grant SMS permission',
                  style: TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Maybe later (outlined)
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                onPressed: () => context.go('/onboard/banks'),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: tc.isDark ? AppColors.accent : AppColors.primary,
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                  ),
                ),
                child: Text(
                  'Maybe later',
                  style: TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: tc.isDark ? AppColors.accent : AppColors.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            // 3-dot progress (2nd = filled/accent)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 8,
                  height: 8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: tc.divider,
                      borderRadius: const BorderRadius.all(Radius.circular(4)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 24,
                  height: 8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: const BorderRadius.all(Radius.circular(4)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 8,
                  height: 8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: tc.divider,
                      borderRadius: const BorderRadius.all(Radius.circular(4)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
