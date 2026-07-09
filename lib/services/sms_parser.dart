class SmsParseResult {
  final String? utr;
  final double? amount;
  final DateTime? date;
  final String? vpa;
  SmsParseResult({this.utr, this.amount, this.date, this.vpa});
}

class SmsParser {
  static final _utrRegex = RegExp(r'\b(\d{12})\b');
  static final _amountRegex = RegExp(r'Rs\.?\s*([\d,]+\.?\d*)|₹\s*([\d,]+\.?\d*)');
  static final _dateRegex = RegExp(
      r'(\d{1,2}[-/](?:0?[1-9]|1[012])[-/]\d{2,4})|(\d{4}-\d{2}-\d{2})|(\d{2}[-][A-Za-z]{3}[-]\d{2})');
  static final _vpaRegex = RegExp(r'\b([\w.]+@[\w]+)\b');

  static SmsParseResult parse(String sms) {
    final effective = sms.replaceAll('\u00A0', ' '); // nbsp → space (some banks)
    String? utr;
    final utrMatch = _utrRegex.firstMatch(effective);
    if (utrMatch != null) utr = utrMatch.group(1);

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
    final vpaMatch = _vpaRegex.firstMatch(effective);
    if (vpaMatch != null) vpa = vpaMatch.group(1);

    return SmsParseResult(utr: utr, amount: amount, date: date, vpa: vpa);
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
        if (month != null && parts[0].length == 2 && parts[2].length == 2) {
          final yr = _pivotTwoDigitYear(int.parse(parts[2]));
          return DateTime(yr, month, day);
        }
      }
    } catch (_) {}
    return null;
  }
}
