import 'package:flutter_test/flutter_test.dart';
import 'package:refund_radar/features/dispute_create/create_dispute_auth_guard.dart';
import 'package:refund_radar/features/dispute_create/fallback_banks.dart';

void main() {
  group('isValidAuthUid', () {
    test('null is invalid — save must show SnackBar, not silent return', () {
      expect(isValidAuthUid(null), isFalse);
    });

    test('empty string is invalid', () {
      expect(isValidAuthUid(''), isFalse);
    });

    test('whitespace-only is invalid', () {
      expect(isValidAuthUid('   '), isFalse);
    });

    test('non-empty uid is valid', () {
      expect(isValidAuthUid('uid-123'), isTrue);
    });
  });

  group('kFallbackBanks', () {
    test('has major banks + other for picker error path', () {
      expect(kFallbackBanks, isNotEmpty);
      final ids = kFallbackBanks.map((b) => b.id).toSet();
      expect(ids, containsAll(['hdfc', 'icici', 'axis', 'sbi', 'other']));
    });
  });
}
