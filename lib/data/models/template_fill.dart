import 'package:refund_radar/data/models/dispute.dart';
import 'package:refund_radar/data/models/template.dart';
import 'package:refund_radar/data/models/user_profile.dart';
import 'package:refund_radar/services/compensation_calculator.dart';
import 'package:refund_radar/shared/utils/date_time_ext.dart';

/// Builds placeholder maps for [Template.fill] from an optional [Dispute]
/// and [UserProfile]. Covers every token used in
/// `assets/templates/**/*.json` plus short aliases used by the wizard
/// (`AMOUNT`, `DATE`, `BANK`, …). Missing fields become empty strings so
/// users can spot blanks without leftover `{TOKEN}` for known keys.
Map<String, String> fillValuesForDispute(
  Dispute? dispute, {
  UserProfile? profile,
}) {
  final p = profile ?? UserProfile.empty;
  if (dispute == null) {
    final values = _emptyAll();
    _applyProfile(values, p);
    return values;
  }

  final amount = dispute.amount.toStringAsFixed(0);
  final entity = dispute.entityName ?? '';
  final txnId = dispute.txnId;
  final d = dispute.txnDate;
  final txnDate = _fmtDate(d);
  final txnDateTime =
      '${_fmtDate(d)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  final today = _fmtDate(DateTime.now());

  String ticket = '';
  for (final key in ['l1', 'l2', 'ombudsman', 'l3']) {
    final v = dispute.ticketNumbers[key];
    if (v != null && v.isNotEmpty) {
      ticket = v;
      break;
    }
  }

  final l1Filed = dispute.filedDates['l1'] ?? dispute.createdAt;
  final complaintDate = _fmtDate(l1Filed);
  final lastFollowup = dispute.filedDates['l2'] != null
      ? _fmtDate(dispute.filedDates['l2']!)
      : complaintDate;

  final comp = CompensationCalculator.compute(dispute);
  final compensationDue = comp.compensationDue.toStringAsFixed(0);
  // ME-2: calendar-day math so a template letter written near midnight
  // doesn't under-report the days elapsed since the transaction.
  final daysElapsed = DateTime.now().differenceInDays(dispute.txnDate);
  final daysElapsedStr = daysElapsed < 0 ? '0' : '$daysElapsed';

  final desc = dispute.description ?? '';

  // Keys must match asset placeholders exactly (case-sensitive).
  return {
    // Core txn
    'UTR': txnId,
    'TXN_ID': txnId,
    'TXN_ID_2': '',
    'AMOUNT': amount,
    'amount': amount,
    'AMOUNT_INR': amount,
    'TOTAL_AMOUNT': amount,
    'CORRECT_AMOUNT': amount,
    'TXN_DATE': txnDate,
    'DATE': txnDate,
    'TXN_DATETIME': txnDateTime,
    'TODAY_DATE': today,
    // Entity
    'BANK_NAME': entity,
    'BANK': entity,
    'ENTITY_NAME': entity,
    'ENTITY': entity,
    'ENTITY_ADDRESS': '',
    'ACQUIRER_BANK': entity,
    'BENEFICIARY_BANK': '',
    // Tickets / dates
    'TICKET_NO': ticket,
    'TICKET': ticket,
    'COMPLAINT_DATE': complaintDate,
    'LAST_FOLLOWUP_DATE': lastFollowup,
    // Compensation
    'COMPENSATION_DUE': compensationDue,
    'DAYS_ELAPSED': daysElapsedStr,
    // User (from one-time profile capture — editable in Settings /
    // dispute-create so the complaint email needs no manual editing)
    'USER_NAME': p.name,
    'MOBILE_NO': p.mobile,
    'EMAIL': p.email,
    'ADDRESS': p.address,
    'PLACE': p.place,
    'ACCOUNT_NO': p.accountNo,
    // UPI
    'VPA': dispute.vpa ?? '',
    'VPA_PAYEE': dispute.vpaPayee ?? '',
    // FASTag / toll
    'TAG_ID': dispute.entityId ?? '',
    'VEHICLE_NO': dispute.vehicleNo ?? '',
    'PLAZA_NAME': dispute.plazaName ?? '',
    'LANE_ID': '',
    'ISSUE_TYPE': desc.isNotEmpty ? desc : dispute.type.id,
    'CROSSINGS_USED': '',
    'PASS_ACTIVATION_DATE': '',
    'SECURITY_DEPOSIT': '',
    // ATM
    'ATM_ID': dispute.atmId ?? '',
    'CARD_LAST4': dispute.cardLast4 ?? '',
    // Wrong transfer beneficiary
    'BENEFICIARY_ACCOUNT_NO': dispute.beneficiaryAccountNo ?? '',
    'BENEFICIARY_IFSC': dispute.beneficiaryIfsc ?? '',
    // Legal / advanced blanks
    'OMBUDSMAN_REF': dispute.ticketNumbers['ombudsman'] ??
        dispute.ticketNumbers['l3'] ??
        '',
    'OMBUDSMAN_ORDER_DATE': '',
    'ADVOCATE_NAME': '',
    'PIO_OFFICE': '',
    'LOCAL_POLICE_STATION': '',
    'HARASSMENT_CLAIM': '',
    'HOURS_LOST': '',
    'HOUR_RATE': '',
    'OUT_OF_POCKET': '',
    'TIME_COST_AMOUNT': '',
    // Multi-transaction / advanced-only tokens (not collected on the
    // single-dispute model yet → blank so users fill them in by hand
    // rather than seeing a leftover {TOKEN}).
    'AMOUNT2': '',
    'AMOUNT3': '',
    'DATE_FINAL_LETTER': '',
    'DATE_RTI_REPLY': '',
    'NUM_TXNS': '',
    'VPA_LEGITIMATE': '',
    'VPA_PAYEE2': '',
    'VPA_PAYEE3': '',
  };
}

String filledBody(
  String body,
  Dispute? dispute, {
  UserProfile? profile,
}) =>
    Template.fill(body, fillValuesForDispute(dispute, profile: profile));

String _fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// Merges the one-time profile identity values into an otherwise-blank
/// token map (used for the no-dispute preview path).
void _applyProfile(Map<String, String> values, UserProfile p) {
  values['USER_NAME'] = p.name;
  values['MOBILE_NO'] = p.mobile;
  values['EMAIL'] = p.email;
  values['ADDRESS'] = p.address;
  values['PLACE'] = p.place;
  values['ACCOUNT_NO'] = p.accountNo;
}

Map<String, String> _emptyAll() {
  const keys = [
    'UTR',
    'TXN_ID',
    'TXN_ID_2',
    'AMOUNT',
    'amount',
    'AMOUNT_INR',
    'TOTAL_AMOUNT',
    'CORRECT_AMOUNT',
    'TXN_DATE',
    'DATE',
    'TXN_DATETIME',
    'TODAY_DATE',
    'BANK_NAME',
    'BANK',
    'ENTITY_NAME',
    'ENTITY',
    'ENTITY_ADDRESS',
    'ACQUIRER_BANK',
    'BENEFICIARY_BANK',
    'TICKET_NO',
    'TICKET',
    'COMPLAINT_DATE',
    'LAST_FOLLOWUP_DATE',
    'COMPENSATION_DUE',
    'DAYS_ELAPSED',
    'USER_NAME',
    'MOBILE_NO',
    'EMAIL',
    'ADDRESS',
    'PLACE',
    'ACCOUNT_NO',
    'VPA',
    'VPA_PAYEE',
    'TAG_ID',
    'VEHICLE_NO',
    'PLAZA_NAME',
    'LANE_ID',
    'ISSUE_TYPE',
    'CROSSINGS_USED',
    'PASS_ACTIVATION_DATE',
    'SECURITY_DEPOSIT',
    'ATM_ID',
    'CARD_LAST4',
    'BENEFICIARY_ACCOUNT_NO',
    'BENEFICIARY_IFSC',
    'OMBUDSMAN_REF',
    'OMBUDSMAN_ORDER_DATE',
    'ADVOCATE_NAME',
    'PIO_OFFICE',
    'LOCAL_POLICE_STATION',
    'HARASSMENT_CLAIM',
    'HOURS_LOST',
    'HOUR_RATE',
    'OUT_OF_POCKET',
    'TIME_COST_AMOUNT',
    'AMOUNT2',
    'AMOUNT3',
    'DATE_FINAL_LETTER',
    'DATE_RTI_REPLY',
    'NUM_TXNS',
    'VPA_LEGITIMATE',
    'VPA_PAYEE2',
    'VPA_PAYEE3',
  ];
  return {for (final k in keys) k: ''};
}

/// Initial wizard step index from dispute lifecycle (0=L1, 1=L2, 2=Ombudsman).
/// Shows the **next** action level after filings already recorded.
int wizardLevelFromDispute(Dispute d) {
  if (d.status == DisputeStatus.ombudsman ||
      d.filedDates['ombudsman'] != null ||
      d.filedDates['l3'] != null) {
    return 2;
  }
  if (d.status == DisputeStatus.filedL2 || d.filedDates['l2'] != null) {
    return 2; // next: Ombudsman
  }
  if (d.status == DisputeStatus.filedL1 || d.filedDates['l1'] != null) {
    return 1; // next: L2
  }
  return 0;
}
