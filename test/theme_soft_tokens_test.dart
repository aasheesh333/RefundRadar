import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:refund_radar/core/theme/app_theme_colors.dart';
import 'package:refund_radar/core/theme/app_tokens.dart';
import 'package:refund_radar/core/theme/status_kind_theme.dart';
import 'package:refund_radar/data/extensions/dispute_type_display.dart';
import 'package:refund_radar/data/models/dispute.dart';

void main() {
  group('StatusKind.bgFor', () {
    test('dark softs are not light pastels', () {
      final dark = AppThemeColors.forTest(isDark: true);
      expect(StatusKind.success.bgFor(dark), isNot(const Color(0xFFD7F5E7)));
      expect(StatusKind.warn.bgFor(dark), isNot(AppColors.alertSoft));
      expect(StatusKind.danger.bgFor(dark), isNot(AppColors.errorSoft));
      expect(StatusKind.info.bgFor(dark), isNot(AppColors.accentSoft));
      expect(StatusKind.premium.bgFor(dark), isNot(AppColors.premiumGoldSoft));
    });

    test('light softs match AppColors pastels', () {
      final light = AppThemeColors.forTest(isDark: false);
      expect(StatusKind.info.bgFor(light), AppColors.accentSoft);
      expect(StatusKind.warn.bgFor(light), AppColors.alertSoft);
    });
  });

  group('DisputeType.softColorFor', () {
    test('dark uses theme softs', () {
      final dark = AppThemeColors.forTest(isDark: true);
      expect(DisputeType.upiP2p.softColorFor(dark), dark.accentSoft);
      expect(DisputeType.bankCharge.softColorFor(dark), dark.surfaceAlt);
    });

    test('light maps match legacy softColor intent', () {
      final light = AppThemeColors.forTest(isDark: false);
      expect(DisputeType.upiP2p.softColorFor(light), light.accentSoft);
      expect(DisputeType.upiP2m.softColorFor(light), light.accentSoft);
      expect(DisputeType.atm.softColorFor(light), light.premiumGoldSoft);
      expect(DisputeType.fastag.softColorFor(light), light.alertSoft);
      expect(DisputeType.imps.softColorFor(light), light.errorSoft);
      expect(DisputeType.bankCharge.softColorFor(light), light.surfaceAlt);
      expect(DisputeType.wrongTransfer.softColorFor(light), light.surfaceAlt);
    });
  });
}
