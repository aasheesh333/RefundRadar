import 'package:flutter/material.dart';
import 'app_tokens.dart';

/// Brightness-aware color resolution so feature screens stop hardcoding
/// `AppColors.*Light` (which made Dark mode in Settings a no-op).
class AppThemeColors {
  AppThemeColors._(this.isDark);
  final bool isDark;

  static AppThemeColors of(BuildContext context) =>
      AppThemeColors._(Theme.of(context).brightness == Brightness.dark);

  @visibleForTesting
  factory AppThemeColors.forTest({required bool isDark}) =>
      AppThemeColors._(isDark);

  Color get bg => isDark ? AppColors.bgDark : AppColors.bgLight;
  Color get surface => isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
  Color get surfaceAlt =>
      isDark ? AppColors.surfaceAltDark : AppColors.surfaceAltLight;
  Color get divider => isDark ? AppColors.dividerDark : AppColors.dividerLight;
  Color get textPrimary =>
      isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
  Color get textSecondary =>
      isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
  Color get textTertiary =>
      isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight;

  // Soft status surfaces need dark variants so pastel chips don't glow.
  Color get accentSoft =>
      isDark ? const Color(0xFF17263F) : AppColors.accentSoft;
  Color get alertSoft =>
      isDark ? const Color(0xFF3A2411) : AppColors.alertSoft;
  Color get errorSoft =>
      isDark ? const Color(0xFF3A1717) : AppColors.errorSoft;
  Color get premiumGoldSoft =>
      isDark ? const Color(0xFF352B12) : AppColors.premiumGoldSoft;

  /// Primary action fill: accent in dark (matches filledButtonTheme), primary in light.
  Color get ctaBackground => isDark ? AppColors.accent : AppColors.primary;

  /// Foreground on [ctaBackground].
  Color get ctaForeground =>
      isDark ? const Color(0xFF0E1116) : const Color(0xFFFFFFFF);
}
