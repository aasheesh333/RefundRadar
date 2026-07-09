/// Fallback bank list for the dispute form picker when rules engine fails.
/// Same set used on the success path for non-FASTag disputes.
const List<({String name, String id})> kFallbackBanks = [
  (name: 'HDFC Bank', id: 'hdfc'),
  (name: 'ICICI Bank', id: 'icici'),
  (name: 'Axis Bank', id: 'axis'),
  (name: 'SBI', id: 'sbi'),
  (name: 'Other bank', id: 'other'),
];
