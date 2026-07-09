/// Pure auth guard for create-dispute / wizard mark-filed flows.
///
/// Callers must await `userIdProvider.future`, then check this before saving.
/// Invalid uid → show SnackBar (formAuthRequired) and return — never silent.
bool isValidAuthUid(String? uid) {
  if (uid == null) return false;
  return uid.trim().isNotEmpty;
}
