import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:refund_radar/core/router/app_routes.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:refund_radar/core/theme/app_tokens.dart';
import 'package:refund_radar/core/theme/app_theme_colors.dart';
import 'package:refund_radar/l10n/app_localizations.dart';

class SmsPermissionPage extends StatelessWidget {
  const SmsPermissionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tc = AppThemeColors.of(context);
    return Scaffold(
      backgroundColor: tc.bg,
      body: SafeArea(
        child: Column(
          children: [
            _PageHeader(tc: tc, l10n: l10n),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    Center(
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: tc.accentSoft,
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Text('📱', style: TextStyle(fontSize: 34)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      l10n?.smsPermissionTitle ??
                          'Use SMS import to fill disputes faster',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppTypography.family,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                        letterSpacing: -0.3,
                        color: tc.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        l10n?.smsPermissionSubtitle ??
                            'Android grants inbox access. RefundRadar scans messages on this phone to find likely refund-related bank or merchant SMS and prefill UTR, amount, and date.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: AppTypography.family,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          height: 1.5,
                          color: tc.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _HowItWorksCard(tc: tc, l10n: l10n),
                    const SizedBox(height: 16),
                    _PrivacyNote(tc: tc, l10n: l10n),
                    const SizedBox(height: 16),
                    _SampleSmsCard(tc: tc, l10n: l10n),
                  ],
                ),
              ),
            ),
            _SmsFooter(tc: tc, l10n: l10n),
          ],
        ),
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  final AppThemeColors tc;
  final AppLocalizations? l10n;
  const _PageHeader({required this.tc, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: tc.textPrimary),
            onPressed: () => context.go(AppRoutes.onboard),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n?.smsPermissionGrant ?? 'Allow SMS import',
                  style: TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: tc.textPrimary,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'Setup',
                  style: TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: tc.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HowItWorksCard extends StatelessWidget {
  final AppThemeColors tc;
  final AppLocalizations? l10n;
  const _HowItWorksCard({required this.tc, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final steps = [
      (
        '1',
        l10n?.smsPermissionHowItWorks1 ??
            'You approve Android SMS inbox access',
      ),
      (
        '2',
        l10n?.smsPermissionHowItWorks2 ??
            'RefundRadar filters likely bank/refund messages on-device',
      ),
      (
        '3',
        l10n?.smsPermissionHowItWorks3 ??
            'You choose a message to prefill the dispute form',
      ),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tc.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: tc.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n?.smsPermissionHowItWorks ?? 'HOW IT WORKS',
            style: TextStyle(
              fontFamily: AppTypography.family,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: tc.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          for (final (n, txt) in steps) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: tc.accentSoft,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      n,
                      style: TextStyle(
                        fontFamily: AppTypography.family,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    txt,
                    style: TextStyle(
                      fontFamily: AppTypography.family,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                      color: tc.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            if (n != '3') const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  final AppThemeColors tc;
  final AppLocalizations? l10n;
  const _PrivacyNote({required this.tc, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tc.alertSoft,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Text(
              '⚠',
              style: TextStyle(
                  fontSize: 14, color: AppColors.alert),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n?.smsPermissionPrivacyNote ??
                  'SMS parsing stays on-device for import. You can skip this and paste an SMS manually later.',
              style: TextStyle(
                fontFamily: AppTypography.family,
                fontSize: 12,
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
  final AppThemeColors tc;
  final AppLocalizations? l10n;
  const _SampleSmsCard({required this.tc, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final labelColor = tc.isDark ? AppColors.accent : AppColors.primary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tc.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: tc.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n?.smsPermissionSampleTitle ??
                    'Sample auto-detected event',
                style: TextStyle(
                  fontFamily: AppTypography.family,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: tc.textPrimary,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: tc.accentSoft,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                child: Text(
                  l10n?.smsPermissionSampleDetected ?? 'SMS detected',
                  style: TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: labelColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: tc.surface,
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  fontFamily: 'monospace',
                  color: tc.textSecondary,
                ),
                children: [
                  const TextSpan(text: 'From: '),
                  TextSpan(
                    text: 'HD-HDFCBK',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: labelColor,
                    ),
                  ),
                  TextSpan(
                    text: l10n?.smsPermissionSampleBody ??
                        ' · 08 Jul 2026\nBody: ₹400 debited from A/c ✱✱✱✱1234 for UPI txn. UTR ',
                  ),
                  TextSpan(
                    text: '412981901234',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: labelColor,
                    ),
                  ),
                  const TextSpan(text: '. If failed, complain within 5 days.'),
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
  final AppThemeColors tc;
  final AppLocalizations? l10n;
  const _SmsFooter({required this.tc, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: tc.surface,
        border: Border(top: BorderSide(color: tc.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: () async {
                  try {
                    final status = await Permission.sms.request();
                    if (!context.mounted) return;
                    if (status.isGranted || status.isLimited) {
                      context.go(AppRoutes.onboardBanks);
                      return;
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          l10n?.formSmsPermissionDeniedAction ??
                              'SMS permission denied. Tap Paste to use a copied SMS, or enter details manually.',
                        ),
                      ),
                    );
                    return;
                  } catch (_) {
                    // Plugin missing / desktop — continue onboarding.
                  }
                  if (context.mounted) context.go(AppRoutes.onboardBanks);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: tc.ctaBackground,
                  foregroundColor: tc.ctaForeground,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                ),
                child: Text(
                  l10n?.smsPermissionGrant ?? 'Allow SMS import',
                  style: TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () => context.go(AppRoutes.onboardBanks),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: tc.divider),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                ),
                child: Text(
                  l10n?.smsPermissionSkip ?? 'Skip and paste manually',
                  style: TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: tc.ctaBackground,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Not now',
              style: TextStyle(
                fontFamily: AppTypography.family,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: tc.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
