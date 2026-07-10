import 'package:flutter_test/flutter_test.dart';
import 'package:refund_radar/data/constants/bank_catalog.dart';

void main() {
  group('BankCatalog.banks', () {
    test('has 30 entries (17 original + 13 new)', () {
      expect(BankCatalog.banks.length, 30);
    });

    test('all ids are lowercase', () {
      for (final b in BankCatalog.banks) {
        expect(
          b.id,
          b.id.toLowerCase(),
          reason: 'bank id "${b.id}" should be lowercase',
        );
      }
    });

    test('all ids are unique', () {
      final ids = BankCatalog.banks.map((b) => b.id).toList();
      expect(ids.toSet().length, ids.length, reason: 'bank ids must be unique');
    });

    test("'other' is the last entry", () {
      expect(BankCatalog.banks.last.id, 'other');
      expect(BankCatalog.banks.last.name, 'Other bank');
    });

    test('every entry has non-empty id, name and short', () {
      for (final b in BankCatalog.banks) {
        expect(b.id, isNotEmpty);
        expect(b.name, isNotEmpty);
        expect(b.short, isNotEmpty);
      }
    });
  });

  group('BankCatalog.nodalEmailFor', () {
    test('returns known nodal email for hdfc', () {
      expect(
        BankCatalog.nodalEmailFor('hdfc'),
        'nodal.officer@hdfcbank.net',
      );
    });

    test('returns known nodal email for sbi', () {
      expect(
        BankCatalog.nodalEmailFor('sbi'),
        'customercare@sbi.co.in',
      );
    });

    test('returns known nodal email for icici', () {
      expect(
        BankCatalog.nodalEmailFor('icici'),
        'nodal@icicibank.com',
      );
    });

    test('returns known nodal email for a 13-new bank (kvb)', () {
      expect(
        BankCatalog.nodalEmailFor('kvb'),
        'nodal.officer@kvb.co.in',
      );
    });

    test('returns known nodal email for tmb (one of the new banks)', () {
      expect(
        BankCatalog.nodalEmailFor('tmb'),
        'customercare@tmb.in',
      );
    });

    test("returns null for unknown bank id", () {
      expect(BankCatalog.nodalEmailFor('unknown_bank'), isNull);
    });

    test("returns null for empty id", () {
      expect(BankCatalog.nodalEmailFor(''), isNull);
    });

    test("returns null for 'other' (no known nodal email)", () {
      expect(BankCatalog.nodalEmailFor('other'), isNull);
    });

    test('every known bank (except other) has a nodal email', () {
      final withoutOther =
          BankCatalog.banks.where((b) => b.id != 'other').toList();
      expect(withoutOther.length, 29);
      for (final b in withoutOther) {
        final email = BankCatalog.nodalEmailFor(b.id);
        expect(
          email,
          isNotNull,
          reason: 'expected nodal email for "${b.id}"',
        );
        expect(email, contains('@'));
      }
    });
  });
}
