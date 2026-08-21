/// Material-style form validators for RefundRadar input fields.
///
/// Every function returns `null` when the input is valid, otherwise a crisp,
/// human-readable error message — so they can be passed directly to
/// `TextFormField.validator`. All regular expressions are precompiled once
/// as static finals to avoid per-keystroke compilation cost.
///
/// Fields that are genuinely optional ([validateUtrRrn],
/// [validateAccountLast4]) treat null/empty input as valid; required fields
/// ([validateName], [validateEmail], [validatePhone], [validateAmount],
/// [validateFreeText]) reject blank input immediately.
library;

/// Letters (Latin + Devanagari), spaces, dots and hyphens only — no digits
/// or symbols that clearly aren't part of a person's name.
final RegExp _nameAllowed =
    RegExp(r'^[A-Za-z\u0900-\u097F .\-]{2,50}$');

/// RFC-5322-ish email shape: local@domain.tld, no surrounding spaces.
final RegExp _email = RegExp(
  r'^[A-Za-z0-9.!#$%&*+/=?^_`{|}~-]+@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$',
);

/// Indian mobile: optional +91 / 91 / 0 prefix, then 10 digits starting 6-9.
final RegExp _indianMobile = RegExp(r'^(?:\+91|91|0)?[6-9]\d{9}$');

/// Whitespace/hyphens stripped from phone input before matching.
final RegExp _phoneStrip = RegExp(r'[\s-]+');

/// Plain numeric amount with at most 2 decimal places.
final RegExp _amount = RegExp(r'^\d+(\.\d{1,2})?$');

/// UPI/NEFT/RTGS/IMPS UTR: 12–22 alphanumeric characters.
final RegExp _utr = RegExp(r'^[A-Za-z0-9]{12,22}$');

/// RRN: exactly 12 digits.
final RegExp _rrn = RegExp(r'^\d{12}$');

/// Exactly 4 digits (masked account number tail).
final RegExp _last4 = RegExp(r'^\d{4}$');

/// All whitespace — used to reject "  " style blank-but-not-empty input.
final RegExp _allSpaces = RegExp(r'^\s+$');

/// All digits — junk detector for free-text fields.
final RegExp _allDigits = RegExp(r'^\d+$');

/// Single repeated character ("aaaaaa", "-----") — junk detector.
final RegExp _sameCharRepeat = RegExp(r'^(.)\1*$');

/// Full name: required, 2–50 chars, letters/spaces/dots/hyphens,
/// not all-spaces.
String? validateName(String? value) {
  if (value == null || value.isEmpty) return 'Please enter your full name';
  final v = value.trim();
  if (v.isEmpty || _allSpaces.hasMatch(v)) {
    return 'Please enter your full name';
  }
  if (!_nameAllowed.hasMatch(v)) {
    return 'Name must be 2–50 characters: letters, spaces, dots or hyphens only';
  }
  return null;
}

/// Email: required, RFC-ish shape, max 254 characters (RFC 5321 limit).
String? validateEmail(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Please enter your email address';
  }
  final v = value.trim();
  if (v.length > 254) return 'Email address is too long';
  if (!_email.hasMatch(v)) return 'Please enter a valid email address';
  return null;
}

/// Indian mobile number: required. Accepts optional +91 / 91 / 0 prefix and
/// ignores spaces/hyphens; the core must be 10 digits starting with 6–9.
String? validatePhone(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Please enter your mobile number';
  }
  final v = value.trim().replaceAll(_phoneStrip, '');
  if (!_indianMobile.hasMatch(v)) {
    return 'Please enter a valid 10-digit Indian mobile number';
  }
  return null;
}

/// Amount in ₹: required, numeric, > 0, ≤ 1,00,00,000, at most 2 decimals.
/// Thousands commas (12,500.00) are stripped before validation.
String? validateAmount(String? value) {
  if (value == null || value.trim().isEmpty) return 'Please enter the amount';
  final v = value.trim().replaceAll(',', '');
  if (!_amount.hasMatch(v)) {
    return 'Amount must be a number with at most 2 decimal places';
  }
  final n = double.tryParse(v);
  if (n == null || n <= 0) return 'Amount must be greater than zero';
  if (n > 10000000) return 'Amount cannot exceed ₹1,00,00,000';
  return null;
}

/// OPTIONAL: bank reference. Blank is valid. If provided, must be either a
/// UTR (12–22 alphanumeric, per UPI/NEFT/RTGS/IMPS formats) or an RRN
/// (exactly 12 digits).
String? validateUtrRrn(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  final v = value.trim();
  if (_utr.hasMatch(v) || _rrn.hasMatch(v)) return null;
  return 'Enter a valid UTR (12–22 characters) or RRN (12 digits)';
}

/// OPTIONAL: last 4 digits of the disputed account. Blank is valid; if
/// provided, must be exactly 4 digits.
String? validateAccountLast4(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  if (!_last4.hasMatch(value.trim())) return 'Enter exactly 4 digits';
  return null;
}

/// Free-text description/note: required, [min]–[max] characters after
/// trimming, and not junk (all digits or one repeated character).
String? validateFreeText(
  String? value, {
  int min = 10,
  int max = 2000,
  String label = 'Description',
}) {
  if (value == null || value.trim().isEmpty) return '$label is required';
  final v = value.trim();
  if (v.length < min) return '$label must be at least $min characters';
  if (v.length > max) return '$label must be at most $max characters';
  if (_allDigits.hasMatch(v) || _sameCharRepeat.hasMatch(v)) {
    return 'Please provide a meaningful $label';
  }
  return null;
}
