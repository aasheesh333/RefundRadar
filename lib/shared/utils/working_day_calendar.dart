/// Indian banking working-day calendar (RBI TAT support).
///
/// RBI "T+1" / "T+5" TAT windows are counted in **working days**, not
/// calendar days. Indian banks are closed on:
///   - every Sunday
///   - the 2nd and 4th Saturday of each month (1st/3rd/5th are working)
///   - declared holidays (Republic Day, Independence Day, Gandhi Jayanti,
///     Christmas, and the movable festival list published in the RBI
///     holiday circular — kept in `rules_engine.json: holidays` so it can
///     be tuned via Remote Config without an app update)
///
/// `₹100/day` penalty compensation accrues per **calendar day** of delay
/// beyond the TAT deadline (RBI circular DPSS/2018), so only the
/// *deadline* is computed in working days; the elapsed-day count stays
/// calendar-day (see `CompensationCalculator`).
///
/// The holiday set is loaded once at boot (see `main.dart` →
/// `_bootBackgroundServices`) from the rules engine and cached here so
/// every synchronous `CompensationCalculator.compute` call site reads the
/// same calendar without threading the set through 7 widgets. Unit tests
/// pass an explicit `holidays` set (or rely on the empty default) so they
/// stay deterministic and don't depend on boot ordering.
library;

class WorkingDayCalendar {
  WorkingDayCalendar._();

  /// Date-only (midnight-normalised) holiday set. Mutated once at boot,
  /// read-only thereafter. Empty in unit tests (boot doesn't run).
  static Set<DateTime> _holidays = <DateTime>{};
  static Set<DateTime> get holidays => _holidays;

  /// Replace the cached holiday set. Called once at boot after the rules
  /// engine loads. Each input is normalised to midnight so containment
  /// checks against `dateOnly` datetimes match regardless of the time
  /// component the rules file carries.
  static void setHolidays(Iterable<DateTime> dates) {
    _holidays = dates.map(_dateOnly).toSet();
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// The 1-based occurrence of this Saturday in its month (1st..5th).
  /// Returns 0 for non-Saturdays.
  static int _saturdayOccurrence(DateTime d) {
    if (d.weekday != DateTime.saturday) return 0;
    return ((d.day - 1) ~/ 7) + 1;
  }

  /// True for a closed day under the Indian banking calendar:
  /// Sundays, 2nd/4th Saturdays, and declared holidays.
  static bool isHoliday(DateTime d, {Set<DateTime>? holidays}) {
    final hols = holidays ?? _holidays;
    if (d.weekday == DateTime.sunday) return true;
    if (d.weekday == DateTime.saturday) {
      final occ = _saturdayOccurrence(d);
      if (occ == 2 || occ == 4) return true;
    }
    return hols.contains(_dateOnly(d));
  }

  /// True for a working day (not [isHoliday]).
  static bool isWorkingDay(DateTime d, {Set<DateTime>? holidays}) =>
      !isHoliday(d, holidays: holidays);

  /// Add [n] working days to [start] (the deadline lands on a working
  /// day). T+1 from a Friday → Monday (skips Sat 2nd/4th + Sun + any
  /// holiday). Iterative to correctly skip variable-length weekend/holiday
  /// runs; bounded by [maxScan] to avoid an infinite loop on a hostile
  /// holiday set.
  static DateTime addWorkingDays(
    DateTime start,
    int n, {
    Set<DateTime>? holidays,
    int maxScan = 400,
  }) {
    var current = start;
    var added = 0;
    var scanned = 0;
    while (added < n && scanned < maxScan) {
      current = current.add(const Duration(days: 1));
      scanned++;
      if (isWorkingDay(current, holidays: holidays)) added++;
    }
    return current;
  }

  /// Calendar-day difference (today − deadline), matching the existing
  /// `differenceInDays` helper so the penalty per calendar day of delay
  /// is computed identically to before. Kept here for symmetry only —
  /// callers should prefer `DateTimeX.differenceInDays`.
  static int calendarDaysElapsed(DateTime deadline, DateTime today) =>
      _dateOnly(today).difference(_dateOnly(deadline)).inDays;
}