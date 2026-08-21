import 'package:flutter/material.dart';
import '../../core/theme/app_theme_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../l10n/app_localizations.dart';
import '../models/dispute.dart';

/// Display-only metadata for [DisputeType]: emoji, soft color, human name
/// and short subtitle for the dispute-type picker card.
extension DisputeTypeDisplay on DisputeType {
  String get emoji => switch (this) {
        DisputeType.upiP2p => '💳',
        DisputeType.upiP2m => '💰',
        DisputeType.atm => '🏧',
        DisputeType.fastag => '🚗',
        DisputeType.imps => '📨',
        DisputeType.bankCharge => '🏦',
        DisputeType.wrongTransfer => '🔁',
      };

  /// Brand icon for the type. Replaces emoji glyphs in high-visibility UI
  /// (cards, pickers, detail hero) with a consistent Material icon set so the
  /// app reads as a designed system, not a sticker sheet.
  IconData get icon => switch (this) {
        DisputeType.upiP2p => Icons.qr_code_scanner_rounded,
        DisputeType.upiP2m => Icons.currency_rupee_rounded,
        DisputeType.atm => Icons.local_atm_rounded,
        DisputeType.fastag => Icons.directions_car_rounded,
        DisputeType.imps => Icons.send_rounded,
        DisputeType.bankCharge => Icons.account_balance_rounded,
        DisputeType.wrongTransfer => Icons.swap_horiz_rounded,
      };

  /// Curated brand hue for the type icon (used inside the soft tile).
  /// Chosen to be distinguishable at a glance while staying inside the
  /// app's trust-blue / amber / red / gold status vocabulary.
  Color get iconColor => switch (this) {
        DisputeType.upiP2p => AppColors.primary,
        DisputeType.upiP2m => const Color(0xFF0E9F6E), // money green
        DisputeType.atm => AppColors.premiumGold,
        DisputeType.fastag => AppColors.alert,
        DisputeType.imps => const Color(0xFF7C3AED), // violet
        DisputeType.bankCharge => AppColors.textSecondaryLight,
        DisputeType.wrongTransfer => const Color(0xFF0284C7), // sky
      };

  /// Light-only; prefer [softColorFor] in widgets.
  Color get softColor => switch (this) {
        DisputeType.upiP2p => AppColors.accentSoft,
        DisputeType.upiP2m => AppColors.accentSoft,
        DisputeType.atm => AppColors.premiumGoldSoft,
        DisputeType.fastag => AppColors.alertSoft,
        DisputeType.imps => AppColors.errorSoft,
        DisputeType.bankCharge => AppColors.surfaceAltLight,
        DisputeType.wrongTransfer => AppColors.surfaceAltLight,
      };

  Color softColorFor(AppThemeColors tc) => switch (this) {
        DisputeType.upiP2p => tc.accentSoft,
        DisputeType.upiP2m => tc.accentSoft,
        DisputeType.atm => tc.premiumGoldSoft,
        DisputeType.fastag => tc.alertSoft,
        DisputeType.imps => tc.errorSoft,
        DisputeType.bankCharge => tc.surfaceAlt,
        DisputeType.wrongTransfer => tc.surfaceAlt,
      };

  /// English fallback (non-UI / tests).
  String get displayName => localizedName(null);

  String localizedName(AppLocalizations? l10n) => switch (this) {
        DisputeType.upiP2p => l10n?.typeUpiP2p ?? 'UPI / QR failed',
        DisputeType.upiP2m => l10n?.typeUpiP2m ?? 'Failed UPI refund',
        DisputeType.atm => l10n?.typeAtm ?? 'ATM failed dispense',
        DisputeType.fastag => l10n?.typeFastag ?? 'FASTag double-cut',
        DisputeType.imps => l10n?.typeImps ?? 'IMPS / NEFT failed',
        DisputeType.bankCharge => l10n?.typeBankCharge ?? 'Bank charge',
        DisputeType.wrongTransfer =>
          l10n?.typeWrongTransfer ?? 'Wrong transfer',
      };

  String get subtitle => localizedSubtitle(null);

  String localizedSubtitle(AppLocalizations? l10n) => switch (this) {
        DisputeType.upiP2p =>
          l10n?.typeSubUpiP2p ?? 'Debit, no credit · double debit',
        DisputeType.upiP2m => l10n?.typeSubUpiP2m ?? 'Refund not received',
        DisputeType.atm => l10n?.typeSubAtm ?? 'Cash debited, not dispensed',
        DisputeType.fastag =>
          l10n?.typeSubFastag ?? 'Double debit · failed tag read',
        DisputeType.imps => l10n?.typeSubImps ?? 'Money debited, not credited',
        DisputeType.bankCharge =>
          l10n?.typeSubBankCharge ?? 'Unauthorised debits',
        DisputeType.wrongTransfer =>
          l10n?.typeSubWrongTransfer ?? 'Wrong-account guidance',
      };

  /// Compensation-rate string for the card (e.g. "₹100/day compensation").
  String? get compensationLabel => localizedCompensation(null);

  String? localizedCompensation(AppLocalizations? l10n) {
    final perDay = compensationPerDay;
    if (perDay == null || perDay <= 0) return null;
    return l10n?.typeCompPerDay('$perDay') ?? '₹$perDay/day compensation';
  }
}
