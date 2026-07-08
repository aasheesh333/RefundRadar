import 'package:refund_radar/data/models/dispute.dart';

class CompensationResult {
  final int daysElapsed;
  final double compensationDue;
  final DateTime deadlineDate;
  final bool isExpired;
  final bool shouldEscalate;

  const CompensationResult({
    required this.daysElapsed,
    required this.compensationDue,
    required this.deadlineDate,
    required this.isExpired,
    required this.shouldEscalate,
  });
}

class CompensationCalculator {
  static const int _displayCapDays = 90;

  static CompensationResult compute(Dispute dispute, {DateTime? now}) {
    final today = (now ?? DateTime.now());
    if (dispute.type.tatDays == null || dispute.type.compensationPerDay == null) {
      // No compensation for fastag/bank_charge/wrong_transfer as per spec
      return CompensationResult(
        daysElapsed: 0,
        compensationDue: 0,
        deadlineDate: dispute.txnDate,
        isExpired: false,
        shouldEscalate: false,
      );
    }
    final deadline = dispute.txnDate.add(Duration(days: dispute.type.tatDays!));
    final elapsed = today.difference(deadline).inDays;
    final days = elapsed < 0 ? 0 : (elapsed > _displayCapDays ? _displayCapDays : elapsed);
    final comp = days * dispute.type.compensationPerDay!;
    return CompensationResult(
      daysElapsed: days,
      compensationDue: comp.toDouble(),
      deadlineDate: deadline,
      isExpired: today.isAfter(deadline),
      shouldEscalate: days >= 30,
    );
  }

  static int daysUntilChargebackExpiry(Dispute dispute, {DateTime? now}) {
    final today = (now ?? DateTime.now());
    const window = 45;
    return dispute.txnDate.add(const Duration(days: window)).difference(today).inDays;
  }

  static int daysUntilFastagExpiry(Dispute dispute, {DateTime? now}) {
    final today = (now ?? DateTime.now());
    return dispute.txnDate.add(const Duration(days: 30)).difference(today).inDays;
  }

  static String formatIndian(double amount) {
    final str = amount.toStringAsFixed(0);
    final parts = <String>[];
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      if (count == 3) {
        parts.insert(0, ',');
      } else if (count > 3 && count % 2 == 1) {
        parts.insert(0, ',');
      }
      parts.insert(0, str[i]);
      count++;
    }
    return '₹${parts.join()}';
  }
}
