import 'package:flutter/material.dart';
import '../../core/theme/app_tokens.dart';
import '../../data/extensions/dispute_type_display.dart';
import '../../data/models/dispute.dart';
import '../../services/compensation_calculator.dart';
import 'status_pill.dart';

/// Dispute list card matching mockup Screen 4.
/// Layout: soft-tinted emoji tile | title + amount | subtitle |
/// 7-segment timeline bars w/ "N days left" | ₹100/day + View → |
/// right status pill (⏰ Day N of M, or deadline-missed red banner variant).
class DisputeCard extends StatelessWidget {
  final Dispute dispute;
  final VoidCallback onTap;
  const DisputeCard({super.key, required this.dispute, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final comp = CompensationCalculator.compute(dispute);
    final isFastag = dispute.type == DisputeType.fastag;
    final isBankCharge = dispute.type == DisputeType.bankCharge;
    final isWrongTransfer = dispute.type == DisputeType.wrongTransfer;
    final daysLeft = isFastag
        ? CompensationCalculator.daysUntilFastagExpiry(dispute)
        : CompensationCalculator.daysUntilChargebackExpiry(dispute);
    final windowDays = isFastag ? 30 : 45;
    final dayN = windowDays - daysLeft.clamp(0, windowDays);
    final deadlineMissed =
        !isBankCharge && !isWrongTransfer && daysLeft <= 0 && dispute.status != DisputeStatus.resolved;

    final borderColor =
        deadlineMissed ? AppColors.errorSoft : AppColors.dividerLight;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          border: Border.all(color: borderColor, width: 1),
          borderRadius: BorderRadius.circular(AppRadii.lg),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // emoji tile
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: dispute.type.softColor,
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              child: Center(
                child: Text(
                  dispute.type.emoji,
                  style: const TextStyle(fontSize: 18, height: 1),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // body
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          dispute.type.displayName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimaryLight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        CompensationCalculator.formatIndian(dispute.amount),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: deadlineMissed
                              ? AppColors.error
                              : AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _subtitle(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondaryLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (deadlineMissed)
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(
                              color: AppColors.error,
                              width: 1,
                              style: BorderStyle.solid),
                          bottom: BorderSide(
                              color: AppColors.error,
                              width: 1,
                              style: BorderStyle.solid),
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          '⚠ Deadline missed — escalate now',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    )
                  else if (!isBankCharge && !isWrongTransfer) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: _Timeline(
                            total: windowDays,
                            done: dayN,
                            color: _barColor(comp),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          daysLeft > 0 ? '$daysLeft days left' : 'Expired',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          dispute.type.compensationLabel ?? 'Guidance mode',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: deadlineMissed
                                ? AppColors.error
                                : AppColors.accent,
                          ),
                        ),
                      ),
                      Text(
                        deadlineMissed ? 'Escalate →' : 'View →',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // right status pill
            _rightPill(deadlineMissed, dayN, windowDays),
          ],
        ),
      ),
    );
  }

  Widget _rightPill(bool missed, int dayN, int windowDays) {
    if (dispute.status == DisputeStatus.resolved) {
      return const StatusPill(
        label: 'Resolved',
        prefix: '✓',
        fg: AppColors.success,
        bg: AppColors.accentSoft,
      );
    }
    if (missed) {
      return const StatusPill(
        label: 'Missed',
        prefix: '⚠',
        fg: AppColors.error,
        bg: AppColors.errorSoft,
      );
    }
    return StatusPill(
      label: 'Day $dayN of $windowDays',
      prefix: '⏰',
      fg: AppColors.alert,
      bg: AppColors.alertSoft,
    );
  }

  Color _barColor(CompensationResult comp) =>
      comp.shouldEscalate ? AppColors.error : AppColors.alert;

  String _subtitle() {
    final parts = <String>[];
    if (dispute.entityName != null && dispute.entityName!.isNotEmpty) {
      parts.add(dispute.entityName!);
    }
    parts.add(_typeShort());
    if (dispute.txnId.isNotEmpty) {
      final masked = dispute.txnId.length > 12
          ? '${dispute.txnId.substring(0, 4)}********${dispute.txnId.substring(dispute.txnId.length - 2)}'
          : dispute.txnId;
      parts.add('UTR $masked');
    } else {
      parts.add(_fmtDate(dispute.txnDate));
    }
    return parts.join(' · ');
  }

  String _typeShort() => switch (dispute.type) {
        DisputeType.upiP2p => 'UPI',
        DisputeType.upiP2m => 'UPI',
        DisputeType.atm => 'ATM',
        DisputeType.imps => 'IMPS',
        DisputeType.fastag => 'FASTag',
        DisputeType.bankCharge => 'Bank charge',
        DisputeType.wrongTransfer => 'Wrong transfer',
      };

  String _fmtDate(DateTime d) =>
      '${d.day} ${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][d.month - 1]}';
}

/// 7-segment progress bar matching mockup timeline strip.
class _Timeline extends StatelessWidget {
  final int total;
  final int done;
  final Color color;
  const _Timeline({required this.total, required this.done, required this.color});

  @override
  Widget build(BuildContext context) {
    const segments = 7;
    final perSeg = total / segments;
    return Row(
      children: List.generate(segments, (i) {
        final filled = i < (done / perSeg).floor();
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < segments - 1 ? 3 : 0),
            height: 5,
            decoration: BoxDecoration(
              color: filled ? color : AppColors.dividerLight,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}
