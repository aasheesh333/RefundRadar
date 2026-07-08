import 'package:flutter/material.dart';
import '../../core/theme/app_tokens.dart';
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

  Color get softColor => switch (this) {
        DisputeType.upiP2p => AppColors.accentSoft,
        DisputeType.upiP2m => AppColors.accentSoft,
        DisputeType.atm => AppColors.premiumGoldSoft,
        DisputeType.fastag => AppColors.alertSoft,
        DisputeType.imps => AppColors.errorSoft,
        DisputeType.bankCharge => AppColors.surfaceAltLight,
        DisputeType.wrongTransfer => AppColors.surfaceAltLight,
      };

  String get displayName => switch (this) {
        DisputeType.upiP2p => 'UPI / QR failed',
        DisputeType.upiP2m => 'Failed UPI refund',
        DisputeType.atm => 'ATM failed dispense',
        DisputeType.fastag => 'FASTag double-cut',
        DisputeType.imps => 'IMPS / NEFT failed',
        DisputeType.bankCharge => 'Bank charge',
        DisputeType.wrongTransfer => 'Wrong transfer',
      };

  String get subtitle => switch (this) {
        DisputeType.upiP2p => 'Debit, no credit · double debit',
        DisputeType.upiP2m => 'Refund not received',
        DisputeType.atm => 'Cash debited, not dispensed',
        DisputeType.fastag => 'Double debit · failed tag read',
        DisputeType.imps => 'Money debited, not credited',
        DisputeType.bankCharge => 'Unauthorised debits',
        DisputeType.wrongTransfer => 'Wrong-account guidance',
      };

  /// Compensation-rate string for the card (e.g. "₹100/day compensation").
  String? get compensationLabel {
    final perDay = compensationPerDay;
    if (compensationPerDay == null || compensationPerDay! <= 0) return null;
    // ignore: unnecessary_null_comparison
    return '₹$perDay/day compensation';
  }
}
