import 'package:flutter_test/flutter_test.dart';
import 'package:refund_radar/data/models/dispute.dart';
import 'package:refund_radar/features/home/home_page.dart';

void main() {
  Dispute mk(String id, DisputeStatus status) => Dispute(
        id: id,
        uid: 'u1',
        type: DisputeType.upiP2p,
        status: status,
        amount: 1000,
        txnDate: DateTime(2025, 1, 10),
        txnId: 'UTR$id',
        createdAt: DateTime(2025, 1, 1),
      );

  group('activeHomeDisputes', () {
    test('includes draft + filed statuses; excludes resolved and expired', () {
      final input = [
        mk('a', DisputeStatus.draft),
        mk('b', DisputeStatus.filedL1),
        mk('c', DisputeStatus.filedL2),
        mk('d', DisputeStatus.ombudsman),
        mk('e', DisputeStatus.resolved),
        mk('f', DisputeStatus.expired),
      ];
      final active = activeHomeDisputes(input);
      // New disputes are created as draft until L1 is filed — they must
      // appear on Home or the create → home flow looks broken.
      expect(active.map((d) => d.id).toList(), ['a', 'b', 'c', 'd']);
    });

    test('empty when only terminal disputes', () {
      final input = [
        mk('e', DisputeStatus.resolved),
        mk('f', DisputeStatus.expired),
      ];
      expect(activeHomeDisputes(input), isEmpty);
    });

    test('includes drafts (create form saves as draft)', () {
      final input = [
        mk('a', DisputeStatus.draft),
        mk('b', DisputeStatus.draft),
      ];
      expect(activeHomeDisputes(input).map((d) => d.id).toList(), ['a', 'b']);
    });

    test('preserves all non-terminal statuses', () {
      final input = [
        mk('a', DisputeStatus.draft),
        mk('b', DisputeStatus.filedL1),
        mk('c', DisputeStatus.filedL2),
        mk('d', DisputeStatus.ombudsman),
      ];
      expect(activeHomeDisputes(input).length, 4);
    });
  });
}
