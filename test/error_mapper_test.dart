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
    test('extracts bracketed firebase error code', () {
      final e = Exception('[cloud_firestore/permission-denied] Missing permissions.');
      expect(errorDetail(e), 'cloud_firestore/permission-denied');
    });

    test('extracts auth error code without brackets', () {
      final e = Exception('code: auth/invalid-credential');
      expect(errorDetail(e), 'auth/invalid-credential');
    });

    test('truncates long messages to 80 chars', () {
      final long = 'x' * 120;
      final e = Exception(long);
      final detail = errorDetail(e);
      expect(detail, isNotNull);
      expect(detail!.endsWith('…'), isTrue);
      expect(detail.length, 81); // 80 chars + ellipsis
    });

    test('returns short messages as-is', () {
      final e = Exception('short error');
      expect(errorDetail(e), 'short error');
    });
  });
}
