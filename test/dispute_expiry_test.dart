import 'package:flutter_test/flutter_test.dart';
import 'package:refund_radar/data/models/activity_log_entry.dart';
import 'package:refund_radar/data/models/dispute.dart';

void main() {
  Dispute mk({
    required DateTime createdAt,
    required DisputeStatus status,
    Map<String, DateTime?>? filedDates,
  }) => Dispute(
    id: '1',
    uid: 'u1',
    type: DisputeType.upiP2p,
    status: status,
    amount: 1000,
    txnDate: createdAt,
    txnId: 'x',
    createdAt: createdAt,
    filedDates: filedDates ?? const {},
  );

  group('Dispute auto-expiry helpers', () {
    test('draft never expires', () {
      final d = mk(
        createdAt: DateTime(2024, 1, 1),
        status: DisputeStatus.draft,
      );
      expect(d.shouldAutoExpire(DateTime.now()), false);
    });

    test('resolved never expires', () {
      final d = mk(
        createdAt: DateTime(2024, 1, 1),
        status: DisputeStatus.resolved,
      );
      expect(d.shouldAutoExpire(DateTime.now()), false);
    });

    test('expired never re-expires', () {
      final d = mk(
        createdAt: DateTime(2024, 1, 1),
        status: DisputeStatus.expired,
      );
      expect(d.shouldAutoExpire(DateTime.now()), false);
    });

    test('expires after 91 days of no filing', () {
      final created = DateTime.now().subtract(const Duration(days: 100));
      final d = mk(createdAt: created, status: DisputeStatus.filedL1);
      expect(d.shouldAutoExpire(DateTime.now()), true);
    });

    test('does not expire at exactly 90 days', () {
      final created = DateTime.now().subtract(const Duration(days: 90));
      final d = mk(createdAt: created, status: DisputeStatus.filedL1);
      expect(d.shouldAutoExpire(DateTime.now()), false);
    });

    test('resets clock after a new filing', () {
      final created = DateTime.now().subtract(const Duration(days: 200));
      final d = mk(
        createdAt: created,
        status: DisputeStatus.filedL2,
        filedDates: {
          'l1': DateTime.now().subtract(const Duration(days: 200)),
          'l2': DateTime.now().subtract(const Duration(days: 5)),
        },
      );
      expect(d.shouldAutoExpire(DateTime.now()), false);
    });

    test('reopenTarget from expired returns most advanced prior filing', () {
      final d = mk(
        createdAt: DateTime(2024, 1, 1),
        status: DisputeStatus.expired,
        filedDates: {
          'l1': DateTime(2024, 2, 1),
          'l2': DateTime(2024, 3, 1),
        },
      );
      expect(d.reopenTarget(), DisputeStatus.filedL2);
    });
  });
}
