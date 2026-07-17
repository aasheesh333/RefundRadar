/// Static catalog of Indian banks used by the Add-banks onboarding screen
/// and the dispute-form bank picker. These are user-facing display values;
/// the actual nodal-officer email routing is handled by `RulesEngine` and the
/// per-bank escalation targets in rules_engine.json.
///
/// Covers all Public Sector Banks (12), Private Sector Banks (21), Small
/// Finance Banks (12), Payments Banks (4), key Foreign Banks (5), plus
/// 'other' — 55 entries total, sourced from RBI scheduled-bank registry
/// (https://en.wikipedia.org/wiki/List_of_banks_in_India, July 2026).
/// Regional Rural Banks and Co-operative banks are excluded (state-level,
/// not relevant for consumer refund disputes).

library;

class BankCatalog {
  BankCatalog._();

  /// Curated set of Indian banks shown in the Add-banks picker / dispute form.
  /// `id` matches known nodal-email keys in _nodalEmails where available.
  static const List<BankEntry> banks = [
    BankEntry(id: 'sbi', name: 'State Bank of India', short: 'SBI'),
    BankEntry(id: 'pnb', name: 'Punjab National Bank', short: 'PNB'),
    BankEntry(id: 'bob', name: 'Bank of Baroda', short: 'BoB'),
    BankEntry(id: 'canara', name: 'Canara Bank', short: 'Canara'),
    BankEntry(id: 'unionbank', name: 'Union Bank of India', short: 'Union'),
    BankEntry(id: 'boi', name: 'Bank of India', short: 'BoI'),
    BankEntry(id: 'indianbank', name: 'Indian Bank', short: 'Indian'),
    BankEntry(id: 'maha', name: 'Bank of Maharashtra', short: 'Maharashtra'),
    BankEntry(id: 'centralbank', name: 'Central Bank of India', short: 'Central'),
    BankEntry(id: 'iob', name: 'Indian Overseas Bank', short: 'IOB'),
    BankEntry(id: 'uco', name: 'UCO Bank', short: 'UCO'),
    BankEntry(id: 'psb', name: 'Punjab & Sind Bank', short: 'P&S'),
    BankEntry(id: 'hdfc', name: 'HDFC Bank', short: 'HDFC'),
    BankEntry(id: 'icici', name: 'ICICI Bank', short: 'ICICI'),
    BankEntry(id: 'axis', name: 'Axis Bank', short: 'Axis'),
    BankEntry(id: 'kotak', name: 'Kotak Mahindra Bank', short: 'Kotak'),
    BankEntry(id: 'yes', name: 'Yes Bank', short: 'Yes'),
    BankEntry(id: 'idbi', name: 'IDBI Bank', short: 'IDBI'),
    BankEntry(id: 'idfc', name: 'IDFC First Bank', short: 'IDFC'),
    BankEntry(id: 'indus', name: 'IndusInd Bank', short: 'IndusInd'),
    BankEntry(id: 'federal', name: 'Federal Bank', short: 'Federal'),
    BankEntry(id: 'rbl', name: 'RBL Bank', short: 'RBL'),
    BankEntry(id: 'bandhan', name: 'Bandhan Bank', short: 'Bandhan'),
    BankEntry(id: 'sib', name: 'South Indian Bank', short: 'SIB'),
    BankEntry(id: 'kbl', name: 'Karnataka Bank', short: 'KarBank'),
    BankEntry(id: 'kvb', name: 'Karur Vysya Bank', short: 'KVB'),
    BankEntry(id: 'cub', name: 'City Union Bank', short: 'CUB'),
    BankEntry(id: 'dcb', name: 'DCB Bank', short: 'DCB'),
    BankEntry(id: 'tmb', name: 'Tamilnad Mercantile Bank', short: 'TMB'),
    BankEntry(id: 'dbl', name: 'Dhanlaxmi Bank', short: 'Dhanlaxmi'),
    BankEntry(id: 'csb', name: 'CSB Bank', short: 'CSB'),
    BankEntry(id: 'ntb', name: 'Nainital Bank', short: 'Nainital'),
    BankEntry(id: 'jk', name: 'Jammu & Kashmir Bank', short: 'J&K'),
    BankEntry(id: 'au', name: 'AU Small Finance Bank', short: 'AU'),
    BankEntry(id: 'equitas', name: 'Equitas Small Finance Bank', short: 'Equitas'),
    BankEntry(id: 'ujjivan', name: 'Ujjivan Small Finance Bank', short: 'Ujjivan'),
    BankEntry(id: 'utkarsh', name: 'Utkarsh Small Finance Bank', short: 'Utkarsh'),
    BankEntry(id: 'jana', name: 'Jana Small Finance Bank', short: 'Jana'),
    BankEntry(id: 'suryoday', name: 'Suryoday Small Finance Bank', short: 'Suryoday'),
    BankEntry(id: 'fino', name: 'Fino Small Finance Bank', short: 'Fino'),
    BankEntry(id: 'esaf', name: 'ESAF Small Finance Bank', short: 'ESAF'),
    BankEntry(id: 'capital', name: 'Capital Small Finance Bank', short: 'Capital'),
    BankEntry(id: 'shivalik', name: 'Shivalik Small Finance Bank', short: 'Shivalik'),
    BankEntry(id: 'unity', name: 'Unity Small Finance Bank', short: 'Unity'),
    BankEntry(id: 'slice', name: 'Slice Small Finance Bank', short: 'Slice'),
    BankEntry(id: 'airtel', name: 'Airtel Payments Bank', short: 'AirtelPB'),
    BankEntry(id: 'indiapost', name: 'India Post Payments Bank', short: 'IndiaPostPB'),
    BankEntry(id: 'jio', name: 'Jio Payments Bank', short: 'JioPB'),
    BankEntry(id: 'nsdl', name: 'NSDL Payments Bank', short: 'NSDLPB'),
    BankEntry(id: 'dbs', name: 'DBS Bank', short: 'DBS'),
    BankEntry(id: 'hsbc', name: 'HSBC', short: 'HSBC'),
    BankEntry(id: 'stanchart', name: 'Standard Chartered Bank', short: 'StanChart'),
    // Citibank India consumer business was acquired by Axis Bank (2024) and
    // is no longer a consumer-banking option — removed to avoid surfacing a
    // dead contact path in the dispute flow. (Citi customers are routed to
    // Axis Bank or 'Other bank' for new complaints.)
    BankEntry(id: 'barclays', name: 'Barclays Bank', short: 'Barclays'),
    BankEntry(id: 'other', name: 'Other bank', short: 'Other'),
  ];

  /// Banks with known nodal-officer / dispute email addresses (subset of `banks`).
  /// Used by the Add-banks tile subtitle. Returns null if we don't have it; the
  /// escalation flow falls back to RulesEngine.escalationTargets or generic text.
  static String? nodalEmailFor(String id) => _nodalEmails[id];

  static const Map<String, String> _nodalEmails = {
    'sbi': 'nodal.officer@sbi.co.in',
    'pnb': 'nodal.officer@pnb.co.in',
    'bob': 'nodal.bank@bankofbaroda.com',
    'canara': 'nodal.canara@canarabank.com',
    'unionbank': 'nodal.officer@unionbankofindia.bank',
    'boi': 'nodal.officer@bankofindia.co.in',
    'indianbank': 'nodal.officer@indianbank.in',
    'maha': 'nodal.officer@mahabank.co.in',
    'centralbank': 'nodal.officer@centralbankofindia.co.in',
    'iob': 'nodal.officer@iob.in',
    'uco': 'nodal.officer@ucobank.co.in',
    'psb': 'nodal.officer@psb.co.in',
    'hdfc': 'nodal.officer@hdfcbank.net',
    'icici': 'nodal@icicibank.com',
    'axis': 'Nodalofficer@axisbank.com',
    'kotak': 'nodal.banking@kotak.com',
    'yes': 'nodal.officer@yesbank.in',
    'idbi': 'nodal.officer@idbi.co.in',
    'idfc': 'nodal.banking@idfcfirstbank.com',
    'indus': 'nodal.officer@indusind.com',
    'federal': 'nodalfederal@federalbank.co.in',
    'rbl': 'nodal.officer@rblbank.com',
    'bandhan': 'banking.nodal@bandhanbank.com',
    'sib': 'nodal.officer@sib.co.in',
    'kvb': 'nodal.officer@kvb.co.in',
    'cub': 'nodal.officer@cityunionbank.com',
    'tmb': 'nodal.officer@tmb.in',
    'jk': 'nodal.officer@jkbmail.jkbank.com',
    'au': 'nodal.officer@aubank.in',
    'airtel': 'nodalofficer@airtelpaymentsbank.com',
  };
}

class BankEntry {
  final String id;
  final String name;
  final String short;
  const BankEntry({required this.id, required this.name, required this.short});
}

