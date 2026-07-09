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
