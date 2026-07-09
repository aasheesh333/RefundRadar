import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/theme/app_tokens.dart';
import '../../services/notification_service.dart';
import '../../shared/widgets/radio_row.dart';
import '../../shared/widgets/toggle_switch.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: SafeArea(
        child: Column(
          children: [
            // top header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Settings',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimaryLight,
                    ),
                  ),
                  InkWell(
                    onTap: () => Navigator.of(context).maybePop(),
                    borderRadius: BorderRadius.circular(17),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        border: Border.all(
                          color: AppColors.dividerLight,
                          width: 1,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 15,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // profile row
            Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
              decoration: const BoxDecoration(
                border: Border(
                  bottom:
                      BorderSide(color: AppColors.dividerLight, width: 1),
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
                      children: const [
                        Text(
                          'Refund Radar user',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimaryLight,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 1),
                        Text(
                          'Local profile',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondaryLight,
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
                        color: AppColors.premiumGoldSoft,
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                      child: const Text(
                        '⭐ Pro',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.premiumGold,
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
                    label: 'SMS detection',
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Auto-detect UTR',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimaryLight,
                                ),
                              ),
                            ),
                            ToggleSwitch(
                              value: true,
                              onChanged: (_) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'SMS permission manages under Android settings.',
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: 'On-device. ',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                              TextSpan(text: 'Nothing leaves your phone.'),
                            ],
                          ),
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondaryLight,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _Card(
                    label: 'Notifications',
                    child: _ToggleRows(
                      items: [
                        _ToggleItem(
                          label: 'Deadline reminders',
                          value: true,
                          onChanged: (_) => ref
                              .read(notificationServiceProvider)
                              .requestPermission(),
                        ),
                        _ToggleItem(
                          label: 'Daily comp clock',
                          value: true,
                          onChanged: (_) {},
                        ),
                        _ToggleItem(
                          label: 'Weekly digest',
                          value: false,
                          onChanged: (_) {},
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _Card(
                    label: 'Language',
                    child: Column(
                      children: [
                        RadioRow(
                          label: 'English',
                          selected: locale.languageCode != 'hi',
                          onTap: () =>
                              ref.read(localeProvider.notifier).state =
                                  const Locale('en'),
                        ),
                        const SizedBox(height: 6),
                        RadioRow(
                          label: 'हिन्दी',
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
                    label: 'Appearance',
                    child: Column(
                      children: [
                        RadioRow(
                          label: 'Light',
                          selected: themeMode == ThemeMode.light,
                          onTap: () => ref
                              .read(themeModeProvider.notifier).state =
                              ThemeMode.light,
                        ),
                        const SizedBox(height: 6),
                        RadioRow(
                          label: 'Dark',
                          selected: themeMode == ThemeMode.dark,
                          onTap: () =>
                              ref.read(themeModeProvider.notifier).state =
                                  ThemeMode.dark,
                        ),
                        const SizedBox(height: 6),
                        RadioRow(
                          label: 'System default',
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
                    label: 'About',
                    child: Column(
                      children: const [
                        _RowPair(
                          left: 'Version',
                          right: '2.0 (build 389)',
                        ),
                        SizedBox(height: 6),
                        _RowPair(
                          left: 'RBI sources',
                          right: '3 · Jul 2026',
                          rightColor: AppColors.accent,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: () => _showDisclaimerDialog(context),
                    child: const _Card(
                      label: 'Legal',
                      child: Text(
                        'Disclaimer · Privacy · Delete data',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimaryLight,
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
                decoration: const BoxDecoration(
                  color: AppColors.surfaceLight,
                  border: Border(
                    top: BorderSide(
                      color: AppColors.dividerLight,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Not affiliated with RBI/NPCI/banks',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textTertiaryLight,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 30,
                      child: TextButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Sign out not implemented.'),
                            ),
                          );
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: AppColors.errorSoft,
                          foregroundColor: AppColors.error,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadii.md),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                        ),
                        child: const Text(
                          'Sign out',
                          style: TextStyle(
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

  void _showDisclaimerDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Disclaimer'),
        content: const SingleChildScrollView(
          child: Text(
            'Refund Radar is an independent informational tool. It is not affiliated with RBI, '
            'NPCI, NHAI, IHMCL, or any bank. We never ask for banking passwords, OTPs, or PINs. '
            'Complaints are filed by you on official portals. Compensation estimates are based on '
            'published RBI/NPCI rules and actual outcomes depend on your bank/regulator.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        border: Border.all(color: AppColors.dividerLight, width: 1),
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 6),
            child: Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontFamily: AppTypography.family,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: AppColors.textSecondaryLight,
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
    this.rightColor = AppColors.textPrimaryLight,
  });
  final String left;
  final String right;
  final Color rightColor;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Text(
              left,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondaryLight,
              ),
            ),
          ),
          Text(
            right,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: rightColor,
            ),
          ),
        ],
      );
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
  Widget build(BuildContext context) => Column(
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
                          ? AppColors.textPrimaryLight
                          : AppColors.textSecondaryLight,
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
