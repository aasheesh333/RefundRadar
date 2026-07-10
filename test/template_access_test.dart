import 'package:flutter_test/flutter_test.dart';
import 'package:refund_radar/data/models/template.dart';
import 'package:refund_radar/data/repositories/template_repository.dart';

Template _template({required String id, required bool isPremium}) {
  return Template(
    id: id,
    titleEn: 'Premium template',
    titleHi: 'Premium template',
    category: 'Advanced / legal',
    escalationLevel: 3,
    isPremium: isPremium,
    bodyEn: 'Body',
    bodyHi: 'Body',
  );
}

void main() {
  group('TemplateRepository.isLocked', () {
    test('locks premium template for free user', () {
      final repo = TemplateRepository();
      final template = _template(id: 'premium_1', isPremium: true);

      expect(repo.isLocked(template, const {}, isPremiumUser: false), isTrue);
    });

    test('unlocks premium template for premium user', () {
      final repo = TemplateRepository();
      final template = _template(id: 'premium_1', isPremium: true);

      expect(repo.isLocked(template, const {}, isPremiumUser: true), isFalse);
    });

    test('unlocks free allowlist template for free user', () {
      final repo = TemplateRepository();
      final template = _template(id: 'free_allowed', isPremium: true);

      expect(
        repo.isLocked(template, const {'free_allowed'}, isPremiumUser: false),
        isFalse,
      );
    });

    test('never locks non-premium template', () {
      final repo = TemplateRepository();
      final template = _template(id: 'free_json', isPremium: false);

      expect(repo.isLocked(template, const {}, isPremiumUser: false), isFalse);
    });
  });
}
