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

    test('everything is free for a premium user', () {
      final buckets = repo.splitForCategory(
        templates,
        DisputeType.upiP2p,
        const {},
        isPremiumUser: true,
      );
      expect(buckets.pro, isEmpty);
      expect(buckets.free.length, 3);
    });
  });
}
