import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:refund_radar/core/providers/app_state_provider.dart';
import 'package:refund_radar/features/onboarding/onboarding_page.dart';
import 'package:refund_radar/features/sms_permission/sms_permission_page.dart';
import 'package:refund_radar/features/add_banks/add_banks_page.dart';
import 'package:refund_radar/features/home/home_page.dart';
import 'package:refund_radar/features/dispute_create/dispute_type_page.dart';
import 'package:refund_radar/features/dispute_create/dispute_form_page.dart';
import 'package:refund_radar/features/dispute_detail/dispute_detail_page.dart';
import 'package:refund_radar/features/wizard/wizard_page.dart';
import 'package:refund_radar/features/paywall/paywall_page.dart';
import 'package:refund_radar/features/reminders/reminders_page.dart';
import 'package:refund_radar/features/settings/settings_page.dart';
import 'package:refund_radar/features/ombudsman/ombudsman_letter_page.dart';
import 'package:refund_radar/features/escalate/escalate_page.dart';
import 'package:refund_radar/features/history/history_page.dart';
import 'package:refund_radar/features/shell/home_shell.dart';
import 'package:refund_radar/features/templates/template_library_page.dart';
import 'package:refund_radar/features/templates/template_picker_page.dart';
import 'package:refund_radar/features/templates/template_preview_page.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final goRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/onboard',
    redirect: (context, state) {
      final onboarded = ref.read(hasSeenOnboardingProvider);
      final goingToOnboard = state.matchedLocation == '/onboard' ||
          state.matchedLocation.startsWith('/onboard/');
      // Not onboarded → force onboarding flow (handles deep-links before
      // onboarding is complete).
      if (!onboarded && !goingToOnboard) {
        return '/onboard';
      }
      // Already onboarded → skip onboarding slides on cold boot.
      if (onboarded && goingToOnboard) {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/onboard', builder: (c, s) => const OnboardingPage()),
      // Persistent bottom-nav shell hosting the four primary destinations.
      // Each branch keeps its own navigator stack + scroll position.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            HomeShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/home', builder: (c, s) => const HomePage()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                  path: '/history', builder: (c, s) => const HistoryPage()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                  path: '/templates',
                  builder: (c, s) => const TemplateLibraryPage()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                  path: '/settings',
                  builder: (c, s) => const SettingsPage()),
            ],
          ),
        ],
      ),
      GoRoute(
          path: '/disputes/create',
          builder: (c, s) => const DisputeTypePage()),
      GoRoute(
        path: '/disputes/form',
        builder: (c, s) => DisputeFormPage(
          type: s.uri.queryParameters['type'] ?? 'upi_p2p',
          prefilledUtr: s.uri.queryParameters['utr'],
          prefilledAmount:
              double.tryParse(s.uri.queryParameters['amount'] ?? ''),
          prefilledSender: s.uri.queryParameters['sender'],
        ),
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
        path: '/escalate/:id',
        builder: (c, s) => EscalatePage(disputeId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/paywall',
        builder: (c, s) => PaywallPage(
          returnPath: s.uri.queryParameters['return'] ?? '/home',
          trigger: s.uri.queryParameters['trigger'] ?? 'generic',
          templateId: s.uri.queryParameters['templateId'],
          templateTitle: s.uri.queryParameters['templateTitle'],
        ),
      ),
      GoRoute(
          path: '/reminders', builder: (c, s) => const RemindersPage()),
      // Wave 4a — full-screen Template Picker + Preview used by
      // DisputeDetail (and reusable from Escalate) for "change template".
      GoRoute(
        path: '/templates/picker',
        builder: (c, s) => TemplatePickerPage(
          disputeId: s.uri.queryParameters['disputeId'] ?? '',
        ),
      ),
      GoRoute(
        path: '/templates/preview',
        builder: (c, s) => TemplatePreviewPage(
          disputeId: s.uri.queryParameters['disputeId'] ?? '',
          templateId: s.uri.queryParameters['templateId'] ?? '',
        ),
      ),
      GoRoute(
          path: '/onboard/sms',
          builder: (c, s) => const SmsPermissionPage()),
      GoRoute(
          path: '/onboard/banks',
          builder: (c, s) => const AddBanksPage()),
    ],
  );
});
