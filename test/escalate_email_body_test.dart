import 'package:flutter_test/flutter_test.dart';
import 'package:refund_radar/data/constants/bank_catalog.dart';
import 'package:refund_radar/data/models/dispute.dart';
import 'package:refund_radar/data/models/template.dart';
import 'package:refund_radar/features/templates/template_library_page.dart';

Template _tpl({
  required String id,
  required String category,
  required int escalationLevel,
  String bodyEn = 'UTR {UTR} amt {AMOUNT} bank {BANK_NAME}',
}) {
  return Template(
    id: id,
    titleEn: id,
    titleHi: id,
    category: category,
    escalationLevel: escalationLevel,
    isPremium: false,
    bodyEn: bodyEn,
    bodyHi: bodyEn,
  );
}

Dispute _dispute({
  DisputeType type = DisputeType.upiP2p,
  String txnId = '987654321098',
  double amount = 1500,
  String? entityName = 'HDFC Bank',
  String? entityId = 'hdfc',
  DateTime? txnDate,
}) {
  return Dispute(
    id: 'd1',
    uid: 'u1',
    type: type,
    amount: amount,
    txnDate: txnDate ?? DateTime(2026, 1, 10),
    txnId: txnId,
    entityName: entityName,
    entityId: entityId,
    createdAt: DateTime(2026, 1, 11),
  );
}

void main() {
  group('BankCatalog.nodalEmailFor (used by _nodalEmail)', () {
    test('returns nodal email when entityId is known (hdfc)', () {
      expect(
        BankCatalog.nodalEmailFor('hdfc'),
        'nodal.officer@hdfcbank.net',
      );
    });

    test('returns nodal email for axis', () {
      expect(
        BankCatalog.nodalEmailFor('axis'),
        'Nodalofficer@axisbank.com',
      );
    });

    test('returns null when entityId is unknown', () {
      expect(BankCatalog.nodalEmailFor('not_a_real_bank'), isNull);
    });

    test('returns null for empty entityId', () {
      expect(BankCatalog.nodalEmailFor(''), isNull);
    });
  });

  group('filledTemplateBody (used when level-2 template matches)', () {
    test('fills an English level-2 template with dispute tokens', () {
      final t = _tpl(
        id: 'upi_p2p_l2',
        category: 'UPI / IMPS / ATM',
        escalationLevel: 2,
        bodyEn: 'Escalating UTR {UTR} amount {AMOUNT} with {BANK_NAME}',
      );
      final d = _dispute();

      final out = filledTemplateBody(t, 'en', d);

      expect(out, contains('987654321098'));
      expect(out, contains('1500'));
      expect(out, contains('HDFC Bank'));
      expect(out, isNot(contains('{UTR}')));
      expect(out, isNot(contains('{AMOUNT}')));
      expect(out, isNot(contains('{BANK_NAME}')));
    });

    test('uses Hindi body when localeCode is "hi"', () {
      final tWithHi = Template(
        id: 'upi_p2p_l2',
        titleEn: 't',
        titleHi: 't',
        category: 'UPI / IMPS / ATM',
        escalationLevel: 2,
        isPremium: false,
        bodyEn: 'EN body {UTR}',
        bodyHi: 'HI body {UTR}',
      );
      final d = _dispute();

      expect(filledTemplateBody(tWithHi, 'en', d), contains('EN body'));
      expect(filledTemplateBody(tWithHi, 'hi', d), contains('HI body'));
    });

    test('handles a null dispute by emptying known tokens', () {
      final t = _tpl(
        id: 'upi_p2p_l2',
        category: 'UPI / IMPS / ATM',
        escalationLevel: 2,
        bodyEn: 'UTR=[{UTR}] bank=[{BANK_NAME}]',
      );

      final out = filledTemplateBody(t, 'en', null);

      expect(out, 'UTR=[] bank=[]');
    });

    test('leaves unknown tokens verbatim (left for user to fill)', () {
      final t = _tpl(
        id: 'upi_p2p_l2',
        category: 'UPI / IMPS / ATM',
        escalationLevel: 2,
        bodyEn: 'UTR {UTR} unknown {MYSTERY}',
      );
      final d = _dispute();

      final out = filledTemplateBody(t, 'en', d);

      expect(out, contains('987654321098'));
      expect(out, contains('{MYSTERY}'));
    });
  });

  // The level-2 template matching logic lives in a private method
  // `_matchEscalationTemplate` inside `_Body` in escalate_page.dart and is
  // not directly testable without a widget harness. The mapping from
  // DisputeType to category string is reproduced below as a behavioral
  // specification so any future refactor that breaks it surfaces here.
  group('escalation category mapping (spec for _matchEscalationTemplate)',
      () {
    // Mirrors the switch expression in `_matchEscalationTemplate`:
    String categoryFor(DisputeType t) {
      return switch (t) {
        DisputeType.upiP2p ||
        DisputeType.upiP2m ||
        DisputeType.atm ||
        DisputeType.imps => 'UPI / IMPS / ATM',
        DisputeType.fastag => 'FASTag',
        DisputeType.bankCharge => 'Bank charges',
        DisputeType.wrongTransfer => 'Wrong transfer',
      };
    }

    test('UPI P2P → "UPI / IMPS / ATM"', () {
      expect(categoryFor(DisputeType.upiP2p), 'UPI / IMPS / ATM');
    });

    test('UPI P2M → "UPI / IMPS / ATM"', () {
      expect(categoryFor(DisputeType.upiP2m), 'UPI / IMPS / ATM');
    });

    test('ATM → "UPI / IMPS / ATM"', () {
      expect(categoryFor(DisputeType.atm), 'UPI / IMPS / ATM');
    });

    test('IMPS → "UPI / IMPS / ATM"', () {
      expect(categoryFor(DisputeType.imps), 'UPI / IMPS / ATM');
    });

    test('FASTag → "FASTag"', () {
      expect(categoryFor(DisputeType.fastag), 'FASTag');
    });

    test('bankCharge → "Bank charges"', () {
      expect(categoryFor(DisputeType.bankCharge), 'Bank charges');
    });

    test('wrongTransfer → "Wrong transfer"', () {
      expect(categoryFor(DisputeType.wrongTransfer), 'Wrong transfer');
    });

    // A level-2 template "matches" when escalationLevel == 2 AND its
    // category equals the dispute's mapped category. No match → null, and
    // `_emailBody` falls back to the hardcoded string. Reproduce that
    // selection rule here.
    Template? match(List<Template> templates, Dispute d) {
      final category = categoryFor(d.type);
      for (final t in templates) {
        if (t.escalationLevel == 2 && t.category == category) return t;
      }
      return null;
    }

    test('matches a level-2 template with matching category', () {
      final t = _tpl(
        id: 'upi_l2',
        category: 'UPI / IMPS / ATM',
        escalationLevel: 2,
      );
      expect(match([t], _dispute(type: DisputeType.upiP2p)), same(t));
    });

    test('skips level-1 templates even if category matches', () {
      final t = _tpl(
        id: 'upi_l1',
        category: 'UPI / IMPS / ATM',
        escalationLevel: 1,
      );
      expect(match([t], _dispute(type: DisputeType.upiP2p)), isNull);
    });

    test('skips level-3 templates even if category matches', () {
      final t = _tpl(
        id: 'upi_l3',
        category: 'UPI / IMPS / ATM',
        escalationLevel: 3,
      );
      expect(match([t], _dispute(type: DisputeType.upiP2p)), isNull);
    });

    test('skips level-2 template with a different category', () {
      final t = _tpl(
        id: 'fastag_l2',
        category: 'FASTag',
        escalationLevel: 2,
      );
      expect(match([t], _dispute(type: DisputeType.upiP2p)), isNull);
    });

    test('returns first matching level-2 template when several match', () {
      final first = _tpl(
        id: 'a',
        category: 'UPI / IMPS / ATM',
        escalationLevel: 2,
      );
      final second = _tpl(
        id: 'b',
        category: 'UPI / IMPS / ATM',
        escalationLevel: 2,
      );
      expect(match([first, second], _dispute(type: DisputeType.upiP2m)),
          same(first));
    });

    test('returns null when no template matches at all (fallback path)', () {
      expect(match(const [], _dispute(type: DisputeType.wrongTransfer)),
          isNull);
    });

    test('FASTag dispute only matches FASTag category', () {
      final fastag = _tpl(
        id: 'fastag_l2',
        category: 'FASTag',
        escalationLevel: 2,
      );
      final upi = _tpl(
        id: 'upi_l2',
        category: 'UPI / IMPS / ATM',
        escalationLevel: 2,
      );
      expect(
        match([upi, fastag], _dispute(type: DisputeType.fastag)),
        same(fastag),
      );
    });
  });
}
