import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:refund_radar/services/revenue_cat_service.dart';

void main() {
  group('RevenueCatService.syncWithFirebaseUid', () {
    test('no-ops when not configured (does not throw)', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final svc = container.read(revenueCatServiceProvider);
      expect(svc.isConfigured, isFalse);
      await expectLater(
        svc.syncWithFirebaseUid('firebase-uid-abc'),
        completes,
      );
    });

    test('no-ops on empty uid', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final svc = container.read(revenueCatServiceProvider);
      await expectLater(svc.syncWithFirebaseUid(''), completes);
      await expectLater(svc.syncWithFirebaseUid('   '), completes);
    });
  });

  group('shouldSwallowLogInError', () {
    test('operationAlreadyInProgress is swallowed', () {
      expect(
        shouldSwallowLogInError(
          PurchasesErrorCode.operationAlreadyInProgressError,
        ),
        isTrue,
      );
    });

    test('other Purchases errors are non-fatal (swallowed)', () {
      expect(
        shouldSwallowLogInError(PurchasesErrorCode.networkError),
        isTrue,
      );
      expect(
        shouldSwallowLogInError(PurchasesErrorCode.unknownError),
        isTrue,
      );
    });
  });
}
