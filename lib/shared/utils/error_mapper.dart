import 'package:flutter/foundation.dart';

/// Map raw Firebase / network exceptions to short, user-facing copy.
/// Never dump `[cloud_firestore/permission-denied] ...` into the UI.
///
/// Shared across all pages that render [BrandedErrorBanner] so the error
/// UX is consistent — Home, Dispute Detail, History, Reminders, Escalate,
/// Ombudsman, etc.
String friendlyError(Object e) {
  final s = e.toString().toLowerCase();
  if (s.contains('permission-denied') || s.contains('permission_denied')) {
    return 'Could not load your data. Tap Retry. If this keeps happening, sign out from Settings and reopen the app.';
  }
  if (s.contains('unavailable') ||
      s.contains('network') ||
      s.contains('socket')) {
    return 'You appear to be offline. Check your connection and retry.';
  }
  if (s.contains('unauthenticated')) {
    return 'Session expired. Tap Retry to sign in again.';
  }
  if (s.contains('operation-not-allowed') ||
      s.contains('admin-restricted-operation')) {
    return 'Anonymous sign-in is not enabled. Open Firebase Console → Authentication → Anonymous → Enable, then reopen the app.';
  }
  if (s.contains('not-found') || s.contains('not_found')) {
    return 'This item could not be found. It may have been deleted.';
  }
  if (s.contains('deadline-exceeded') || s.contains('timeout')) {
    return 'The request timed out. Check your connection and retry.';
  }
  return 'Something went wrong. Tap Retry.';
}

/// Short technical code surfaced in the banner's detail row so the exact
/// failing layer (auth vs rules vs network) is visible without debugging.
/// Kept terse on purpose — [friendlyError] is the user-facing copy; this
/// just lets us confirm the root cause at a glance.
String? errorDetail(Object e) {
  if (kDebugMode) return e.toString();
  final s = e.toString();
  final m = RegExp(r'\[([\w/-]+/[a-z-]+)\]').firstMatch(s);
  if (m != null) return m.group(1);
  final am = RegExp(r'\b(auth/[a-z-]+)\b').firstMatch(s);
  if (am != null) return am.group(1);
  return s.length > 80 ? '${s.substring(0, 80)}…' : s;
}
