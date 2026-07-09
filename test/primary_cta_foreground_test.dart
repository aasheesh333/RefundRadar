import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Regression: FilledButtons that override backgroundColor to AppColors.primary
/// must also set foregroundColor: Colors.white (and disabled colors if present).
void main() {
  final primaryCtaFiles = [
    'lib/features/dispute_create/dispute_type_page.dart',
    'lib/features/onboarding/onboarding_page.dart',
    'lib/features/wizard/wizard_page.dart',
    'lib/features/reminders/reminders_page.dart',
  ];

  group('primary FilledButton overrides', () {
    for (final path in primaryCtaFiles) {
      test('$path sets foregroundColor white with primary background', () {
        final source = File(path).readAsStringSync();
        expect(
          source.contains('backgroundColor: AppColors.primary'),
          isTrue,
          reason: '$path should still override primary background',
        );
        // Every primary background override block must include white foreground.
        final styleBlocks = RegExp(
          r'FilledButton\.styleFrom\(([\s\S]*?)\),',
        ).allMatches(source);
        final primaryBlocks = styleBlocks
            .map((m) => m.group(1)!)
            .where((b) => b.contains('backgroundColor: AppColors.primary'))
            .toList();
        expect(primaryBlocks, isNotEmpty, reason: '$path has no primary styleFrom');
        for (final block in primaryBlocks) {
          expect(
            block.contains('foregroundColor: Colors.white'),
            isTrue,
            reason: '$path primary styleFrom missing foregroundColor: Colors.white',
          );
        }
      });
    }
  });

  group('ombudsman disclaimer', () {
    test('uses theme textTertiary not Colors.grey', () {
      final source =
          File('lib/features/ombudsman/ombudsman_letter_page.dart').readAsStringSync();
      expect(source.contains('Colors.grey'), isFalse);
      expect(source.contains('AppThemeColors.of(context).textTertiary'), isTrue);
    });
  });
}
