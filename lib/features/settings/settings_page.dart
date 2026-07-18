import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:refund_radar/core/router/app_routes.dart';
import 'package:refund_radar/core/utils/url_launcher_helper.dart';
import 'package:refund_radar/core/providers/dispute_provider.dart';
import 'package:refund_radar/core/providers/sms_detection_provider.dart';
import 'package:refund_radar/data/repositories/reminder_repository.dart';
import 'package:refund_radar/features/settings/settings_actions.dart';
import '../../core/providers/app_state_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/theme/app_theme_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/radio_row.dart';
import '../../shared/widgets/toggle_switch.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tc = AppThemeColors.of(context);
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    final isPremium = ref.watch(isPremiumProvider);
    return Scaffold(
      backgroundColor: tc.bg,
      body: SafeArea(
        child: Column(
          children: [
            _PageHeader(tc: tc, l10n: l10n),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  _UserCard(isPremium: isPremium, tc: tc, l10n: l10n),
                  const SizedBox(height: 16),
                  _SectionCard(
                    label: l10n?.settingsSmsDetection ?? 'SMS detection',
                    tc: tc,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n?.settingsAutoDetectUtr ??
                                        'Auto-detect UTR',
                                    style: TextStyle(
                                      fontFamily: AppTypography.family,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: tc.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    l10n?.settingsOnDeviceLabel ??
                                        'On-device. Nothing leaves your phone.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: tc.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ToggleSwitch(
                              value:
                                  ref.watch(smsDetectionEnabledProvider),
                              onChanged: (v) async {
                                if (v) {
                                  final status =
                                      await Permission.sms.request();
                                  if (!context.mounted) return;
                                  if (status.isGranted) {
                                    await setSmsDetectionEnabled(true);
                                    ref
                                        .read(smsDetectionEnabledProvider
                                            .notifier)
                                        .state = true;
                                  } else {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          l10n?.settingsSmsPermissionHint ??
                                              'SMS permission is managed under Android settings.',
                                        ),
                                      ),
                                    );
                                  }
                                } else {
                                  await setSmsDetectionEnabled(false);
                                  ref
                                      .read(smsDetectionEnabledProvider
                                          .notifier)
                                      .state = false;
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _SectionCard(
                    label: l10n?.settingsNotifications ?? 'Notifications',
                    tc: tc,
                    child: Column(
                      children: [
                        _ToggleRow(
                          label: l10n?.settingsDeadlineReminders ??
                              'Deadline reminders',
                          value: ref.watch(notifDeadlineProvider),
                          onChanged: (v) => setNotifDeadline(ref, v),
                          tc: tc,
                        ),
                        const SizedBox(height: 10),
                        _ToggleRow(
                          label: l10n?.settingsDailyComp ??
                              'Daily comp clock',
                          value: ref.watch(notifDailyProvider),
                          onChanged: (v) => setNotifDaily(ref, v),
                          tc: tc,
                        ),
                        const SizedBox(height: 10),
                        _ToggleRow(
                          label: l10n?.settingsWeeklyDigest ??
                              'Weekly digest',
                          value: ref.watch(notifWeeklyProvider),
                          onChanged: (v) => setNotifWeekly(ref, v),
                          tc: tc,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _SectionCard(
                    label: l10n?.settingsLanguage ?? 'Language',
                    tc: tc,
                    child: Column(
                      children: [
                        RadioRow(
                          label: l10n?.settingsEnglish ?? 'English',
                          selected: locale.languageCode != 'hi',
                          onTap: () {
                            ref.read(localeProvider.notifier).state =
                                const Locale('en');
                            persistLocaleCode('en');
                          },
                        ),
                        const SizedBox(height: 8),
                        RadioRow(
                          label: l10n?.settingsHindi ?? 'हिन्दी',
                          selected: locale.languageCode == 'hi',
                          onTap: () {
                            ref.read(localeProvider.notifier).state =
                                const Locale('hi');
                            persistLocaleCode('hi');
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _SectionCard(
                    label: l10n?.settingsAppearance ?? 'Appearance',
                    tc: tc,
                    child: Column(
                      children: [
                        RadioRow(
                          label: l10n?.settingsLight ?? 'Light',
                          selected: themeMode == ThemeMode.light,
                          onTap: () {
                            ref.read(themeModeProvider.notifier).state =
                                ThemeMode.light;
                            persistThemeMode(ThemeMode.light);
                          },
                        ),
                        const SizedBox(height: 8),
                        RadioRow(
                          label: l10n?.settingsDark ?? 'Dark',
                          selected: themeMode == ThemeMode.dark,
                          onTap: () {
                            ref.read(themeModeProvider.notifier).state =
                                ThemeMode.dark;
                            persistThemeMode(ThemeMode.dark);
                          },
                        ),
                        const SizedBox(height: 8),
                        RadioRow(
                          label:
                              l10n?.settingsSystemDefault ?? 'System default',
                          selected: themeMode == ThemeMode.system,
                          onTap: () {
                            ref.read(themeModeProvider.notifier).state =
                                ThemeMode.system;
                            persistThemeMode(ThemeMode.system);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _SectionCard(
                    label: l10n?.settingsAbout ?? 'About',
                    tc: tc,
                    child: Column(
                      children: [
                        _InfoRow(
                          left: l10n?.settingsVersion ?? 'Version',
                          right:
                              '${const String.fromEnvironment('VERSION_NAME', defaultValue: '1.0.0')} (${const String.fromEnvironment('VERSION_CODE', defaultValue: '1')})',
                          tc: tc,
                        ),
                        const SizedBox(height: 8),
                        _InfoRow(
                          left: l10n?.settingsRbiSources ?? 'RBI sources',
                          right: '3 · Jul 2026',
                          rightColor: AppColors.accent,
                          tc: tc,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: () => _showLegalDialog(context, ref),
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: tc.surface,
                        border: Border.all(color: tc.divider),
                        borderRadius: BorderRadius.circular(AppRadii.md),
                      ),
                      child: Row(
                        children: [
                          Text(
                            l10n?.settingsLegal ?? 'Legal',
                            style: TextStyle(
                              fontFamily: AppTypography.family,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: tc.textSecondary,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            l10n?.settingsLegalRow ??
                                'Disclaimer · Privacy · Delete data',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: tc.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.chevron_right,
                              size: 16, color: tc.textSecondary),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _SignOutFooter(
              tc: tc,
              l10n: l10n,
              onSignOut: () => _confirmSignOut(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  void _showLegalDialog(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l10n?.settingsLegal ?? 'Legal'),
        content: Text(
          l10n?.settingsLegalRow ??
              'Disclaimer · Privacy · Delete data',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(c);
              _showDisclaimerDialog(context);
            },
            child: Text(l10n?.settingsDisclaimerTitle ?? 'Disclaimer'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(c);
              await launchExternalUrl('https://refundradar.app/privacy');
            },
            child: Text(l10n?.settingsPrivacyTitle ?? 'Privacy Policy'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(c);
              _confirmDeleteData(context, ref);
            },
            child: Text(l10n?.settingsDeleteData ?? 'Delete my data'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text(l10n?.commonCancel ?? 'Cancel'),
          ),
        ],
      ),
    );
  }

  void _showDisclaimerDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l10n?.settingsDisclaimerTitle ?? 'Disclaimer'),
        content: SingleChildScrollView(
          child: Text(
            l10n?.disclaimerBody ??
                'Refund Radar is an independent informational tool. It is not affiliated with RBI, '
                'NPCI, NHAI, IHMCL, or any bank. We never ask for banking passwords, OTPs, or PINs. '
                'Complaints are filed by you on official portals. Compensation estimates are based on '
                'published RBI/NPCI rules and actual outcomes depend on your bank/regulator.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text(l10n?.commonOk ?? 'OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteData(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l10n?.settingsDeleteData ?? 'Delete my data'),
        content: Text(
          l10n?.settingsDeleteConfirm ??
              'Delete all your data? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(l10n?.commonCancel ?? 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(
              l10n?.settingsDeleteData ?? 'Delete my data',
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    String? uid = ref.read(userIdProvider).asData?.value;
    if (uid == null || uid.isEmpty) {
      try {
        uid = await ref
            .read(userIdProvider.future)
            .timeout(const Duration(seconds: 10));
      } catch (_) {
        uid = null;
      }
    }
    if (uid == null || uid.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n?.commonError ?? 'Something went wrong'),
        ),
      );
      return;
    }

    try {
      await executeDeleteAllUserData(
        uid: uid,
        deleteAllUserData: (id) =>
            ref.read(disputeRepositoryProvider).deleteAllUserData(id),
        deleteAllRemindersAndNotifications: (id) =>
            deleteAllRemindersAndNotifications(ref, id),
      );
      await ref.read(freeDisputesUsedProvider.notifier).reset();
      ref.invalidate(disputesProvider(uid));
      ref.invalidate(remindersProvider(uid));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(kDeleteDataSuccessBody)),
      );
      context.go(AppRoutes.home);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n?.commonError ?? 'Something went wrong'),
        ),
      );
    }
  }

  Future<void> _confirmSignOut(
      BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l10n?.settingsSignOut ?? 'Sign out'),
        content: const Text(kSignOutWarningBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(l10n?.commonCancel ?? 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(
              l10n?.settingsSignOut ?? 'Sign out',
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    await ref.read(reauthProvider)();
    ref.invalidate(userIdProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(kSignOutCompletedBody)),
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
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: tc.textPrimary),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Text(
              l10n?.settingsTitle ?? 'Settings',
              style: TextStyle(
                fontFamily: AppTypography.family,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: tc.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final bool isPremium;
  final AppThemeColors tc;
  final AppLocalizations? l10n;
  const _UserCard({
    required this.isPremium,
    required this.tc,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tc.surface,
        border: Border.all(color: tc.divider),
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: tc.ctaBackground.withValues(alpha: 0.12),
            ),
            alignment: Alignment.center,
            child: Text(
              'A',
              style: TextStyle(
                fontFamily: AppTypography.family,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: tc.ctaBackground,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n?.settingsRefundRadarUser ?? 'Refund Radar user',
                  style: TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: tc.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n?.settingsLocalProfile ?? 'Local profile',
                  style: TextStyle(
                    fontSize: 11,
                    color: tc.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () => context.push(AppRoutes.paywallWithParams(
              trigger: 'settings',
              returnPath: AppRoutes.settings,
            )),
            borderRadius: BorderRadius.circular(AppRadii.pill),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isPremium ? tc.premiumGoldSoft : tc.accentSoft,
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
              child: Text(
                isPremium
                    ? (l10n?.settingsProBadge ?? 'Pro')
                    : (l10n?.paywallTitle ?? 'Upgrade'),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isPremium ? AppColors.premiumGold : tc.ctaBackground,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String label;
  final Widget child;
  final AppThemeColors tc;
  const _SectionCard({
    required this.label,
    required this.child,
    required this.tc,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tc.surface,
        border: Border.all(color: tc.divider),
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                fontFamily: AppTypography.family,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
                color: tc.textSecondary,
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final AppThemeColors tc;
  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.tc,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppTypography.family,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: value ? tc.textPrimary : tc.textSecondary,
            ),
          ),
        ),
        ToggleSwitch(value: value, onChanged: onChanged),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String left;
  final String right;
  final Color? rightColor;
  final AppThemeColors tc;
  const _InfoRow({
    required this.left,
    required this.right,
    this.rightColor,
    required this.tc,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            left,
            style: TextStyle(
              fontFamily: AppTypography.family,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: tc.textSecondary,
            ),
          ),
        ),
        Text(
          right,
          style: TextStyle(
            fontFamily: AppTypography.family,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: rightColor ?? tc.textPrimary,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _SignOutFooter extends StatelessWidget {
  final AppThemeColors tc;
  final AppLocalizations? l10n;
  final VoidCallback onSignOut;
  const _SignOutFooter({
    required this.tc,
    required this.l10n,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: tc.surface,
        border: Border(top: BorderSide(color: tc.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n?.settingsNotAffiliated ??
                  'Not affiliated with RBI/NPCI/banks',
              style: TextStyle(
                fontSize: 10,
                color: tc.textTertiary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 40,
            child: OutlinedButton(
              onPressed: onSignOut,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error, width: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: Text(
                l10n?.settingsSignOut ?? 'Sign out',
                style: TextStyle(
                  fontFamily: AppTypography.family,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.error,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
