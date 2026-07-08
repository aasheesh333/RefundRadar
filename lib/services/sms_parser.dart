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
    String? utr;
    final utrMatch = _utrRegex.firstMatch(sms);
    if (utrMatch != null) utr = utrMatch.group(1);

    double? amount;
    final amtMatch = _amountRegex.firstMatch(sms);
    if (amtMatch != null) {
      final raw = (amtMatch.group(1) ?? amtMatch.group(2) ?? '')
          .replaceAll(',', '')
          .trim();
      amount = double.tryParse(raw);
    }

    DateTime? date;
    final dateMatch = _dateRegex.firstMatch(sms);
    if (dateMatch != null) {
      final raw = dateMatch.group(0) ?? '';
      date = DateTime.tryParse(raw) ?? _tryParseFlexible(raw);
    }

    String? vpa;
    final vpaMatch = _vpaRegex.firstMatch(sms);
    if (vpaMatch != null) vpa = vpaMatch.group(1);

    return SmsParseResult(utr: utr, amount: amount, date: date, vpa: vpa);
  }

  static DateTime? _tryParseFlexible(String raw) {
    for (final fmt in ['dd-MM-yyyy', 'dd/MM/yyyy', 'dd-MMM-yy', 'yyyy-MM-dd']) {
      try {
        final parts = raw.split(RegExp('[-/]'));
        if (parts.length == 3) {
          if (fmt == 'dd-MM-yyyy' || fmt == 'dd/MM/yyyy') {
            return DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
          }
        }
      } catch (_) {}
    }
    return null;
  }
}
