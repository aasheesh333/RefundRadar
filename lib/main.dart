import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:refund_radar/core/router/app_router.dart';
import 'package:refund_radar/core/theme/app_theme.dart';
import 'package:refund_radar/core/providers/theme_provider.dart';
import 'package:refund_radar/l10n/app_localizations.dart';
import 'package:refund_radar/firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (_) {
    // Firebase placeholder config - real values set via GitHub secrets later
  }
  runApp(const ProviderScope(child: RefundRadarApp()));
}

class RefundRadarApp extends ConsumerWidget {
  const RefundRadarApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    return MaterialApp.router(
      title: 'Refund Radar',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      debugShowCheckedModeBanner: false,
    );
  }
}
