import 'package:flutter/material.dart';

/// Refund Radar design tokens — Section 6.1 of the build spec.
/// Single source of truth for every visual decision in the app.
/// Vibe: trustworthy fintech + righteous consumer-rights energy.
///        Clean, spacious, serious but warm. NOT playful/cartoonish.
class AppColors {
  AppColors._();

  // Brand
  static const primary = Color(0xFF0B3D2E);     // deep trust green
  static const primaryDark = Color(0xFF072518);
  static const accent = Color(0xFF16C784);      // emerald — money green
  static const accentSoft = Color(0xFFD7F5E7); // emerald @ 12% perceptual

  // Status / counter
  static const alert = Color(0xFFF5A623);       // amber — counter
  static const alertSoft = Color(0xFFFCEFD3);
  static const error = Color(0xFFE5484D);
  static const errorSoft = Color(0xFFFCE4E5);
  static const success = Color(0xFF16A34A);

  // Surfaces — light
  static const bgLight = Color(0xFFFAFAF7);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const surfaceAltLight = Color(0xFFF2F4F1);
  static const dividerLight = Color(0xFFE5E7E2);
  static const textPrimaryLight = Color(0xFF12211C);
  static const textSecondaryLight = Color(0xFF5A6560);
  static const textTertiaryLight = Color(0xFF8A918D);

  // Surfaces — dark
  static const bgDark = Color(0xFF0E1513);
  static const surfaceDark = Color(0xFF1A2420);
  static const surfaceAltDark = Color(0xFF22302B);
  static const dividerDark = Color(0xFF2A3833);
  static const textPrimaryDark = Color(0xFFE8F0EC);
  static const textSecondaryDark = Color(0xFFA6B5AE);
  static const textTertiaryDark = Color(0xFF6B7772);

  // Premium indicator
  static const premiumGold = Color(0xFFE0B657);
  static const premiumGoldSoft = Color(0xFFFBF0D6);

  // Shared
  static const shadow = Color(0x14000000);
  static const scrim = Color(0x99000000);
}

/// Soft green-tinted shadows for cards/buttons/FAB — the design-spec tokens.
class AppShadows {
  AppShadows._();

  /// `.cd` cards: 0 1px 2px rgba(11,61,46,.04), 0 4px 12px rgba(11,61,46,.06)
  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x0A0B3D2E), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x0F0B3D2E), blurRadius: 12, offset: Offset(0, 4)),
  ];

  /// `.fab` pill: 0 8px 24px rgba(11,61,46,.22)
  static const List<BoxShadow> fab = [
    BoxShadow(color: Color(0x380B3D2E), blurRadius: 24, offset: Offset(0, 8)),
  ];

  /// `.bp` primary button: 0 4px 16px rgba(11,61,46,.12)
  static const List<BoxShadow> button = [
    BoxShadow(color: Color(0x1F0B3D2E), blurRadius: 16, offset: Offset(0, 4)),
  ];
}

/// 8pt spacing grid. Use these instead of literal dp values everywhere.
class AppSpacing {
  AppSpacing._();
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const base = 16.0;
  static const lg = 20.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const xxxl = 48.0;
  static const edge = 20.0; // horizontal screen edge padding
}

/// Shape tokens per Section 6.1: 16px cards, 12px buttons.
class AppRadii {
  AppRadii._();
  static const xs = 8.0;
  static const sm = 10.0;
  static const md = 12.0;   // buttons
  static const lg = 16.0;   // cards
  static const xl = 20.0;
  static const pill = 999.0;
}

/// Typography scale per Section 6.1: Manrope, Display 32/bold, H1 24/bold,
/// H2 18/semibold, body 15/regular, caption 12.
/// Counter uses tabular figures at 40/extrabold.
class AppTypography {
  AppTypography._();

  static const String family = 'Manrope';

  static TextStyle display({Color? color, TextBaseline? baseline}) => TextStyle(
        fontFamily: family,
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 1.15,
        letterSpacing: -0.5,
        color: color,
      );

  static TextStyle h1({Color? color}) => TextStyle(
        fontFamily: family,
        fontSize: 24,
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: -0.3,
        color: color,
      );

  static TextStyle h2({Color? color}) => TextStyle(
        fontFamily: family,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.25,
        letterSpacing: -0.2,
        color: color,
      );

  static TextStyle h3({Color? color}) => TextStyle(
        fontFamily: family,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: color,
      );

  static TextStyle body({Color? color}) => TextStyle(
        fontFamily: family,
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.45,
        color: color,
      );

  static TextStyle bodyMedium({Color? color}) => TextStyle(
        fontFamily: family,
        fontSize: 15,
        fontWeight: FontWeight.w500,
        height: 1.45,
        color: color,
      );

  static TextStyle caption({Color? color}) => TextStyle(
        fontFamily: family,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.3,
        letterSpacing: 0.1,
        color: color,
      );

  static TextStyle overline({Color? color}) => TextStyle(
        fontFamily: family,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        height: 1.2,
        letterSpacing: 1.2,
        color: color,
      );

  /// Counter: 40pt extrabold, tabular figures — used for the Owed Counter.
  static TextStyle counter({Color? color}) => TextStyle(
        fontFamily: family,
        fontSize: 40,
        fontWeight: FontWeight.w800,
        height: 1.0,
        letterSpacing: -0.8,
        fontFeatures: const [FontFeature.tabularFigures()],
        color: color,
      );

  static TextStyle counterLarge({Color? color}) => TextStyle(
        fontFamily: family,
        fontSize: 56,
        fontWeight: FontWeight.w800,
        height: 1.0,
        letterSpacing: -1.2,
        fontFeatures: const [FontFeature.tabularFigures()],
        color: color,
      );

  /// Medium counter: 28pt extrabold — used in dispute-detail hero (₹400) and
  /// escalate hero (₹900 max claim).
  static TextStyle counterMedium({Color? color}) => TextStyle(
        fontFamily: family,
        fontSize: 28,
        fontWeight: FontWeight.w800,
        height: 1.0,
        letterSpacing: -0.5,
        fontFeatures: const [FontFeature.tabularFigures()],
        color: color,
      );
}

/// Status tokens for chips/badges.
enum StatusKind { neutral, info, warn, danger, success, premium }

extension StatusKindX on StatusKind {
  Color get fg => switch (this) {
        StatusKind.neutral => const Color(0xFF5A6560),
        StatusKind.info => AppColors.primary,
        StatusKind.warn => AppColors.alert,
        StatusKind.danger => AppColors.error,
        StatusKind.success => AppColors.success,
        StatusKind.premium => AppColors.premiumGold,
      };

  Color get bg => switch (this) {
        StatusKind.neutral => const Color(0xFFE5E7E2),
        StatusKind.info => AppColors.accentSoft,
        StatusKind.warn => AppColors.alertSoft,
        StatusKind.danger => AppColors.errorSoft,
        StatusKind.success => const Color(0xFFD7F5E7),
        StatusKind.premium => const Color(0xFFFBF0D6),
      };
}
