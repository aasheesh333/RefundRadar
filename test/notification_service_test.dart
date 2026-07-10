import 'package:flutter_test/flutter_test.dart';
import 'package:refund_radar/services/notification_service.dart';

void main() {
  group('NotificationService id derivation', () {
    test('uses stable fixed ids for known reminder ids', () {
      expect(NotificationService.scheduledIdFor('d1_l1_followup'), 164003897);
      expect(NotificationService.scheduledIdFor('d1_l2_escalate'), 1824034838);
      expect(NotificationService.scheduledIdFor('d1_ombudsman'), 21033389);
      expect(
        NotificationService.scheduledIdFor('d1_ombudsman_followup'),
        876816214,
      );
    });

    test('different reminder ids for same dispute produce different ints', () {
      final idL1 = NotificationService.scheduledIdFor('d1_l1_followup');
      final idL2 = NotificationService.scheduledIdFor('d1_l2_escalate');
      final idOmb = NotificationService.scheduledIdFor('d1_ombudsman');
      final idDraft = NotificationService.scheduledIdFor('d1_ombudsman_followup');

      final ids = [idL1, idL2, idOmb, idDraft];
      expect(ids.toSet().length, equals(4));
    });

    test('same stage different dispute produces different int', () {
      final idA = NotificationService.scheduledIdFor('disputeA_l1_followup');
      final idB = NotificationService.scheduledIdFor('disputeB_l1_followup');
      expect(idA, isNot(equals(idB)));
    });

    test('id is masked to 31-bit positive int', () {
      const veryLongId =
          'this_is_a_very_long_dispute_id_that_will_produce_a_large_hash_code_and_could_overflow_if_not_masked_properly_l1_followup';
      final id = NotificationService.scheduledIdFor(veryLongId);
      expect(id, greaterThanOrEqualTo(0));
      expect(id, lessThanOrEqualTo(0x7FFFFFFF));
    });
  });

  group('NotificationService cancelForReminder', () {
    test('cancelForReminder derives same id as schedule for given reminderId', () {
      final reminderId = 'test_dispute_l1_followup';
      final scheduleId = NotificationService.scheduledIdFor(reminderId);
      final cancelId = NotificationService.cancelIdFor(reminderId);
      expect(scheduleId, 693035993);
      expect(cancelId, equals(scheduleId));
    });
  });
}
