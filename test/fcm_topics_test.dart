import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:refund_radar/services/fcm_topics.dart';
import 'package:refund_radar/data/models/dispute.dart';

class _FakeFcm extends Mock implements FirebaseMessaging {}
void main() {
  late _FakeFcm fcm;
  late FcmTopicService svc;
  late List<String> subscribed;
  late List<String> unsubscribed;

  setUp(() {
    fcm = _FakeFcm();
    subscribed = [];
    unsubscribed = [];
    when(() => fcm.subscribeToTopic(any())).thenAnswer((inv) async {
      subscribed.add(inv.positionalArguments[0] as String);
    });
    when(() => fcm.unsubscribeFromTopic(any())).thenAnswer((inv) async {
      unsubscribed.add(inv.positionalArguments[0] as String);
    });
    svc = FcmTopicService(fcm);
  });

  group('FcmTopicService.reevaluate — topic gating', () {
    test('brand-new free user (freeDisputesUsed=0) NOT subscribed to free_limit_hit',
        () async {
      await svc.reevaluate(
        installedHours: 1,
        activeDisputes: 0,
        hasExpiredDispute: false,
        isPremium: false,
        hasFastag: false,
        hasUpi: false,
        languageCode: 'en',
        freeDisputesUsed: 0,
      );
      expect(subscribed, isNot(contains('free_limit_hit')));
      expect(unsubscribed, contains('free_limit_hit'));
    });

    test('free user with 1+ used dispute subscribes to free_limit_hit',
        () async {
      await svc.reevaluate(
        installedHours: 1,
        activeDisputes: 0,
        hasExpiredDispute: false,
        isPremium: false,
        hasFastag: false,
        hasUpi: false,
        languageCode: 'en',
        freeDisputesUsed: 1,
      );
      expect(subscribed, contains('free_limit_hit'));
    });

    test('premium user never subscribed to free_limit_hit (regardless of use)',
        () async {
      await svc.reevaluate(
        installedHours: 1,
        activeDisputes: 0,
        hasExpiredDispute: false,
        isPremium: true,
        hasFastag: false,
        hasUpi: false,
        languageCode: 'en',
        freeDisputesUsed: 5,
      );
      expect(subscribed, isNot(contains('free_limit_hit')));
      expect(subscribed, contains('premium'));
    });
  });

  group('FcmTopicService.reevaluate — dormant vs active', () {
    test('installed >= 48h with 0 disputes → dormant segment', () async {
      await svc.reevaluate(
        installedHours: 50,
        activeDisputes: 0,
        hasExpiredDispute: false,
        isPremium: false,
        hasFastag: false,
        hasUpi: false,
        languageCode: 'en',
      );
      expect(subscribed, contains('dormant_no_dispute'));
      expect(subscribed, isNot(contains('active_dispute')));
    });

    test('installed 24h with 0 disputes → no dormant yet (boundary)', () async {
      await svc.reevaluate(
        installedHours: 24,
        activeDisputes: 0,
        hasExpiredDispute: false,
        isPremium: false,
        hasFastag: false,
        hasUpi: false,
        languageCode: 'en',
      );
      expect(subscribed, isNot(contains('dormant_no_dispute')));
    });

    test('>=1 active dispute → active_dispute subscribed', () async {
      await svc.reevaluate(
        installedHours: 100,
        activeDisputes: 2,
        hasExpiredDispute: false,
        isPremium: false,
        hasFastag: false,
        hasUpi: false,
        languageCode: 'en',
      );
      expect(subscribed, contains('active_dispute'));
      expect(subscribed, isNot(contains('dormant_no_dispute')));
    });
  });

  group('FcmTopicService.reevaluate — language + dispute type', () {
    test('lang_hi subscribed if languageCode == hi', () async {
      await svc.reevaluate(
        installedHours: 1,
        activeDisputes: 0,
        hasExpiredDispute: false,
        isPremium: false,
        hasFastag: false,
        hasUpi: false,
        languageCode: 'hi',
      );
      expect(subscribed, contains('lang_hi'));
      expect(subscribed, isNot(contains('lang_en')));
    });

    test('fastag_user subscribes if hasFastag', () async {
      await svc.reevaluate(
        installedHours: 1,
        activeDisputes: 0,
        hasExpiredDispute: false,
        isPremium: false,
        hasFastag: true,
        hasUpi: false,
        languageCode: 'en',
      );
      expect(subscribed, contains('fastag_user'));
      expect(subscribed, isNot(contains('upi_user')));
    });

    test('upi_user subscribes if hasUpi', () async {
      await svc.reevaluate(
        installedHours: 1,
        activeDisputes: 0,
        hasExpiredDispute: false,
        isPremium: false,
        hasFastag: false,
        hasUpi: true,
        languageCode: 'en',
      );
      expect(subscribed, contains('upi_user'));
    });

    test('all 9 topics evaluated each call', () async {
      await svc.reevaluate(
        installedHours: 100,
        activeDisputes: 1,
        hasExpiredDispute: true,
        isPremium: true,
        hasFastag: true,
        hasUpi: true,
        languageCode: 'hi',
        freeDisputesUsed: 0,
      );
      final total = subscribed.length + unsubscribed.length;
      expect(total, FcmTopicService.topics.length);
    });
  });

  group('FcmTopicService.subscribe / unsubscribe — swallow errors', () {
    test('subscribe throws → caller does NOT propagate', () async {
      // Use a generic Exception so the test does not need to import the
      // platform-specific FirebaseException plugin (which would also pull
      // platform channels into the test isolate).
      when(() => fcm.subscribeToTopic(any()))
          .thenThrow(Exception('subscribe failed'));
      // No expectThrow: the method swallows.
      await svc.subscribe('premium');
      verify(() => fcm.subscribeToTopic('premium')).called(1);
    });

    test('unsubscribe throws → caller does NOT propagate', () async {
      when(() => fcm.unsubscribeFromTopic(any()))
          .thenThrow(Exception('unsubscribe failed'));
      await svc.unsubscribe('premium');
      verify(() => fcm.unsubscribeFromTopic('premium')).called(1);
    });
  });

  group('DisputeStats.fromList', () {
    Dispute mk(DisputeType t, DisputeStatus s,
            {String id = 'd'}) =>
        Dispute(
          id: id,
          uid: 'u',
          type: t,
          status: s,
          amount: 1,
          txnDate: DateTime(2025, 1, 1),
          txnId: 'x',
          createdAt: DateTime(2025, 1, 1),
        );

    test('counts every non-resolved/non-expired status as active', () {
      final list = [
        mk(DisputeType.upiP2p, DisputeStatus.draft),
        mk(DisputeType.upiP2p, DisputeStatus.filedL1),
        mk(DisputeType.upiP2p, DisputeStatus.filedL2, id: 'd2'),
        mk(DisputeType.upiP2p, DisputeStatus.ombudsman, id: 'd3'),
      ];
      final s = DisputeStats.fromList(list);
      expect(s.activeDisputes, 4);
      expect(s.hasExpiredDispute, isFalse);
    });

    test('expired mark rises once one expired dispute exists', () {
      final list = [
        mk(DisputeType.upiP2p, DisputeStatus.filedL1),
        mk(DisputeType.upiP2p, DisputeStatus.expired, id: 'e1'),
      ];
      final s = DisputeStats.fromList(list);
      expect(s.hasExpiredDispute, isTrue);
      // expired is NOT counted in activeDisputes
      expect(s.activeDisputes, 1);
    });

    test('resolved does not contribute to active count', () {
      final list = [
        mk(DisputeType.upiP2p, DisputeStatus.resolved),
        mk(DisputeType.upiP2p, DisputeStatus.filedL1, id: 'd2'),
      ];
      expect(DisputeStats.fromList(list).activeDisputes, 1);
    });

    test('hasFastag true if at least one FASTag dispute', () {
      final list = [
        mk(DisputeType.upiP2p, DisputeStatus.filedL1),
        mk(DisputeType.fastag, DisputeStatus.filedL1, id: 'f1'),
      ];
      expect(DisputeStats.fromList(list).hasFastag, isTrue);
    });

    test('hasUpi true for upiP2p, upiP2m, imps (not for atm/fastag/etc)',
        () {
      final upiTypes = [
        DisputeType.upiP2p,
        DisputeType.upiP2m,
        DisputeType.imps,
      ];
      for (final t in upiTypes) {
        final s = DisputeStats.fromList([mk(t, DisputeStatus.filedL1)]);
        expect(s.hasUpi, isTrue, reason: '$t should count as UPI');
      }
      // And the negatives
      for (final t in [DisputeType.atm, DisputeType.fastag, DisputeType.bankCharge]) {
        final s = DisputeStats.fromList([mk(t, DisputeStatus.filedL1)]);
        expect(s.hasUpi, isFalse, reason: '$t should NOT count as UPI');
      }
    });
  });
}
