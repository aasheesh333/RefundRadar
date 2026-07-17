/// UTC date serialization codec for Firestore-stored models.
///
/// All [DateTime] fields on Dispute / Reminder / ActivityLogEntry /
/// UtrDetection are stored as **UTC** ISO-8601 strings with a trailing
/// `Z` (e.g. `2026-01-15T09:00:00.000Z`) so the absolute instant survives
/// device timezone changes and cross-device reads. Reads convert back to
/// the device's local zone for display + compensation math.
///
/// **Legacy migration:** earlier builds wrote naive local ISO strings with
/// no offset (e.g. `2026-01-15T14:30:00.000`). [parseDate] handles both:
/// `DateTime.tryParse` returns a UTC [DateTime] for `Z`-suffixed strings
/// and a local [DateTime] for offset-less strings; `.toLocal()` is a no-op
/// on an already-local [DateTime], so legacy data reads identically to
/// before while new UTC data is portable.
library;

/// Serialise a [DateTime] to a portable UTC ISO-8601 string (`...Z`).
String toUtcIso(DateTime dt) => dt.toUtc().toIso8601String();

/// Parse an ISO-8601 string (UTC `Z`-suffixed OR legacy offset-less local)
/// into a local-zone [DateTime]. Returns `null` if [s] is null/empty/unparseable
/// — callers decide the fallback (now(), preserve null, etc.).
DateTime? parseDate(String? s) {
  if (s == null || s.isEmpty) return null;
  final dt = DateTime.tryParse(s);
  if (dt == null) return null;
  // toLocal() is a no-op on an already-local DateTime; converts UTC → local.
  return dt.toLocal();
}