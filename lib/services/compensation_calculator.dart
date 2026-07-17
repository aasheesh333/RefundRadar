import 'package:refund_radar/data/models/dispute.dart';
import 'package:refund_radar/shared/utils/date_time_ext.dart';
import 'package:refund_radar/shared/utils/indian_number_formatter.dart';
import 'package:refund_radar/shared/utils/working_day_calendar.dart';

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

  /// Compensation for a delayed refund per RBI Circular DPSS/2018:
  ///   - The TAT deadline (T+1 / T+5) is counted in **working days**
  ///     (excludes Sundays, 2nd/4th Saturdays, declared holidays — see
  ///     [WorkingDayCalendar]). This matches the RBI working-day TAT.
  ///   - The ₹100/day penalty accrues per **calendar day** of delay beyond
  ///     that deadline (RBI: "₹100 per day of delay"), capped at 90 days.
  ///   - FASTag / bank_charge / wrong_transfer have no per-day comp
  ///     (tatDays == null) and return ₹0 — they rely on dispute windows
  ///     (FASTag 30-day) and escalation, not the TAT penalty framework.
  ///
  /// ATM uses ₹100/day per the user's decision (consistent with the other
  /// types; RBI's ATM-specific ₹1000/day reading was rejected for v1 to
  /// keep the messaging uniform across dispute types).
  ///
  /// [holidays] overrides the cached holiday set (used by tests); in
  /// production the boot loader seeds [WorkingDayCalendar.holidays] from
  /// the rules engine so every call site shares one calendar.
  static CompensationResult compute(
    Dispute dispute, {
    DateTime? now,
    Set<DateTime>? holidays,
  }) {
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
    // RBI working-day TAT: the deadline is tatDays working days after the
    // transaction. T+1 from Friday → Monday (skips Sat 2nd/4th + Sun +
    // any declared holiday).
    final deadline = WorkingDayCalendar.addWorkingDays(
      dispute.txnDate,
      dispute.type.tatDays!,
      holidays: holidays,
    );
    // ME-2: penalty per calendar day of delay (midnight-aligned) so a
    // wall-clock `now` at 23:59 vs a midnight-aligned deadline doesn't
    // under-report by a day.
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
    // Chargeback window is a calendar-day window (not a working-day TAT),
    // so this stays calendar-day math.
    return dispute.txnDate.add(const Duration(days: window)).differenceInDays(today);
  }

  static int daysUntilFastagExpiry(Dispute dispute, {DateTime? now}) {
    final today = (now ?? DateTime.now());
    // FASTag 30-day dispute window — calendar days (not a TAT).
    return dispute.txnDate.add(const Duration(days: 30)).differenceInDays(today);
  }

  static String formatIndian(double amount) {
    // LO-1: delegate to the single Indian grouping implementation so the
    // three local copies (home_page, owed_counter_card, here) can be removed
    // without behaviour drift.
    return '₹${IndianNumberFormatter.format(amount)}';
  }
}
