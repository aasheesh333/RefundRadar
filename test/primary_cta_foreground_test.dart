import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Regression: primary FilledButtons must use theme-aware ctaBackground /
/// ctaForeground (AppThemeColors.of(context)) instead of hardcoded
/// AppColors.primary + Colors.white, so dark mode honours the accent palette.
void main() {
  group('primary FilledButton overrides are theme-aware (ctaBackground)', () {
    // Legacy: FilledButtons used to hardcode backgroundColor: AppColors.primary
    // + foregroundColor: Colors.white, which broke dark mode (purple-on-purple).
    // Migration rule: use AppThemeColors.of(context).ctaBackground/.ctaForeground
    // so the default theme filledButtonTheme (accent in dark) is respected.
    final primaryCtaFiles = [
      'lib/features/dispute_create/dispute_type_page.dart',
      'lib/features/onboarding/onboarding_page.dart',
      'lib/features/wizard/wizard_page.dart',
      'lib/features/reminders/reminders_page.dart',
      'lib/features/sms_permission/sms_permission_page.dart',
      'lib/features/add_banks/add_banks_page.dart',
    ];

    for (final path in primaryCtaFiles) {
      test('$path uses ctaBackground / ctaForeground (no AppColors.primary '
          'backgroundColor)', () {
        final source = File(path).readAsStringSync();
        final styleBlocks = _extractFilledButtonStyleFromBlocks(source);
        expect(
          styleBlocks,
          isNotEmpty,
          reason: '$path has no FilledButton.styleFrom',
        );
        for (final block in styleBlocks) {
          if (!block.contains('backgroundColor:')) continue;
          expect(
            block.contains('backgroundColor: AppColors.primary'),
            isFalse,
            reason: '$path still hardcodes backgroundColor: AppColors.primary '
                '— migrate to tc.ctaBackground. Block:\n$block',
          );
          expect(
            block.contains('ctaBackground'),
            isTrue,
            reason: '$path FilledButton backgroundColor override should use '
                'ctaBackground, got: $block',
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

/// Extracts the argument-list text of every `FilledButton.styleFrom(...)`
/// call in [source], honouring nested parentheses (e.g. method chains like
/// `AppThemeColors.of(context).ctaBackground`) so a naive non-greedy regex
/// does not truncate at the first `)`.
List<String> _extractFilledButtonStyleFromBlocks(String source) {
  final marker = 'FilledButton.styleFrom(';
  final blocks = <String>[];
  var i = 0;
  while (true) {
    final start = source.indexOf(marker, i);
    if (start < 0) break;
    final argStart = start + marker.length;
    var depth = 1;
    var j = argStart;
    while (j < source.length && depth > 0) {
      final ch = source[j];
      if (ch == '(') {
        depth++;
      } else if (ch == ')') {
        depth--;
        if (depth == 0) break;
      }
      j++;
    }
    blocks.add(source.substring(argStart, j));
    i = j + 1;
  }
  return blocks;
}
