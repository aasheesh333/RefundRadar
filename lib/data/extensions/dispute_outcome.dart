import '../models/dispute.dart';

/// Outcome classification helpers for the History / Ledger screen (ME-4).
///
/// The old history card and the `filterHistoryDisputes` filter both inlined
/// these predicates with slight drift (e.g. the filter used `> 0` while the
/// card used `> 0` + `<= amount` for "won"). Centralising them removes the
/// fragile switch arm ordering and the duplicated boolean logic.
extension DisputeOutcomeX on Dispute {
  /// A dispute is "won" when it resolved with a positive refund/credit.
  bool get isWon =>
      status == DisputeStatus.resolved && (resolvedAmount ?? 0) > 0;

  /// A dispute is "lost" when it expired, or resolved with zero recovery.
  bool get isLost =>
      status == DisputeStatus.expired ||
      (status == DisputeStatus.resolved && (resolvedAmount ?? 0) == 0);

  /// A dispute is "partial" when it won but recovered less than the debited
  /// amount (e.g. a partial reversal + a smaller comp).
  bool get isPartial => isWon && (resolvedAmount ?? 0) < amount;
}
