import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:refund_radar/core/providers/dispute_provider.dart';
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
            // top header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n?.settingsTitle ?? 'Settings',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: tc.textPrimary,
                    ),
                  ),
                  Tooltip(
                    message: l10n?.commonClose ?? 'Close',
                    child: Semantics(
                      button: true,
                      label: l10n?.commonClose ?? 'Close',
                      child: InkWell(
                        onTap: () => Navigator.of(context).maybePop(),
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: tc.surface,
                            border: Border.all(
                              color: tc.divider,
                              width: 1,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close,
                            size: 18,
                            color: tc.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // profile row
            Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: tc.divider, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.primary, AppColors.primaryDark],
                      ),
                    ),
                    child: const Center(
                      child: Text(
                        'A',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n?.settingsRefundRadarUser ?? 'Refund Radar user',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: tc.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 1),
                        Text(
                          l10n?.settingsLocalProfile ?? 'Local profile',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: tc.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => context.push('/paywall?trigger=settings'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isPremium
                            ? tc.premiumGoldSoft
                            : tc.accentSoft,
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                      child: Text(
                        isPremium
                            ? (l10n?.settingsProBadge ?? '⭐ Pro')
                            : (l10n?.paywallTitle ?? 'Upgrade'),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isPremium
                              ? AppColors.premiumGold
                              : AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // body cards
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
                children: [
                  _Card(
                    label: l10n?.settingsSmsDetection ?? 'SMS detection',
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                l10n?.settingsAutoDetectUtr ?? 'Auto-detect UTR',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: tc.textPrimary,
                                ),
                              ),
                            ),
                            ToggleSwitch(
                              value: true,
                              onChanged: (_) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      l10n?.settingsSmsPermissionHint ??
                                          'SMS permission manages under Android settings.',
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: l10n?.settingsOnDeviceLabel ?? 'On-device. ',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                              TextSpan(
                                  text: l10n?.settingsNothingLeaves ??
                                      'Nothing leaves your phone.'),
                            ],
                          ),
                          style: TextStyle(
                            fontSize: 10,
                            color: tc.textSecondary,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _Card(
                    label: l10n?.settingsNotifications ?? 'Notifications',
                    child: _ToggleRows(
                      items: [
                        _ToggleItem(
                          label: l10n?.settingsDeadlineReminders ??
                              'Deadline reminders',
                          value: ref.watch(notifDeadlineProvider),
                          onChanged: (v) => setNotifDeadline(ref, v),
                        ),
                        _ToggleItem(
                          label: l10n?.settingsDailyComp ?? 'Daily comp clock',
                          value: ref.watch(notifDailyProvider),
                          onChanged: (v) => setNotifDaily(ref, v),
                        ),
                        _ToggleItem(
                          label: l10n?.settingsWeeklyDigest ?? 'Weekly digest',
                          value: ref.watch(notifWeeklyProvider),
                          onChanged: (v) => setNotifWeekly(ref, v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _Card(
                    label: l10n?.settingsLanguage ?? 'Language',
                    child: Column(
                      children: [
                        RadioRow(
                          label: l10n?.settingsEnglish ?? 'English',
                          selected: locale.languageCode != 'hi',
                          onTap: () =>
                              ref.read(localeProvider.notifier).state =
                                  const Locale('en'),
                        ),
                        const SizedBox(height: 6),
                        RadioRow(
                          label: l10n?.settingsHindi ?? 'हिन्दी',
                          selected: locale.languageCode == 'hi',
                          onTap: () => ref
                              .read(localeProvider.notifier).state =
                              const Locale('hi'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _Card(
                    label: l10n?.settingsAppearance ?? 'Appearance',
                    child: Column(
                      children: [
                        RadioRow(
                          label: l10n?.settingsLight ?? 'Light',
                          selected: themeMode == ThemeMode.light,
                          onTap: () => ref
                              .read(themeModeProvider.notifier).state =
                              ThemeMode.light,
                        ),
                        const SizedBox(height: 6),
                        RadioRow(
                          label: l10n?.settingsDark ?? 'Dark',
                          selected: themeMode == ThemeMode.dark,
                          onTap: () =>
                              ref.read(themeModeProvider.notifier).state =
                                  ThemeMode.dark,
                        ),
                        const SizedBox(height: 6),
                        RadioRow(
                          label: l10n?.settingsSystemDefault ?? 'System default',
                          selected: themeMode == ThemeMode.system,
                          onTap: () => ref
                              .read(themeModeProvider.notifier).state =
                              ThemeMode.system,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _Card(
                    label: l10n?.settingsAbout ?? 'About',
                    child: Column(
                      children: [
                        _RowPair(
                          left: l10n?.settingsVersion ?? 'Version',
                          right: '2.0 (build 389)',
                        ),
                        const SizedBox(height: 6),
                        _RowPair(
                          left: l10n?.settingsRbiSources ?? 'RBI sources',
                          right: '3 · Jul 2026',
                          rightColor: AppColors.accent,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: () => _showLegalDialog(context, ref),
                    child: _Card(
                      label: l10n?.settingsLegal ?? 'Legal',
                      child: Text(
                        l10n?.settingsLegalRow ??
                            'Disclaimer · Privacy · Delete data',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: tc.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // sign out / footer
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 9, 20, 9),
                decoration: BoxDecoration(
                  color: tc.surface,
                  border: Border(
                    top: BorderSide(
                      color: tc.divider,
                      width: 1,
                    ),
                  ),
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
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 48,
                      child: TextButton(
                        onPressed: () => _confirmSignOut(context, ref),
                        style: TextButton.styleFrom(
                          backgroundColor: tc.errorSoft,
                          foregroundColor: AppColors.error,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadii.md),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          minimumSize: const Size(0, 48),
                        ),
                        child: Text(
                          l10n?.settingsSignOut ?? 'Sign out',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
            child: Text(l10n?.settingsDeleteData ?? 'Delete my data'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final uid = ref.read(userIdProvider).asData?.value;
    if (uid == null || uid.isEmpty) {
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
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(kDeleteDataSuccessBody)),
      );
      context.go('/onboard');
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n?.commonError ?? 'Something went wrong'),
        ),
      );
    }
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
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
            child: Text(l10n?.settingsSignOut ?? 'Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    // Anonymous re-auth: signs out then mints a fresh uid — cloud data under
    // the previous uid becomes unreachable (warned above).
    await ref.read(reauthProvider)();
    ref.invalidate(userIdProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(kSignOutCompletedBody)),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: tc.surface,
        border: Border.all(color: tc.divider, width: 1),
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 6),
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                fontFamily: AppTypography.family,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
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

class _RowPair extends StatelessWidget {
  const _RowPair({
    required this.left,
    required this.right,
    this.rightColor,
  });
  final String left;
  final String right;
  final Color? rightColor;

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            left,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: tc.textSecondary,
            ),
          ),
        ),
        Text(
          right,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: rightColor ?? tc.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _ToggleItem {
  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;
  const _ToggleItem({
    required this.label,
    required this.value,
    required this.onChanged,
  });
}

class _ToggleRows extends StatelessWidget {
  const _ToggleRows({required this.items});
  final List<_ToggleItem> items;

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    return Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i != 0) const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  items[i].label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: items[i].value
                        ? tc.textPrimary
                        : tc.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ToggleSwitch(
                value: items[i].value,
                onChanged: items[i].onChanged,
              ),
            ],
          ),
        ],
      ],
    );
  }
}
