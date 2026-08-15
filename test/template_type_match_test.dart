import 'package:flutter_test/flutter_test.dart';
import 'package:refund_radar/data/models/dispute.dart';
import 'package:refund_radar/data/models/template.dart';
import 'package:refund_radar/data/repositories/template_repository.dart';

Template _t({
  required String id,
  int level = 1,
  bool premium = false,
}) =>
    Template(
      id: id,
      titleEn: id,
      titleHi: id,
      category: 'UPI / IMPS / ATM',
      escalationLevel: level,
      isPremium: premium,
      bodyEn: '',
      bodyHi: '',
    );

void main() {
  final repo = TemplateRepository();

  final templates = [
    _t(id: 'upi_p2p_bank_complaint', level: 1),
    _t(id: 'upi_p2p_npci_escalation', level: 2),
    _t(id: 'upi_p2p_advocate', level: 2, premium: true),
    _t(id: 'upi_p2m_bank_complaint', level: 1),
    _t(id: 'upi_p2m_npci_escalation', level: 2),
    _t(id: 'upi_chargeback_generic', level: 2),
    _t(id: 'atm_bank_complaint', level: 1),
    _t(id: 'atm_npci_portal', level: 2),
    _t(id: 'imps_bank_complaint', level: 1),
    _t(id: 'imps_npci_portal', level: 2),
    _t(id: 'upi_imp_personally_visit_branch_l1', level: 1),
  ];

  group('matchesType', () {
    test('UPI P2P sees its own + generic UPI templates only', () {
      final ids = templates
          .where((t) => repo.matchesType(t, DisputeType.upiP2p))
          .map((t) => t.id)
          .toSet();
      expect(ids, containsAll([
        'upi_p2p_bank_complaint',
        'upi_p2p_npci_escalation',
        'upi_chargeback_generic',
      ]));
      expect(ids, isNot(contains('upi_p2m_bank_complaint')));
      expect(ids, isNot(contains('atm_bank_complaint')));
    });

    test('UPI P2M also gets the friendly L1 shared template', () {
      final ids = templates
          .where((t) => repo.matchesType(t, DisputeType.upiP2m))
          .map((t) => t.id)
          .toSet();
      expect(ids, contains('upi_p2m_bank_complaint'));
      expect(ids, contains('upi_chargeback_generic'));
      expect(ids, isNot(contains('upi_p2p_bank_complaint')));
    });

    test('ATM sees only atm_ templates', () {
      final ids = templates
          .where((t) => repo.matchesType(t, DisputeType.atm))
          .map((t) => t.id)
          .toSet();
      expect(ids, {'atm_bank_complaint', 'atm_npci_portal'});
    });

    test('IMPS sees imps_ + the branch-visit L1', () {
      final ids = templates
          .where((t) => repo.matchesType(t, DisputeType.imps))
          .map((t) => t.id)
          .toSet();
      expect(ids, {
        'imps_bank_complaint',
        'imps_npci_portal',
        'upi_imp_personally_visit_branch_l1',
      });
    });
  });

  group('defaultForType', () {
    test('picks the free L1 by default', () {
      final def = repo.defaultForType(templates, DisputeType.upiP2p);
      expect(def?.id, 'upi_p2p_bank_complaint');
      expect(def?.escalationLevel, 1);
      expect(def?.isPremium, false);
    });

    test('falls back to first free when no free L1 exists', () {
      final onlyL2 = [
        _t(id: 'upi_p2p_npci_escalation', level: 2),
        _t(id: 'upi_p2p_advocate', level: 2, premium: true),
      ];
      final def = repo.defaultForType(onlyL2, DisputeType.upiP2p);
      expect(def?.id, 'upi_p2p_npci_escalation');
    });

    test('falls back to first relevant when all are premium', () {
      final allPro = [
        _t(id: 'upi_p2p_advocate', level: 2, premium: true),
        _t(id: 'upi_p2p_pro_l1', level: 1, premium: true),
      ];
      final def = repo.defaultForType(allPro, DisputeType.upiP2p);
      expect(def?.id, 'upi_p2p_pro_l1');
    });

    test('null when nothing matches the type', () {
      expect(repo.defaultForType(templates, DisputeType.wrongTransfer), isNull);
    });

    test('same stable default for premium users', () {
      final def = repo.defaultForType(templates, DisputeType.upiP2p);
      expect(def?.id, 'upi_p2p_bank_complaint');
    });
  });

  group('splitForType', () {
    test('free bucket = non-premium templates for the type, ordered by level',
        () {
      final buckets = repo.splitForType(templates, DisputeType.upiP2p);
      expect(buckets.free.map((t) => t.id), [
        // The generic branch-visit L1 is shared into the P2P type.
        'upi_imp_personally_visit_branch_l1',
        'upi_p2p_bank_complaint',
        'upi_chargeback_generic',
        'upi_p2p_npci_escalation',
      ]);
      expect(buckets.pro.map((t) => t.id), ['upi_p2p_advocate']);
    });

    test('buckets are disjoint and complete for the type', () {
      final buckets = repo.splitForType(templates, DisputeType.imps);
      final freeIds = buckets.free.map((t) => t.id).toSet();
      final proIds = buckets.pro.map((t) => t.id).toSet();
      expect(freeIds.intersection(proIds), isEmpty);
      expect(freeIds.union(proIds), repo.filterForType(templates, DisputeType.imps).map((t) => t.id).toSet());
    });
  });
}
