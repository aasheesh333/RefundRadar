/// Static catalog of Indian banks used by the Add-banks onboarding screen
/// and the dispute-form bank picker. These are user-facing display values;
/// the actual nodal-officer email routing is handled by `RulesEngine` and the
/// per-bank escalation targets in rules_engine.json.
///
/// Keeping the list here avoids duplicating literal bank names across pages
/// the same way Lists.fastagIssuers does for FASTag issuers.

library;

class BankCatalog {
  BankCatalog._();

  /// Minimal curated set of major Indian banks shown in the Add-banks picker.
  /// `code` matches the FASTag issuer `id` in rules_engine.json where applicable.
  static const List<BankEntry> banks = [
    BankEntry(id: 'hdfc', name: 'HDFC Bank', short: 'HDFC'),
    BankEntry(id: 'icici', name: 'ICICI Bank', short: 'ICICI'),
    BankEntry(id: 'axis', name: 'Axis Bank', short: 'Axis'),
    BankEntry(id: 'sbi', name: 'State Bank of India', short: 'SBI'),
    BankEntry(id: 'kotak', name: 'Kotak Mahindra Bank', short: 'Kotak'),
    BankEntry(id: 'yes', name: 'Yes Bank', short: 'Yes'),
    BankEntry(id: 'idfc', name: 'IDFC First Bank', short: 'IDFC'),
    BankEntry(id: 'pnb', name: 'Punjab National Bank', short: 'PNB'),
    BankEntry(id: 'bob', name: 'Bank of Baroda', short: 'BoB'),
    BankEntry(id: 'canara', name: 'Canara Bank', short: 'Canara'),
    BankEntry(id: 'iob', name: 'Indian Overseas Bank', short: 'IOB'),
    BankEntry(id: 'au', name: 'AU Small Finance Bank', short: 'AU'),
    BankEntry(id: 'federal', name: 'Federal Bank', short: 'Federal'),
    BankEntry(id: 'indus', name: 'IndusInd Bank', short: 'IndusInd'),
    BankEntry(id: 'bandhan', name: 'Bandhan Bank', short: 'Bandhan'),
    BankEntry(id: 'rbl', name: 'RBL Bank', short: 'RBL'),
    BankEntry(id: 'other', name: 'Other bank', short: 'Other'),
  ];

  /// Banks with known nodal-officer / dispute email addresses (subset of `banks`).
  /// Used by the Add-banks tile subtitle. Returns null if we don't have it; the
  /// escalation flow falls back to RulesEngine.escalationTargets or generic text.
  static String? nodalEmailFor(String id) => _nodalEmails[id];

  static const Map<String, String> _nodalEmails = {
    'hdfc': 'nodal.officer@hdfcbank.net',
    'icici': 'nodal@icicibank.com',
    'axis': 'Nodalofficer@axisbank.com',
    'sbi': 'customercare@sbi.co.in',
    'kotak': 'nodal.banking@kotak.com',
    'yes': 'nodal.officer@yesbank.in',
    'idfc': 'nodal.banking@idfcfirstbank.com',
    'pnb': 'nodal.officer@pnb.co.in',
    'bob': 'nodal.bank@bankofbaroda.com',
    'canara': 'nodal.canara@canarabank.com',
    'iob': 'nodal.officer@iob.in',
    'au': 'nodal.officer@aubank.in',
    'federal': 'nodalfederal@federalbank.co.in',
    'indus': 'nodal.officer@indusind.com',
    'bandhan': 'banking.nodal@bandhanbank.com',
    'rbl': 'nodal.officer@rblbank.com',
  };
}

class BankEntry {
  final String id;
  final String name;
  final String short;
  const BankEntry({required this.id, required this.name, required this.short});
}
