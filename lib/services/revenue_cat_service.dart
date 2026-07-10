import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:refund_radar/core/providers/app_state_provider.dart';
import 'package:refund_radar/services/analytics_service.dart';

/// RevenueCat integration layer (backlog B3).
///
/// Responsibilities:
///   1. Configure the SDK once with a public SDK key (no secret — it's
///      safe to ship in the binary, only RevenueCat app-id is needed).
///   2. Fetch current [`Offering`]s for the paywall page.
///   3. Drive purchase / restore flows for a given package.
///   4. Mirror customer-info changes onto [`isPremiumProvider`] via
///      [`persistPremium`] so the rest of the app reads entitlement
///      synchronously.
///   5. Emit the spec analytics events (`paywall_view`, `purchase`).
///
/// **Resilience:** if `REVENUECAT_SDK_KEY` isn't passed (placeholder
/// builds, dev/test) we skip `Purchases.configureSDK` and every method
/// no-ops gracefully — offerings come back empty, purchase throws a
/// typed `RevenueCatNotConfigured` error, customer info reports
/// `isPremium = false`. The app stays usable.
///
/// **Anti-abuse:** `"purchases_flutter": ^8.0.0` is declared in pubspec
/// but was not initialiseable before B3; now it is. No private keys
/// ship in the binary — only the public SDK key, which is by design
/// public per RevenueCat docs.
class RevenueCatService {
  final Ref _ref;
  final String? _sdkKey;
  bool _configured = false;

  RevenueCatService(this._ref, this._sdkKey);

  /// Public SDK key passed via `--dart-define=REVENUECAT_SDK_KEY=...`.
  /// Can be safely shipped in the APK. Get it from RevenueCat dashboard
  /// → project "Refund Radar" (id `145b7bb9`) → API keys → SDK API keys.
  ///
  /// **Debug fallback:** when no `--dart-define` is supplied (local dev
  /// builds and the CI `debug` job) we use the RevenueCat **Test Store**
  /// public SDK key for the Refund Radar project. This lets developers
  /// exercise the full purchase flow against the sandbox store without
  /// any secret wiring. The Test Store key starts with `test_` and is
  /// safe to embed in the binary — it cannot make real charges.
  ///
  /// **Release:** the GitHub Actions `release` job overrides this with
  /// the live Play Store SDK key via `--dart-define=REVENUECAT_SDK_KEY`,
  /// which is stored as the `REVENUECAT_SDK_KEY` GitHub secret. Only the
  /// secret value changes when going live; this code stays untouched.
  static const _testStoreSdkKey = 'test_kLEeRaGzWFJaBEWdoztufhrpZCS';

  static String? get envSdkKey {
    const defined = String.fromEnvironment('REVENUECAT_SDK_KEY');
    if (defined.isNotEmpty) return defined;
    return _testStoreSdkKey;
  }

  /// True once `configure()` succeeded at least once this session.
  bool get isConfigured => _configured;

  /// Idempotent. Safe to call multiple times.
  Future<void> configure() async {
    if (_configured) return;
    final key = _sdkKey;
    if (key == null || key.isEmpty) {
      debugPrint('RevenueCat: skipping configure (no SDK key)');
      return;
    }
    try {
      await Purchases.configure(PurchasesConfiguration(key));
      // Listen to customer-info updates for live entitlement changes
      // (purchase success, refund, expired subscription).
      Purchases.addCustomerInfoUpdateListener(_onCustomerInfo);
      _configured = true;
      debugPrint('RevenueCat: configured');
    } catch (e, st) {
      debugPrint('RevenueCat: configure failed: $e\n$st');
    }
  }

  void _onCustomerInfo(CustomerInfo info) {
    final premium = info.entitlements.active.containsKey('Premium');
    // Side-effect: persist + propagate.
    persistPremium(_ref, premium);
    _ref.read(analyticsServiceProvider).setPremiumUserProperty(premium);
  }

  /// Current offerings for the paywall. Returns `null` if not configured
  /// or if RevenueCat returns no `current` offering.
  Future<Offerings?> fetchOfferings() async {
    if (!_configured) return null;
    try {
      return await Purchases.getOfferings();
    } catch (e) {
      debugPrint('RevenueCat: fetchOfferings failed: $e');
      return null;
    }
  }

  /// Initiate a purchase for the given package. Returns `true` on success.
  /// Mirrors premium flag + logs the spec `purchase` event.
  Future<bool> purchasePackage(Package pkg, {String source = 'paywall'}) async {
    if (!_configured) {
      throw const RevenueCatNotConfigured();
    }
    try {
      final info = await Purchases.purchasePackage(pkg);
      final premium = info.entitlements.active.containsKey('Premium');
      await persistPremium(_ref, premium);
      // Best-effort analytics — log price from package product if available.
      final product = pkg.storeProduct;
      await _ref.read(analyticsServiceProvider).logPurchase(
            planId: product.identifier,
            priceInr: product.price.toDouble(),
            source: source,
          );
      _ref
          .read(analyticsServiceProvider)
          .setPremiumUserProperty(premium);
      return premium;
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      debugPrint('RevenueCat: purchase error: $code ($e)');
      return false;
    }
  }

  /// Restore prior purchases. Returns `true` if premium is now active.
  Future<bool> restorePurchases() async {
    if (!_configured) return false;
    try {
      final info = await Purchases.restorePurchases();
      final premium = info.entitlements.active.containsKey('Premium');
      await persistPremium(_ref, premium);
      return premium;
    } catch (e) {
      debugPrint('RevenueCat: restore failed: $e');
      return false;
    }
  }

  /// Returns the current premium status from live customer info (not the
  /// cached provider value).
  Future<bool> fetchIsPremium() async {
    if (!_configured) return false;
    try {
      final info = await Purchases.getCustomerInfo();
      return info.entitlements.active.containsKey('Premium');
    } catch (_) {
      return false;
    }
  }

  /// Link RevenueCat's app-user-id to the Firebase anonymous uid via
  /// [Purchases.logIn], then refresh the local premium flag.
  ///
  /// Safe to call after every anonymous sign-in / re-auth. Never throws —
  /// failures (including [PurchasesErrorCode.operationAlreadyInProgressError])
  /// are swallowed so startup / auth never blocks on RC identity.
  Future<void> syncWithFirebaseUid(String uid) async {
    final trimmed = uid.trim();
    if (trimmed.isEmpty || !_configured) return;
    try {
      final result = await Purchases.logIn(trimmed);
      final premium =
          result.customerInfo.entitlements.active.containsKey('Premium');
      await persistPremium(_ref, premium);
      _ref.read(analyticsServiceProvider).setPremiumUserProperty(premium);
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (shouldSwallowLogInError(code)) {
        debugPrint('RevenueCat: logIn non-fatal: $code');
      }
    } catch (e) {
      debugPrint('RevenueCat: syncWithFirebaseUid failed: $e');
    }
  }
}

/// Whether a [Purchases.logIn] error is non-fatal and must not block auth.
///
/// [PurchasesErrorCode.operationAlreadyInProgressError] is always ignored;
/// other codes are also non-fatal for identity sync so startup never hangs.
bool shouldSwallowLogInError(PurchasesErrorCode code) {
  switch (code) {
    case PurchasesErrorCode.operationAlreadyInProgressError:
      return true;
    default:
      return true;
  }
}

/// Typed error for "RevenueCat hasn't been configured — call configure()
/// with a valid `REVENUECAT_SDK_KEY` first."
class RevenueCatNotConfigured implements Exception {
  const RevenueCatNotConfigured();
  @override
  String toString() =>
      'RevenueCatNotConfigured: SDK key missing — pass --dart-define=REVENUECAT_SDK_KEY=...';
}

final revenueCatServiceProvider = Provider<RevenueCatService>((ref) {
  return RevenueCatService(ref, RevenueCatService.envSdkKey);
});
