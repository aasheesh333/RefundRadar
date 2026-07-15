/// Date-time helpers that operate on calendar days, avoiding the
/// off-by-one issues that come from raw [Duration.inDays] on wall-clock
/// [DateTime] values.
extension DateTimeX on DateTime {
  /// This date at midnight (00:00:00.000).
  DateTime get dateOnly => DateTime(year, month, day);

  /// Whole calendar-day difference between two dates (this - other).
  int differenceInDays(DateTime other) {
    return dateOnly.difference(other.dateOnly).inDays;
  }
}
