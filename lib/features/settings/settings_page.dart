import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:refund_radar/core/providers/theme_provider.dart';
import 'package:refund_radar/services/notification_service.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionHeader('Language'),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('Language'),
            subtitle: Text(locale.languageCode == 'hi' ? 'हिन्दी' : 'English'),
            onTap: () => _showLanguageDialog(context, ref),
          ),
          const _SectionHeader('Appearance'),
          ListTile(
            leading: const Icon(Icons.dark_mode),
            title: const Text('Theme'),
            subtitle: Text(themeMode.name),
            onTap: () => _showThemeDialog(context, ref),
          ),
          const _SectionHeader('Notifications'),
          ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text('Notification permissions'),
            subtitle: const Text('Tap to grant'),
            onTap: () => ref.read(notificationServiceProvider).requestPermission(),
          ),
          const _SectionHeader('Subscription'),
          ListTile(
            leading: const Icon(Icons.card_membership),
            title: const Text('Manage subscription'),
            onTap: () => context.push('/paywall'),
          ),
          const _SectionHeader('Legal & Privacy'),
          ListTile(
            leading: const Icon(Icons.privacy_tip),
            title: const Text('Privacy policy'),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Disclaimers'),
            onTap: () => _showDisclaimerDialog(context),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Color(0xFFE5484D)),
            title: const Text('Delete my data',
                style: TextStyle(color: Color(0xFFE5484D))),
            subtitle: const Text('Removes all Firestore docs + cancels notifications'),
            onTap: () => _confirmDelete(context, ref),
          ),
        ],
      ),
    );
  }

  void _showLanguageDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Language'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(title: const Text('English'), onTap: () {
            ref.read(localeProvider.notifier).state = const Locale('en');
            Navigator.pop(c);
          }),
          ListTile(title: const Text('हिन्दी'), onTap: () {
            ref.read(localeProvider.notifier).state = const Locale('hi');
            Navigator.pop(c);
          }),
        ]),
      ),
    );
  }

  void _showThemeDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Theme'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(title: const Text('System'), onTap: () {
            ref.read(themeModeProvider.notifier).state = ThemeMode.system;
            Navigator.pop(c);
          }),
          ListTile(title: const Text('Light'), onTap: () {
            ref.read(themeModeProvider.notifier).state = ThemeMode.light;
            Navigator.pop(c);
          }),
          ListTile(title: const Text('Dark'), onTap: () {
            ref.read(themeModeProvider.notifier).state = ThemeMode.dark;
            Navigator.pop(c);
          }),
        ]),
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
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK')),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete all data?'),
        content: const Text('This cannot be undone. All disputes and reminders will be permanently removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              ref.read(notificationServiceProvider).cancelAll();
              Navigator.pop(c);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Data deleted. Firestore cleanup requires authentication.')),
              );
            },
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE5484D)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text(text,
            style: TextStyle(
              color: const Color(0xFF16C784),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            )),
      );
}
