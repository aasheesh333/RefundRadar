import 'package:refund_radar/data/models/dispute.dart';
import 'package:refund_radar/shared/utils/date_time_ext.dart';
import 'package:refund_radar/shared/utils/indian_number_formatter.dart';

class CompensationResult {
  final int daysElapsed;
  final double compensationDue;
  final DateTime deadlineDate;
  final bool isExpired;
  final bool shouldEscalate;

  const CompensationResult({
    required this.daysElapsed,
    required this.compensationDue,
    required this.deadlineDate,
    required this.isExpired,
    required this.shouldEscalate,
  });
}

class CompensationCalculator {
  static const int _displayCapDays = 90;

  static CompensationResult compute(Dispute dispute, {DateTime? now}) {
    final today = (now ?? DateTime.now());
    if (dispute.type.tatDays == null || dispute.type.compensationPerDay == null) {
      // No compensation for fastag/bank_charge/wrong_transfer as per spec
      return CompensationResult(
        daysElapsed: 0,
        compensationDue: 0,
        deadlineDate: dispute.txnDate,
        isExpired: false,
        shouldEscalate: false,
      );
    }
    final deadline = dispute.txnDate.add(Duration(days: dispute.type.tatDays!));
    // ME-2: use calendar-day math so a wall-clock `now` taken at 23:59 vs a
    // midnight-aligned deadline doesn't under-report by a day.
    final elapsed = today.differenceInDays(deadline);
    final days = elapsed < 0 ? 0 : (elapsed > _displayCapDays ? _displayCapDays : elapsed);
    final comp = days * dispute.type.compensationPerDay!;
    return CompensationResult(
      daysElapsed: days,
      compensationDue: comp.toDouble(),
      deadlineDate: deadline,
      isExpired: today.isAfter(deadline),
      shouldEscalate: days >= 30,
    );
  }

  static int daysUntilChargebackExpiry(Dispute dispute, {DateTime? now}) {
    final today = (now ?? DateTime.now());
    const window = 45;
    // ME-2: calendar-day math; deadline is midnight-aligned.
    return dispute.txnDate.add(const Duration(days: window)).differenceInDays(today);
  }

  static int daysUntilFastagExpiry(Dispute dispute, {DateTime? now}) {
    final today = (now ?? DateTime.now());
    // ME-2: calendar-day math.
    return dispute.txnDate.add(const Duration(days: 30)).differenceInDays(today);
  }

  static String formatIndian(double amount) {
    // LO-1: delegate to the single Indian grouping implementation so the
    // three local copies (home_page, owed_counter_card, here) can be removed
    // without behaviour drift.
    return '₹${IndianNumberFormatter.format(amount)}';
  }
}
