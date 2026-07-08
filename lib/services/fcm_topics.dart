import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:refund_radar/data/models/dispute.dart';

class FcmTopicService {
  final FirebaseMessaging _fcm;

  FcmTopicService(this._fcm);

  static const topics = [
    'dormant_no_dispute',
    'active_dispute',
    'deadline_missed',
    'free_limit_hit',
    'premium',
    'fastag_user',
    'upi_user',
    'lang_hi',
    'lang_en',
  ];

  Future<void> subscribe(String topic) async {
    try {
      await _fcm.subscribeToTopic(topic);
    } catch (_) {}
  }

  Future<void> unsubscribe(String topic) async {
    try {
      await _fcm.unsubscribeFromTopic(topic);
    } catch (_) {}
  }

  Future<void> reevaluate({
    required int installedHours,
    required int activeDisputes,
    required bool hasExpiredDispute,
    required bool isPremium,
    required bool hasFastag,
    required bool hasUpi,
    required String languageCode,
  }) async {
    final active = <String, bool>{
      'dormant_no_dispute': installedHours >= 48 && activeDisputes == 0,
      'active_dispute': activeDisputes >= 1,
      'deadline_missed': hasExpiredDispute,
      'free_limit_hit': !isPremium,
      'premium': isPremium,
      'fastag_user': hasFastag,
      'upi_user': hasUpi,
      'lang_hi': languageCode == 'hi',
      'lang_en': languageCode == 'en',
    };

    for (final entry in active.entries) {
      if (entry.value) {
        await subscribe(entry.key);
      } else {
        await unsubscribe(entry.key);
      }
    }
  }
}

final fcmTopicServiceProvider = Provider<FcmTopicService>((ref) {
  return FcmTopicService(FirebaseMessaging.instance);
});

class DisputeStats {
  final int activeDisputes;
  final bool hasExpiredDispute;
  final bool hasFastag;
  final bool hasUpi;
  const DisputeStats({
    required this.activeDisputes,
    required this.hasExpiredDispute,
    required this.hasFastag,
    required this.hasUpi,
  });

  static DisputeStats fromList(List<Dispute> disputes) {
    var active = 0;
    var expired = false;
    var fastag = false;
    var upi = false;
    for (final d in disputes) {
      if (d.status != DisputeStatus.resolved &&
          d.status != DisputeStatus.expired) active++;
      if (d.status == DisputeStatus.expired) expired = true;
      if (d.type == DisputeType.fastag) fastag = true;
      if (d.type == DisputeType.upiP2p ||
          d.type == DisputeType.upiP2m ||
          d.type == DisputeType.imps) upi = true;
    }
    return DisputeStats(
      activeDisputes: active,
      hasExpiredDispute: expired,
      hasFastag: fastag,
      hasUpi: upi,
    );
  }
}
