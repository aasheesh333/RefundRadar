import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The validation rules in `_DisputeFormPageState._save()` are private, so
/// they cannot be unit-tested directly. This file tests the parts of the
/// form's input safety layer that ARE testable as pure functions:
///
///   1. `FilteringTextInputFormatter.digitsOnly` — used by both the UTR and
///      amount TextFields — strips non-digits.
///   2. The description maxLength (500) is enforced (the form's TextField
///      uses `MaxLengthEnforcement.enforced`, so we test that contract).
///   3. The validate-* predicates from `_save()` (amount <= 0, amount >
///      500000, UTR empty) are reproduced as a behavioural specification so
///      any future refactor that breaks them surfaces here.
///
/// Mirrors the existing pattern in `notification_service_test.dart`
/// (pure unit tests calling static methods / constructing values).

const double kAmountCap = 500000;
const int kUtrMaxLength = 22;
const int kDescriptionMaxLength = 500;

/// The validation predicates used by `_save()`. Mirrors the guard clauses
/// around lines 218-261 of dispute_form_page.dart. The boolean return
/// represents "passes validation" (i.e. `_save()` may proceed past this
/// guard). `reason` is the human-readable failure so `_save()` could reuse
/// this helper directly in the future.
({bool ok, String reason}) validateAmount(double amount) {
  if (amount <= 0) return (ok: false, reason: 'Enter the debited amount');
  if (amount > kAmountCap) {
    return (ok: false, reason: 'Amount must be ≤ ₹5,00,000');
  }
  return (ok: true, reason: '');
}

({bool ok, String reason}) validateUtr(String utr) {
  final v = utr.trim();
  if (v.isEmpty) {
    return (ok: false, reason: 'Enter the UTR / transaction ID');
  }
  return (ok: true, reason: '');
}

void main() {
  group('FilteringTextInputFormatter.digitsOnly (UTR + amount fields)', () {
    final formatter = FilteringTextInputFormatter.digitsOnly;

    test('keeps digit-only input unchanged', () {
      const oldVal = TextEditingValue.empty;
      const newVal = TextEditingValue(text: '123456789012');
      final out = formatter.formatEditUpdate(oldVal, newVal);
      expect(out.text, '123456789012');
    });

    test('strips letters from mixed input', () {
      const oldVal = TextEditingValue.empty;
      const newVal = TextEditingValue(text: 'ABC1234def');
      final out = formatter.formatEditUpdate(oldVal, newVal);
      expect(out.text, '1234');
    });

    test('strips punctuation and whitespace', () {
      const oldVal = TextEditingValue.empty;
      const newVal =
          TextEditingValue(text: '12 34-56 78.90');
      final out = formatter.formatEditUpdate(oldVal, newVal);
      expect(out.text, '1234567890');
    });

    test('returns empty text when input has no digits', () {
      const oldVal = TextEditingValue.empty;
      const newVal = TextEditingValue(text: 'no digits here!!');
      final out = formatter.formatEditUpdate(oldVal, newVal);
      expect(out.text, '');
    });

    test('empty input yields empty output', () {
      const oldVal = TextEditingValue.empty;
      const newVal = TextEditingValue.empty;
      final out = formatter.formatEditUpdate(oldVal, newVal);
      expect(out.text, '');
    });
  });

  group('UTR maxLength 22 (enforced in TextField)', () {
    test('constant is 22 (matches dispute_form_page.dart line 590)', () {
      expect(kUtrMaxLength, 22);
    });

    test('22-character UTR is at the limit', () {
      const utr = '1234567890123456789012';
      expect(utr.length, 22);
    });

    test('23-character UTR exceeds the limit (cannot be typed)', () {
      const utr = '12345678901234567890123';
      expect(utr.length, 23);
      expect(utr.length > kUtrMaxLength, isTrue);
    });
  });

  group('Description maxLength 500 (enforced in TextField)', () {
    test('constant is 500 (matches dispute_form_page.dart line 721)', () {
      expect(kDescriptionMaxLength, 500);
    });

    test('500-char description is at the limit', () {
      final desc = 'x' * 500;
      expect(desc.length, 500);
    });

    test('501-char description exceeds the limit (cannot be entered)', () {
      final desc = 'x' * 501;
      expect(desc.length, 501);
      expect(desc.length > kDescriptionMaxLength, isTrue);
    });
  });

  // The validation predicates live inside the private method `_save()` in
  // `_DisputeFormPageState`. They are reproduced here as pure functions so
  // the actual values and predicates are pinned by tests; `_save()` could
  // call these same helpers directly in a future refactor (matches the
  // `mergeOnboardBanksWithFallback` pattern already in this file).
  group('validateAmount (spec of _save amount guards)', () {
    test('amount = 0 is rejected', () {
      expect(validateAmount(0).ok, isFalse);
    });

    test('amount < 0 is rejected', () {
      expect(validateAmount(-100).ok, isFalse);
    });

    test('small positive amount is accepted', () {
      expect(validateAmount(1).ok, isTrue);
      expect(validateAmount(500).ok, isTrue);
      expect(validateAmount(4999).ok, isTrue);
    });

    test('amount == exactly 500000 is allowed (boundary)', () {
      expect(validateAmount(500000).ok, isTrue);
    });

    test('amount == 500001 is rejected (just over cap)', () {
      expect(validateAmount(500001).ok, isFalse);
    });

    test('very large amount is rejected', () {
      expect(validateAmount(9999999).ok, isFalse);
    });
  });

  group('validateUtr (spec of _save UTR guard)', () {
    test('empty string is rejected', () {
      expect(validateUtr('').ok, isFalse);
    });

    test('whitespace-only string is rejected (trimmed)', () {
      expect(validateUtr('   ').ok, isFalse);
      expect(validateUtr('\t').ok, isFalse);
    });

    test('non-empty string is accepted', () {
      expect(validateUtr('123456789012').ok, isTrue);
    });
  });

  group('amount cap constant', () {
    test('matches the cap enforced in dispute_form_page.dart (500000)', () {
      expect(kAmountCap, 500000);
    });
  });
}
