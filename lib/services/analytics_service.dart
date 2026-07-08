import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Thin wrapper around `FirebaseAnalytics` with a typed surface for the four
/// spec events (`dispute_created`, `wizard_completed`, `paywall_view`,
/// `purchase`) plus the `premium` user property. Resilient to missing
/// Firebase config (test/dev builds): exceptions are caught and logged.
///
/// All telemetry is event-name + parameter only — no PII, no UTR, no
/// dispute body, no bank account numbers. Spec §10 analytics policy.
class AnalyticsService {
  final FirebaseAnalytics _analytics;
  AnalyticsService(this._analytics);

  /// Dispute created, regardless of free/paid status.
  /// Params: `dispute_type` (enum value string), `is_premium` (bool).
  Future<void> logDisputeCreated({
    required String disputeType,
    required bool isPremium,
  }) =>
      _safe(
        () => _analytics.logEvent(
          name: 'dispute_created',
          parameters: {
            'dispute_type': disputeType,
            'is_premium': _asInt(isPremium),
          },
        ),
      );

  /// Wizard finished by an active dispute owner. Params:
  /// `outcome` (one of: `escalate`, `ombudsman`, `resolved`, `abandoned`),
  /// `days_open` (int), `was_won` (bool).
  Future<void> logWizardCompleted({
    required String outcome,
    required int daysOpen,
    required bool wasWon,
  }) =>
      _safe(
        () => _analytics.logEvent(
          name: 'wizard_completed',
          parameters: {
            'outcome': outcome,
            'days_open': daysOpen,
            'was_won': _asInt(wasWon),
          },
        ),
      );

  /// Paywall shown. Params:
  /// `trigger` (`free_second_dispute` | `ombudsman_letter` | `template_locked`),
  /// `plan_id` (nullable), `is_premium` (bool).
  Future<void> logPaywallView({
    required String trigger,
    String? planId,
    required bool isPremium,
  }) =>
      _safe(
        () => _analytics.logEvent(
          name: 'paywall_view',
          parameters: {
            'trigger': trigger,
            // ignore: use_null_aware_elements
            if (planId != null) 'plan_id': planId,
            'is_premium': _asInt(isPremium),
          },
        ),
      );

  /// Successful purchase / restore. Params:
  /// `plan_id`, `price` (double, INR), `source` (`paywall` | `restore`),
  /// `is_premium` (always true here; logged for parity).
  Future<void> logPurchase({
    required String planId,
    required double priceInr,
    required String source,
  }) =>
      _safe(
        () => _analytics.logEvent(
          name: 'purchase',
          parameters: {
            'plan_id': planId,
            'price': priceInr,
            'source': source,
            'is_premium': 1,
          },
        ),
      );

  /// User property: `premium` (true/false) — flips the audience lists.
  Future<void> setPremiumUserProperty(bool value) => _safe(
        () => _analytics.setUserProperty(
          name: 'premium',
          value: value ? 'true' : 'false',
        ),
      );

  /// App-open analytics event. Call from a top-level effect once on cold
  /// launch — exists separately because FirebaseAnalytics auto-logs it but
  /// only if consent + measurement enabled; we mirror it to be safe.
  Future<void> logAppOpen() =>
      _safe(() => _analytics.logEvent(name: 'app_open'));

  Future<void> _safe(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (kDebugMode) debugPrint('analytics: skipped ($e)');
    }
  }

  int _asInt(bool b) => b ? 1 : 0;
}

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return AnalyticsService(FirebaseAnalytics.instance);
});

/// Convenience: log the four canonical events from anywhere without
/// explicitly reading the provider. Import this file and call
/// `ref.read(analyticsServiceProvider).logDisputeCreated(...)`.
