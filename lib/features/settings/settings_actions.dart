// Pure helpers for Settings destructive actions (testable without Firebase UI).

/// Runs full user-data wipe: disputes/user doc first, then reminders + local
/// notifications. Callers supply the repository operations so UI can inject
/// providers / fakes.
Future<void> executeDeleteAllUserData({
  required String uid,
  required Future<void> Function(String uid) deleteAllUserData,
  required Future<void> Function(String uid) deleteAllRemindersAndNotifications,
}) async {
  await deleteAllUserData(uid);
  await deleteAllRemindersAndNotifications(uid);
}

/// True: [reauthProvider] signs out then mints a new anonymous uid, so
/// cloud data under the previous uid becomes unreachable to this device.
const bool signOutCreatesUnreachableData = true;

/// Confirm dialog body before calling reauth (honest about orphaned data).
const String kSignOutWarningBody =
    'Sign out mints a new anonymous account. Data under your current session '
    'becomes unreachable on this device unless you delete it first.';

/// SnackBar after reauth — not a false "session refreshed" success.
const String kSignOutCompletedBody =
    'Signed out. You are on a new anonymous session.';

/// Success after delete-all.
const String kDeleteDataSuccessBody = 'All your data was deleted.';
