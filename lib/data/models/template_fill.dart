import 'package:refund_radar/data/models/dispute.dart';
import 'package:refund_radar/data/models/template.dart';
import 'package:refund_radar/services/compensation_calculator.dart';
import 'package:refund_radar/shared/utils/date_time_ext.dart';

/// Builds placeholder maps for [Template.fill] from an optional [Dispute].
/// Covers every token used in `assets/templates/**/*.json` plus short aliases
/// used by the wizard (`AMOUNT`, `DATE`, `BANK`, …). Missing fields become
/// empty strings so users can spot blanks without leftover `{TOKEN}` for
/// known keys.
Map<String, String> fillValuesForDispute(Dispute? dispute) {
  if (dispute == null) {
    return _emptyAll();
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
    // User (not collected yet → blank)
    'USER_NAME': '',
    'MOBILE_NO': '',
    'EMAIL': '',
    'ADDRESS': '',
    'PLACE': '',
    'ACCOUNT_NO': '',
    // UPI
    'VPA': '',
    'VPA_PAYEE': '',
    // FASTag / toll
    'TAG_ID': dispute.entityId ?? '',
    'VEHICLE_NO': '',
    'PLAZA_NAME': '',
    'LANE_ID': '',
    'ISSUE_TYPE': desc.isNotEmpty ? desc : dispute.type.id,
    'CROSSINGS_USED': '',
    'PASS_ACTIVATION_DATE': '',
    'SECURITY_DEPOSIT': '',
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
  };
}

String filledBody(String body, Dispute? dispute) =>
    Template.fill(body, fillValuesForDispute(dispute));

String _fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

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
