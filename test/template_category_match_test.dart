import 'package:flutter_test/flutter_test.dart';
import 'package:refund_radar/data/models/dispute.dart';
import 'package:refund_radar/data/models/template.dart';
import 'package:refund_radar/data/repositories/template_repository.dart';

Template _t({
  required String id,
  required String category,
  int level = 2,
  bool premium = false,
}) =>
    Template(
      id: id,
      titleEn: id,
      titleHi: id,
      category: category,
      escalationLevel: level,
      isPremium: premium,
      bodyEn: '',
      bodyHi: '',
    );

void main() {
  final repo = TemplateRepository();
  final templates = [
    _t(id: 'upi_free', category: 'UPI / IMPS / ATM'),
    _t(id: 'upi_pro1', category: 'UPI / IMPS / ATM', premium: true),
    _t(id: 'upi_pro2', category: 'UPI / IMPS / ATM', premium: true),
    _t(id: 'fastag_l2', category: 'FASTag'),
    _t(id: 'upi_l1', category: 'UPI / IMPS / ATM', level: 1),
  ];

  group('TemplateRepository.categoryFor', () {
    test('UPI family shares one category', () {
      expect(
        TemplateRepository.categoryFor(DisputeType.upiP2p),
        'UPI / IMPS / ATM',
      );
      expect(
        TemplateRepository.categoryFor(DisputeType.imps),
        'UPI / IMPS / ATM',
      );
      expect(TemplateRepository.categoryFor(DisputeType.fastag), 'FASTag');
      expect(
        TemplateRepository.categoryFor(DisputeType.bankCharge),
        'Bank charges',
      );
      expect(
        TemplateRepository.categoryFor(DisputeType.wrongTransfer),
        'Wrong transfer',
      );
    });
  });

  group('TemplateRepository.matchForCategory', () {
    test('returns a free template first for non-premium user', () {
      final match = repo.matchForCategory(
        templates,
        DisputeType.upiP2p,
        const {},
        isPremiumUser: false,
      );
      expect(match?.id, 'upi_free');
    });

    test('a premium user matches the first level-2 row entry', () {
      final match = repo.matchForCategory(
        templates,
        DisputeType.upiP2p,
        const {},
        isPremiumUser: true,
      );
      expect(match, isNotNull);
      expect(match?.escalationLevel, 2);
    });

    test('only considers the requested level', () {
      final match = repo.matchForCategory(
        templates,
        DisputeType.upiP2p,
        const {},
        isPremiumUser: true,
      );
      expect(match?.id, isNot('upi_l1'));
    });

    test('returns null when no level-2 template exists for the category', () {
      final match = repo.matchForCategory(
        templates,
        DisputeType.bankCharge,
        const {},
        isPremiumUser: false,
      );
      expect(match, isNull);
    });
  });

  group('TemplateRepository.splitForCategory', () {
    test('partitions free vs pro for a non-premium user', () {
      final buckets = repo.splitForCategory(
        templates,
        DisputeType.upiP2p,
        const {},
        isPremiumUser: false,
      );
      expect(buckets.free.map((t) => t.id), ['upi_free']);
      expect(buckets.pro.map((t) => t.id), ['upi_pro1', 'upi_pro2']);
    });

    // Regression: previously a premium user saw EVERY template in the
    // Free bucket and an empty Pro bucket (since partition was driven
    // by the user's lock state, not the template's own isPremium flag).
    // The new behaviour partitions on isPremium only — the Pro tab
    // remains populated after purchase so the user can still discover
    // and switch back to a premium template.
    test('premium user still sees the Pro tab (partition is by isPremium, not lock)', () {
      final buckets = repo.splitForCategory(
        templates,
        DisputeType.upiP2p,
        const {},
        isPremiumUser: true,
      );
      expect(buckets.free.map((t) => t.id), ['upi_free']);
      expect(buckets.pro.map((t) => t.id), ['upi_pro1', 'upi_pro2']);
    });

    test('fastag_l2 lands in Pro bucket (only premium FASTag templates)', () {
      final withFastagFree = [
        // Existing fastag_l2 is non-premium by default in this fixture.
        // Override it to premium=true so it would land in Pro.
        _t(id: 'fastag_l2', category: 'FASTag', premium: true),
        _t(id: 'fastag_free', category: 'FASTag'),
      ];
      final buckets = repo.splitForCategory(
        withFastagFree,
        DisputeType.fastag,
        const {},
        isPremiumUser: false,
      );
      expect(buckets.free.map((t) => t.id), ['fastag_free']);
      expect(buckets.pro.map((t) => t.id), ['fastag_l2']);
    });
  });
}
