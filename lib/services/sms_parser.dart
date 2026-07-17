class SmsParseResult {
  final String? utr;
  final double? amount;
  final DateTime? date;
  final String? vpa;
  SmsParseResult({this.utr, this.amount, this.date, this.vpa});
}

class SmsParser {
  /// UPI UTRs are 12 digits but IMPS/FASTag RRNs can be 15-22 digits (Task C3).
  /// The 22-digit ceiling keeps us off clearly non-UTR long numerics (e.g.
  /// 24-digit ISO timestamps or 30+ character tracking numbers).
  static final _utrRegex = RegExp(r'\b(\d{12,22})\b');
  /// Spaced 12-digit run (`1234 5678 9012`) — some banks write UTRs this
  /// way. Stripped to a contiguous candidate before the Aadhaar filter.
  static final _spacedUtrRegex = RegExp(r'\b(\d{4}\s\d{4}\s\d{4})\b');
  /// Currency amount. Covers Rs/INR/₹ prefixes and `Amt:`/`Amount:` label
  /// prefixes; the `/-` suffix some banks append (Rs.500/-) is left after
  /// the captured digit run and so ignored.
  static final _amountRegex = RegExp(
      r'(?:Rs\.?|INR|₹)\s*([\d,]+(?:\.\d+)?)'
      r'|(?:Amt|Amount)\s*:?\s*([\d,]+(?:\.\d+)?)');
  /// Transaction date. Supports dd/mm/yyyy, dd-mm-yyyy (2- or 4-digit
  /// year), yyyy-mm-dd, and dd-MMM-yy (1-2 digit day, 2-4 digit year).
  static final _dateRegex = RegExp(
      r'(\d{1,2}[-/](?:0?[1-9]|1[012])[-/]\d{2,4})'
      r'|(\d{4}-\d{2}-\d{2})'
      r'|(\d{1,2}[-][A-Za-z]{3}[-]\d{2,4})');
  /// VPA (Virtual Payment Address) — `name@psp`. Emails match the same
  /// shape, so candidates are filtered by [_isLikelyVpa] (excludes dotted
  /// domains + known email providers).
  static final _vpaRegex = RegExp(r'\b([\w.]+@[\w.]+)\b');

  static SmsParseResult parse(String sms) {
    final effective = sms.replaceAll('\u00A0', ' '); // nbsp → space (some banks)
    String? utr;
    var utrMatch = _utrRegex.firstMatch(effective);
    if (utrMatch == null) {
      // Fall back to the spaced 4+4+4 form and strip spaces to form a
      // contiguous 12-digit candidate.
      final spaced = _spacedUtrRegex.firstMatch(effective);
      if (spaced != null) {
        utrMatch = RegExp(r'(\d{12})')
            .firstMatch(spaced.group(1)!.replaceAll(' ', ''));
      }
    }
    if (utrMatch != null) {
      final candidate = utrMatch.group(1)!;
      // Verify the match isn't an Aadhaar number or other non-transaction
      // ID before committing to it (Task C3 false-positive filter).
      if (_isLikelyTransactionId(candidate, effective)) {
        utr = candidate;
      }
    }

    double? amount;
    final amtMatch = _amountRegex.firstMatch(effective);
    if (amtMatch != null) {
      final raw = (amtMatch.group(1) ?? amtMatch.group(2) ?? '')
          .replaceAll(',', '')
          .trim();
      amount = double.tryParse(raw);
    }

    DateTime? date;
    final dateMatch = _dateRegex.firstMatch(effective);
    if (dateMatch != null) {
      final raw = dateMatch.group(0) ?? '';
      date = DateTime.tryParse(raw) ?? _tryParseFlexible(raw);
    }

    String? vpa;
    for (final m in _vpaRegex.allMatches(effective)) {
      final candidate = m.group(1)!;
      if (_isLikelyVpa(candidate)) {
        vpa = candidate;
        break;
      }
    }

    return SmsParseResult(utr: utr, amount: amount, date: date, vpa: vpa);
  }

  /// Email-vs-VPA disambiguation. A VPA's domain (after @) is a PSP
  /// handle like `okhdfcbank`, `paytm`, `upi`, `ybl` — never dotted and
  /// never a known mail provider. Reject dotted domains (gmail.com etc.)
  /// and an explicit provider allowlist so `user@gmail.com` isn't
  /// captured as a VPA.
  static bool _isLikelyVpa(String candidate) {
    final at = candidate.lastIndexOf('@');
    if (at < 0) return false;
    final domain = candidate.substring(at + 1).toLowerCase();
    if (domain.contains('.')) return false;
    const emailProviders = {
      'gmail', 'yahoo', 'outlook', 'hotmail', 'rediffmail',
      'live', 'msn', 'aol', 'icloud', 'zoho', 'protonmail',
    };
    if (emailProviders.contains(domain)) return false;
    return true;
  }

  /// Aadhaar / non-transaction false-positive filter (Task C3).
  ///
  /// The 12-22 digit regex now also catches Aadhaar numbers (12 digits,
  /// sometimes written `1234 5678 9012`). We exclude those when no
  /// UTR/RRN/ref/txn keyword is nearby, so bank SMS still parse and
  /// govt/OTP SMS don't latch onto a 12-digit substring. Longer matches
  /// (13-22 digits) are never Aadhaar, so they always pass.
  static bool _isLikelyTransactionId(String match, String fullSms) {
    // The SMS body explicitly mentions Aadhaar → skip regardless of length.
    if (fullSms.toLowerCase().contains('aadhaar')) return false;

    // A 12-digit match could be an Aadhaar number — especially when the
    // body shows it in the canonical `4+4+4` layout. Accept only when a
    // UTR / RRN / ref / txn keyword is present to anchor it as a txn id.
    if (match.length == 12 &&
        RegExp(r'\d{4}\s?\d{4}\s?\d{4}').hasMatch(fullSms)) {
      final lower = fullSms.toLowerCase();
      if (!lower.contains('utr') &&
          !lower.contains('rrn') &&
          !lower.contains('ref') &&
          !lower.contains('txn')) {
        return false;
      }
    }
    return true;
  }

  /// Two-year pivot for `dd-MMM-yy` / `yy-MM-dd`: bank SMSs without a
  /// 4-digit year. Use the same convention as `compensation_calculator`
  /// (assumes the pivot is 2000-2099 → 20YY) — accurate for at least the
  /// next 70+ years of refund SMS.
  static int _pivotTwoDigitYear(int yy) => (yy < 100) ? (2000 + yy) : yy;

  static DateTime? _tryParseFlexible(String raw) {
    // Try the explicit fixed formats first (`yyyy-MM-dd` etc).
    for (final fmt in ['dd-MM-yyyy', 'dd/MM/yyyy', 'yyyy-MM-dd']) {
      try {
        final parts = raw.split(RegExp('[-/]'));
        if (parts.length == 3) {
          if (fmt == 'dd-MM-yyyy' || fmt == 'dd/MM/yyyy') {
            // Bank SMSs frequently send 2-digit years (05/06/25). Pivot
            // them to 20YY; the regex already constrained us to digits,
            // so we don't need to validate further.
            var year = int.parse(parts[2]);
            if (year < 100) year = _pivotTwoDigitYear(year);
            return DateTime(year, int.parse(parts[1]), int.parse(parts[0]));
          }
          if (fmt == 'yyyy-MM-dd') {
            return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
          }
        }
      } catch (_) {}
    }
    // The bug (m6): `dd-MMM-yy` was reached but `int.parse('Jan')` threw
    // inside the loop above and was swallowed — the function silently
    // returned null even though the regex had matched `10-Jan-25`. Handle
    // it explicitly via month-name lookup instead.
    final monthByName = <String, int>{
      'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
      'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
    };
    try {
      final parts = raw.split('-');
      if (parts.length == 3) {
        final day = int.parse(parts[0]);
        final monthStr = parts[1].toLowerCase();
        final month = monthByName[monthStr];
        // Accept 1-2 digit day and 2-4 digit year (e.g. `1-Jan-25` and
        // `10-Jan-2026`), not just the old strict `2 && 2`.
        if (month != null && parts[0].isNotEmpty && parts[0].length <= 2 &&
            (parts[2].length == 2 || parts[2].length == 4)) {
          final yr = _pivotTwoDigitYear(int.parse(parts[2]));
          return DateTime(yr, month, day);
        }
      }
    } catch (_) {}
    return null;
  }
}
