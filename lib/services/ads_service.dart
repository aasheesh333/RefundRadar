import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// AdMob (google_mobile_ads 9.x) coordinator for free-tier monetisation.
///
/// Surfaces:
/// - Interstitial — shown only at natural breaks (wizard completion, report
///   generated), throttled by a persisted minimum-gap timer so users are
///   never spammed back-to-back.
/// - Rewarded — user-initiated unlocks of premium-ish one-off features; the
///   feature is gated strictly on [showRewarded] returning `true` (reward
///   actually earned), never on ad load/show alone.
///
/// Policy notes:
/// - Ads are only presented at natural transitions; never on screen load,
///   never overlapping primary CTAs, and never with layouts that invite
///   accidental clicks (AdMob invalid-traffic policy).
/// - All failures are silent (logged via [debugPrint] in debug builds); the
///   app must degrade gracefully when ads are unavailable (no fill, offline,
///   test device).
/// - Ad unit IDs are injected via `--dart-define` and fall back to the
///   official Google test IDs, so dev builds can never serve real ads.
class AdsService {
  static const String interstitialAdUnitId = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_ID',
    defaultValue: 'ca-app-pub-3940256099942544/1033173712',
  );
  static const String rewardedAdUnitId = String.fromEnvironment(
    'ADMOB_REWARDED_ID',
    defaultValue: 'ca-app-pub-3940256099942544/5224354917',
  );

  static const String _lastInterstitialKey = 'ads_last_interstitial';

  InterstitialAd? _interstitial;
  bool _interstitialLoading = false;

  RewardedAd? _rewarded;
  bool _rewardedLoading = false;

  /// Background warm-up of both formats. Safe to call multiple times —
  /// in-flight requests and already-loaded ads prevent duplicates.
  void preload() {
    unawaited(_preloadInterstitial());
    unawaited(_preloadRewarded());
  }

  /// Shows an interstitial if one is loaded AND at least [minGap] has passed
  /// since the last interstitial was shown. Returns `true` only when shown.
  ///
  /// Always triggers a preload for the next slot on dismiss/failure. All
  /// errors are swallowed silently (returns `false`).
  Future<bool> showInterstitial({
    Duration minGap = const Duration(minutes: 3),
  }) async {
    try {
      if (!await _interstitialCooldownElapsed(minGap)) return false;
      final ad = _interstitial;
      if (ad == null) {
        unawaited(_preloadInterstitial());
        return false;
      }
      _interstitial = null;

      final shown = Completer<bool>();
      ad.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          unawaited(_markInterstitialShown());
          unawaited(_preloadInterstitial());
          if (!shown.isCompleted) shown.complete(true);
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          debugPrint('AdsService: interstitial failed to show: $error');
          ad.dispose();
          unawaited(_preloadInterstitial());
          if (!shown.isCompleted) shown.complete(false);
        },
      );
      await ad.show();
      return await shown.future;
    } catch (e) {
      debugPrint('AdsService: showInterstitial error: $e');
      return false;
    }
  }

  /// Loads a rewarded ad (8s cap) and shows it. Returns `true` ONLY if
  /// `onUserEarnedReward` fired — i.e. the user watched to completion.
  /// Any load/show failure or early dismissal returns `false`.
  Future<bool> showRewarded() async {
    try {
      var ad = _rewarded;
      _rewarded = null;
      ad ??= await _loadRewarded()
          .timeout(const Duration(seconds: 8), onTimeout: () => null);
      if (ad == null) {
        unawaited(_preloadRewarded());
        return false;
      }

      var earned = false;
      final done = Completer<bool>();
      ad.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          unawaited(_preloadRewarded());
          if (!done.isCompleted) done.complete(earned);
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          debugPrint('AdsService: rewarded failed to show: $error');
          ad.dispose();
          unawaited(_preloadRewarded());
          if (!done.isCompleted) done.complete(false);
        },
      );
      await ad.show(
        onUserEarnedReward: (ad, reward) {
          earned = true;
        },
      );
      return await done.future;
    } catch (e) {
      debugPrint('AdsService: showRewarded error: $e');
      return false;
    }
  }

  Future<void> _preloadInterstitial() async {
    if (_interstitial != null || _interstitialLoading) return;
    _interstitialLoading = true;
    final completer = Completer<InterstitialAd?>();
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: completer.complete,
        onAdFailedToLoad: (error) {
          debugPrint('AdsService: interstitial failed to load: $error');
          completer.complete(null);
        },
      ),
    );
    _interstitial = await completer.future;
    _interstitialLoading = false;
  }

  Future<void> _preloadRewarded() async {
    if (_rewarded != null || _rewardedLoading) return;
    _rewardedLoading = true;
    _rewarded = await _loadRewarded();
    _rewardedLoading = false;
  }

  Future<RewardedAd?> _loadRewarded() {
    final completer = Completer<RewardedAd?>();
    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: completer.complete,
        onAdFailedToLoad: (error) {
          debugPrint('AdsService: rewarded failed to load: $error');
          completer.complete(null);
        },
      ),
    );
    return completer.future;
  }

  Future<bool> _interstitialCooldownElapsed(Duration minGap) async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt(_lastInterstitialKey);
    if (last == null) return true;
    return DateTime.now().millisecondsSinceEpoch - last >=
        minGap.inMilliseconds;
  }

  Future<void> _markInterstitialShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _lastInterstitialKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Disposes any cached (not-yet-shown) ads.
  void dispose() {
    _interstitial?.dispose();
    _interstitial = null;
    _rewarded?.dispose();
    _rewarded = null;
  }
}

/// App-wide singleton; ads are app-level state and survive tab switches.
final adsServiceProvider = Provider<AdsService>((ref) => AdsService());
