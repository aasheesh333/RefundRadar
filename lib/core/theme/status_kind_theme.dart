import 'package:flutter/material.dart';

import 'app_theme_colors.dart';
import 'app_tokens.dart';

/// Brightness-aware StatusKind surfaces (lives here to avoid circular imports
/// between [app_tokens] and [app_theme_colors]).
extension StatusKindThemeX on StatusKind {
  Color bgFor(AppThemeColors tc) => switch (this) {
        StatusKind.neutral => tc.surfaceAlt,
        StatusKind.info => tc.accentSoft,
        StatusKind.warn => tc.alertSoft,
        StatusKind.danger => tc.errorSoft,
        StatusKind.success => tc.accentSoft,
        StatusKind.premium => tc.premiumGoldSoft,
      };

  Color fgFor(AppThemeColors tc) => switch (this) {
        StatusKind.neutral => tc.textSecondary,
        StatusKind.info => tc.isDark ? AppColors.accent : AppColors.primary,
        StatusKind.warn => AppColors.alert,
        StatusKind.danger => AppColors.error,
        StatusKind.success => AppColors.success,
        StatusKind.premium => AppColors.premiumGold,
      };
}
