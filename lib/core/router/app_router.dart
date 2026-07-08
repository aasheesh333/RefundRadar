import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:refund_radar/features/onboarding/onboarding_page.dart';
import 'package:refund_radar/features/home/home_page.dart';
import 'package:refund_radar/features/dispute_create/dispute_type_page.dart';
import 'package:refund_radar/features/dispute_create/dispute_form_page.dart';
import 'package:refund_radar/features/dispute_detail/dispute_detail_page.dart';
import 'package:refund_radar/features/wizard/wizard_page.dart';
import 'package:refund_radar/features/paywall/paywall_page.dart';
import 'package:refund_radar/features/reminders/reminders_page.dart';
import 'package:refund_radar/features/settings/settings_page.dart';
import 'package:refund_radar/features/ombudsman/ombudsman_letter_page.dart';
import 'package:refund_radar/features/templates/template_library_page.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/onboard',
    routes: [
      GoRoute(path: '/onboard', builder: (c, s) => const OnboardingPage()),
      GoRoute(path: '/home', builder: (c, s) => const HomePage()),
      GoRoute(
          path: '/disputes/create',
          builder: (c, s) => const DisputeTypePage()),
      GoRoute(
        path: '/disputes/form',
        builder: (c, s) =>
            DisputeFormPage(type: s.uri.queryParameters['type'] ?? 'upi_p2p'),
      ),
      GoRoute(
        path: '/disputes/:id',
        builder: (c, s) => DisputeDetailPage(id: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/wizard/:disputeId',
        builder: (c, s) =>
            WizardPage(disputeId: s.pathParameters['disputeId']!),
      ),
      GoRoute(
        path: '/ombudsman/:disputeId',
        builder: (c, s) =>
            OmbudsmanLetterPage(disputeId: s.pathParameters['disputeId']!),
      ),
      GoRoute(
        path: '/paywall',
        builder: (c, s) =>
            PaywallPage(returnPath: s.uri.queryParameters['return'] ?? '/home'),
      ),
      GoRoute(
          path: '/reminders', builder: (c, s) => const RemindersPage()),
      GoRoute(
          path: '/settings', builder: (c, s) => const SettingsPage()),
      GoRoute(
          path: '/templates',
          builder: (c, s) => const TemplateLibraryPage()),
    ],
  );
});
