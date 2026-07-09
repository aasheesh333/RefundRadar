import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:refund_radar/core/theme/app_tokens.dart';
import 'package:refund_radar/shared/widgets/onboarding_step_header.dart';

/// Onboarding SMS permission page (mockup Screen 12).
/// Explains on-device SMS parsing for failed-UPI auto-detection
/// and exposes the Android runtime SMS permission request.
class SmsPermissionPage extends StatelessWidget {
  const SmsPermissionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: SafeArea(
        child: Column(
          children: [
            // header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(
                children: [
                  Material(
                    color: AppColors.surfaceLight,
                    shape: const CircleBorder(
                      side: BorderSide(
                          color: AppColors.dividerLight, width: 1),
                    ),
                    child: Tooltip(
                      message: 'Back',
                      child: Semantics(
                        button: true,
                        label: 'Back',
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => context.go('/onboard'),
                          child: const SizedBox(
                            width: 48,
                            height: 48,
                            child: Center(
                              child: Icon(Icons.arrow_back,
                                  size: 22, color: AppColors.textPrimaryLight),
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
                    const Text(
                      'Detect failed UPI automatically',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppTypography.family,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                        color: AppColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Reads bank SMS on-device to auto-detect UTR, date, and amount. '
                      'No messages sent to servers.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: AppColors.textSecondaryLight,
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
    return Container(
      width: 72,
      height: 72,
      decoration: const BoxDecoration(
        color: AppColors.accentSoft,
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
    final steps = const [
      ('1', 'Receive any bank SMS (debit failed, refund processed)'),
      ('2', 'Local regex parser extracts UTR and amount on-device'),
      ('3', 'Pre-filled dispute card appears — tap to confirm'),
    ];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: AppShadows.card,
        border: Border.all(color: AppColors.dividerLight, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'HOW IT WORKS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              color: AppColors.textSecondaryLight,
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
                  decoration: const BoxDecoration(
                    color: AppColors.accentSoft,
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
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                      color: AppColors.textPrimaryLight,
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
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.premiumGoldSoft,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Padding(
            padding: EdgeInsets.only(top: 1),
            child: Text('⚠️',
                style: TextStyle(fontSize: 12, color: AppColors.premiumGold)),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Android allows only Financial SMS from approved bank sender IDs — no personal SMS read.',
              style: TextStyle(
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

class _SampleSmsCard extends StatelessWidget {
  const _SampleSmsCard();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceAltLight,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.dividerLight, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'Sample auto-detected event',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimaryLight,
                ),
              ),
              Text(
                'SMS detected',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(AppRadii.xs),
            ),
            child: RichText(
              text: const TextSpan(
                style: TextStyle(
                  fontSize: 11,
                  height: 1.45,
                  fontFamily: 'monospace',
                  color: AppColors.textSecondaryLight,
                ),
                children: [
                  TextSpan(text: 'From: '),
                  TextSpan(
                    text: 'HD-HDFCBK',
                    style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary),
                  ),
                  TextSpan(text: ' · 08 Jul 2026\nBody: ₹400 debited from A/c ✱✱✱✱1234 for UPI txn. UTR '),
                  TextSpan(
                    text: '412981901234',
                    style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary),
                  ),
                  TextSpan(text: '. If failed, complain within 5 days.'),
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
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      decoration: const BoxDecoration(
        color: AppColors.surfaceLight,
        border: Border(
          top: BorderSide(color: AppColors.dividerLight, width: 1),
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
                onPressed: () {
                  // TODO: request android.permission.RECEIVE_SMS / READ_SMS,
                  // then navigate. For now treat as granted and proceed.
                  context.go('/onboard/banks');
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
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
                  side: const BorderSide(color: AppColors.primary, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                  ),
                ),
                child: const Text(
                  'Maybe later',
                  style: TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            // 3-dot progress (2nd = filled/accent)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                SizedBox(
                  width: 8,
                  height: 8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.dividerLight,
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                SizedBox(
                  width: 24,
                  height: 8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                SizedBox(
                  width: 8,
                  height: 8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.dividerLight,
                      borderRadius: BorderRadius.all(Radius.circular(4)),
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
