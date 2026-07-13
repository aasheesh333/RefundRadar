import 'package:flutter_test/flutter_test.dart';
import 'package:refund_radar/shared/utils/error_mapper.dart';

void main() {
  group('friendlyError', () {
    test('maps permission-denied to friendly message', () {
      final e = Exception('[cloud_firestore/permission-denied] Missing or insufficient permissions.');
      expect(friendlyError(e), contains('Tap Retry'));
    });

    test('maps network errors to offline message', () {
      final e = Exception('Failed host lookup: www.googleapis.com (network unavailable)');
      expect(friendlyError(e), contains('offline'));
    });

    test('maps unauthenticated to session expired', () {
      final e = Exception('[cloud_firestore/unauthenticated] User is not authenticated.');
      expect(friendlyError(e), contains('Session expired'));
    });

    test('maps operation-not-allowed to Firebase Console message', () {
      final e = Exception('[firebase_auth/operation-not-allowed] Anonymous sign-in is not enabled.');
      expect(friendlyError(e), contains('Firebase Console'));
    });

    test('maps timeout to timeout message', () {
      final e = Exception('DeadlineExceededException: deadline-exceeded');
      expect(friendlyError(e), contains('timed out'));
    });

    test('falls back to generic message for unknown errors', () {
      final e = Exception('Something completely unexpected');
      expect(friendlyError(e), 'Something went wrong. Tap Retry.');
    });
  });

  group('errorDetail', () {
    // In debug mode (including tests), errorDetail returns e.toString()
    // directly so developers see the full error. The regex extraction
    // only runs in release/profile mode.
    test('returns full toString in debug mode', () {
      final e = Exception('[cloud_firestore/permission-denied] Missing permissions.');
      // kDebugMode is true in tests, so we get the full string.
      expect(errorDetail(e), e.toString());
    });

    test('returns short messages as-is', () {
      final e = Exception('short error');
      expect(errorDetail(e), 'Exception: short error');
    });
  });
}
