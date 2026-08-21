import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:refund_radar/core/providers/app_state_provider.dart';

/// AdMob banner unit ID.
///
/// Default = Google's *test* banner unit (safe for dev — clicks on a real
/// ad unit with test traffic get the account banned). For release builds
/// pass the real unit id at build time:
///   flutter build apk --dart-define=ADMOB_BANNER_ID=ca-app-pub-XXX/NNN
const String kAdMobBannerUnitId = String.fromEnvironment(
  'ADMOB_BANNER_ID',
  defaultValue: 'ca-app-pub-3940256099942544/6300978111',
);

/// Inline adaptive banner for free users.
///
/// Renders nothing (zero-height) while the ad is loading or if it fails,
/// and is completely omitted for premium users (ad-free is part of the
/// premium value prop; see paywall copy). Mounted at the bottom of the
/// Home screen via the Scaffold's bottomNavigationBar slot.
class AdBanner extends ConsumerStatefulWidget {
  const AdBanner({super.key});

  @override
  ConsumerState<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends ConsumerState<AdBanner> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ad != null) return;
    if (ref.read(isPremiumProvider)) return; // premium = ad-free
    _load();
  }

  Future<void> _load() async {
    final width =
        MediaQuery.of(context).size.width.truncate();
    final size = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
      width,
    );
    if (!mounted || size == null) return;
    final ad = BannerAd(
      adUnitId: kAdMobBannerUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('AdBanner failed to load: $error');
          ad.dispose();
        },
      ),
    );
    _ad = ad;
    ad.load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Double-gate on premium in case entitlement flips while mounted.
    if (ref.watch(isPremiumProvider)) return const SizedBox.shrink();
    final ad = _ad;
    if (!_loaded || ad == null) return const SizedBox.shrink();
    return SizedBox(
      width: ad.size.width.toDouble(),
      height: ad.size.height.toDouble(),
      child: AdWidget(ad: ad),
    );
  }
}
