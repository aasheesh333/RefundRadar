import 'package:flutter_test/flutter_test.dart';
import 'package:refund_radar/features/settings/settings_actions.dart';

void main() {
  group('executeDeleteAllUserData', () {
    test('calls dispute wipe then reminders wipe in order', () async {
      final calls = <String>[];
      await executeDeleteAllUserData(
        uid: 'uid-1',
        deleteAllUserData: (uid) async {
          expect(uid, 'uid-1');
          calls.add('disputes');
        },
        deleteAllRemindersAndNotifications: (uid) async {
          expect(uid, 'uid-1');
          calls.add('reminders');
        },
      );
      expect(calls, ['disputes', 'reminders']);
    });

    test('rethrows when dispute wipe fails (reminders not called)', () async {
      final calls = <String>[];
      await expectLater(
        executeDeleteAllUserData(
          uid: 'uid-x',
          deleteAllUserData: (uid) async {
            calls.add('disputes');
            throw StateError('firestore down');
          },
          deleteAllRemindersAndNotifications: (uid) async {
            calls.add('reminders');
          },
        ),
        throwsStateError,
      );
      expect(calls, ['disputes']);
    });
  });

  group('sign-out honesty', () {
    test('warns that reauth mints a new anon uid and orphans cloud data', () {
      expect(signOutCreatesUnreachableData, isTrue);
      expect(kSignOutWarningBody, contains('unreachable'));
      expect(kSignOutWarningBody.toLowerCase(), contains('new'));
    });

    test('post-reauth snackbar is not a false "session refreshed" success', () {
      expect(kSignOutCompletedBody.toLowerCase(), isNot(contains('refreshed')));
      expect(kSignOutCompletedBody.toLowerCase(), contains('new'));
    });
  });
}
