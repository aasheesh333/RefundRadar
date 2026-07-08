import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:refund_radar/core/providers/app_state_provider.dart';
import 'package:refund_radar/core/providers/auth_provider.dart';
import 'package:refund_radar/core/providers/theme_provider.dart';
import 'package:refund_radar/core/providers/dispute_provider.dart';
import 'package:refund_radar/services/fcm_topics.dart';
import 'package:refund_radar/services/onesignal_service.dart';

/// FCM topic re-evaluation effect (backlog B5).
///
/// Mount this [ConsumerWidget] once near the top of the tree (inside
/// `RefundRadarApp`). It renders nothing but keeps [ref.listen] alive for
/// the whole session: any change to disputes / premium / locale re-runs
/// `FcmTopicService.reevaluate()` against the 9 spec topics.
///
/// The re-evaluation is idempotent — subscribe is a no-op on existing
/// subscriptions, unsubscribe a no-op on absent ones — so calling it on
/// every input change is fine even when FCM isn't configured (dev/test
/// builds without real Firebase).
// TODO(B3): once RevenueCat lands, ensure `persistPremium` is called before
// the first reevaluation so premium=correct for the boot snapshot.
class FcmReevaluator extends ConsumerWidget {
  const FcmReevaluator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uidAsync = ref.watch(userIdProvider);
    final uid = uidAsync.valueOrNull;

    // Listen to premium + locale and re-run.
    ref.listen<bool>(isPremiumProvider, (_, _) => _reeval(ref, uid));
    ref.listen<Locale>(localeProvider, (_, _) => _reeval(ref, uid));

    // When uid transitions to non-null, run once and attach a listener.
    // Future changes to disputesProvider(uid) will trigger via ref.watch.
    if (uid != null) {
      ref.watch(disputesProvider(uid));
      ref.listen<AsyncValue<dynamic>>(
        disputesProvider(uid),
        (_, _) => _reeval(ref, uid),
      );
    }

    return const SizedBox.shrink(); // invisible, no UI
  }

  Future<void> _reeval(WidgetRef ref, String? uid) async {
    if (uid == null) return;
    final disputes = await ref.read(disputesProvider(uid).future);
    final stats = DisputeStats.fromList(disputes);
    final isPremium = ref.read(isPremiumProvider);
    final locale = ref.read(localeProvider);
    final inputs = await readFcmInputs(ref);
    final svc = ref.read(fcmTopicServiceProvider);
    await svc.reevaluate(
      installedHours: inputs.installedHours,
      activeDisputes: stats.activeDisputes,
      hasExpiredDispute: stats.hasExpiredDispute,
      isPremium: isPremium,
      hasFastag: stats.hasFastag,
      hasUpi: stats.hasUpi,
      languageCode: locale.languageCode,
    );
    // Mirror the same 9 segmentation dimensions into OneSignal user-tags
    // so the OneSignal dashboard can target the same audiences. OneSignal
    // stays dormant for push delivery (FCM is primary per spec); only its
    // tag store is kept in sync.
    final oneSignal = ref.read(oneSignalServiceProvider);
    await oneSignal.syncTags(
      installedHours: inputs.installedHours,
      activeDisputes: stats.activeDisputes,
      hasExpiredDispute: stats.hasExpiredDispute,
      isPremium: isPremium,
      hasFastag: stats.hasFastag,
      hasUpi: stats.hasUpi,
      languageCode: locale.languageCode,
    );
  }
}
