import 'package:flutter_test/flutter_test.dart';
import 'package:refund_radar/data/models/reminder.dart';
import 'package:refund_radar/data/repositories/reminder_repository.dart';

void main() {
  group('allReminderIdsForDispute (helper used by syncRemindersForDispute + deleteRemindersForDispute)', () {
    test('returns one id per ReminderStage, namespaced by disputeId', () {
      final ids = allReminderIdsForDispute('d42');
      expect(ids, hasLength(ReminderStage.values.length));
      expect(ids, containsAll(<String>[
        'd42_l1_followup',
        'd42_l2_escalate',
        'd42_ombudsman',
        'd42_ombudsman_followup',
      ]));
    });

    test('different disputeIds produce non-overlapping id sets', () {
      final a = allReminderIdsForDispute('alpha').toSet();
      final b = allReminderIdsForDispute('beta').toSet();
      expect(a.intersection(b), isEmpty,
          reason: 'Distinct disputes must not share any reminder ids');
    });

    test('same disputeId is deterministic across calls', () {
      expect(allReminderIdsForDispute('d1'), allReminderIdsForDispute('d1'));
    });

    test('every id maps to a unique NotificationService scheduledIdFor value', () {
      // Regression: the old code derived the id from disputeId only, so all
      // reminders for one dispute collided. With per-reminder ids, every
      // id in the all-possible set must hash to a distinct int. Reproduce
      // the production mask inline so the test doesn't have to import the
      // service (which would pull timezone / plugin shells in unit tests).
      int scheduledIdFor(String r) => r.hashCode & 0x7FFFFFFF;
      final ids = allReminderIdsForDispute('collision-prone');
      final scheduledIds = ids.map(scheduledIdFor).toSet();
      expect(scheduledIds.length, equals(ids.length),
          reason:
              'All per-stage reminder ids for one dispute must produce distinct'
              ' local-notification ids — collision breaks scheduling.');
    });
  });
}
