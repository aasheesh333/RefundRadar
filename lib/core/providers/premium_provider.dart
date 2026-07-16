import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Premium-state plumbing (spec §5.5, Task 8.3).
///
/// Two representations of the same thing:
///
///   * `premiumStatusProvider` — the *authoritative* status as an
///     [`AsyncValue<bool>`]. Starts in `AsyncValue.loading()` on a fresh
///     install, switches to `AsyncValue.data(persistedValue)` once
///     `hydratePersistedAppState` reads SharedPreferences, and is then
///     updated to `AsyncValue.data(true/false)` whenever RevenueCat pushes
///     a customer-info update (purchase, restore, entitlement expiry).
///     New premium-aware widgets should read this so they can distinguish
///     "still loading" from "definitely free".
///
///   * `isPremiumProvider` — backward-compatible *derived* `bool`. Returns
///     `premiumStatusProvider`'s `data` value, or `false` when in
///     `loading`/`error`. This preserves the previous fail-safe default
///     (`loading == not premium == free`) that every existing gate relies
///     on, so we don't have to touch 10+ consumer files just to surface a
///     loading spinner. Migrate callers to `premiumStatusProvider` when
///     you actually need granular loading UI; otherwise reading
///     `isPremiumProvider` keeps working as before.
///
/// **Fail-safe:** while `premiumStatusProvider` is in `loading`, every gate
/// that reads `isPremiumProvider` treats the user as *free* — i.e. they see
/// paywalls instead of silently unlocked premium features. That's the
/// behaviour required by spec §5.5: "Paywall gates treat an unhydrated state
/// as 'not premium' (fail-safe). This prevents a brief flash of premium gates
/// for a lapsed user while RevenueCat configures."
final premiumStatusProvider =
    StateProvider<AsyncValue<bool>>((ref) => const AsyncValue.loading());

/// Derived boolean premium flag — `true` only when `premiumStatusProvider`
/// has resolved to `AsyncValue.data(true)`. Loading and error both yield
/// `false` (free). Read this from gates/UI that need a plain `bool`.
final isPremiumProvider = Provider<bool>(
  (ref) => ref.watch(premiumStatusProvider).valueOrNull ?? false,
);

/// Set the current premium status from RevenueCat customer-info updates.
///
/// Called from [`RevenueCatService._onCustomerInfo`] (and purchase/restore
/// success paths) — through [`persistPremium`] in `app_state_provider.dart`
/// — with the freshly resolved entitlement. This is the only place the app
/// should *write* to `premiumStatusProvider`; persisted through
/// `persistPremium` (which still writes the SharedPreferences entry used by
/// the next launch's hydrate path).
///
/// Accepts `dynamic` (not `Ref`) because callers pass a `ProviderContainer`
/// from `main.dart`'s startup sequence — `ProviderContainer` has a `read()`
/// method but does NOT implement `Ref` in Riverpod 2.x.
void setPremiumStatus(dynamic ref, bool premium) {
  ref.read(premiumStatusProvider.notifier).state = AsyncValue.data(premium);
}
