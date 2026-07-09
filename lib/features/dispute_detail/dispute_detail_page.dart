import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:refund_radar/core/providers/app_state_provider.dart';
import 'package:refund_radar/core/providers/auth_provider.dart';
import 'package:refund_radar/core/providers/dispute_provider.dart';
import 'package:refund_radar/core/theme/app_tokens.dart';
import 'package:refund_radar/data/extensions/dispute_type_display.dart';
import 'package:refund_radar/data/models/dispute.dart';
import 'package:refund_radar/data/repositories/reminder_repository.dart';
import 'package:refund_radar/l10n/app_localizations.dart';
import 'package:refund_radar/services/compensation_calculator.dart';
import 'package:refund_radar/shared/widgets/app_back_button.dart';
import 'package:refund_radar/shared/widgets/rbi_timeline.dart';
import 'package:refund_radar/shared/widgets/activity_log.dart';
import 'package:refund_radar/shared/widgets/branded_error_banner.dart';
import 'package:refund_radar/shared/widgets/skeleton.dart';

class DisputeDetailPage extends ConsumerWidget {
  final String id;
  const DisputeDetailPage({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(userIdProvider).asData?.value;
    if (uid == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final disputesAsync = ref.watch(disputesProvider(uid));
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: SafeArea(
        child: disputesAsync.when(
          data: (disputes) {
            Dispute? dispute;
            for (final d in disputes) {
              if (d.id == id) {
                dispute = d;
                break;
              }
            }
            if (dispute == null) {
              return BrandedErrorBanner(
                message: 'Dispute not found.',
                onRetry: () => ref.invalidate(disputesProvider(uid)),
              );
            }
            return _DisputeBody(uid: uid, dispute: dispute);
          },
          loading: () => const SkeletonList(itemCount: 3),
          error: (e, _) => BrandedErrorBanner(
            message: e.toString(),
            onRetry: () => ref.invalidate(disputesProvider(uid)),
          ),
        ),
      ),
    );
  }
}

class _DisputeBody extends ConsumerWidget {
  final String uid;
  final Dispute dispute;
  const _DisputeBody({required this.uid, required this.dispute});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final comp = CompensationCalculator.compute(dispute);
    final isFastag = dispute.type == DisputeType.fastag;
    final daysLeft = isFastag
        ? CompensationCalculator.daysUntilFastagExpiry(dispute)
        : CompensationCalculator.daysUntilChargebackExpiry(dispute);
    final windowDays = isFastag ? 30 : 45;
    final dayN = windowDays - daysLeft.clamp(0, windowDays);
    final deadlineMissed = daysLeft <= 0 && dispute.status != DisputeStatus.resolved;
    final hoursLeft = (daysLeft < 0 ? 0 : daysLeft * 24);

    return Column(
      children: [
        // header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AppBackButton(
                onTap: () => context.pop(),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dispute.type.displayName,
                      style: const TextStyle(
                        fontFamily: AppTypography.family,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _headerSubtitle(),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondaryLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            children: [
              // hero
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: dispute.type.softColor,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(dispute.type.emoji,
                          style: const TextStyle(fontSize: 24)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          CompensationCalculator.formatIndian(dispute.amount),
                          style: const TextStyle(
                            fontFamily: AppTypography.family,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                            letterSpacing: -0.5,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            if (dispute.status != DisputeStatus.resolved &&
                                !deadlineMissed)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.alertSoft,
                                  borderRadius:
                                      BorderRadius.circular(AppRadii.pill),
                                ),
                                child: Text(
                                  '⏰ Day $dayN of $windowDays',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.alert,
                                  ),
                                ),
                              ),
                            if (deadlineMissed)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.errorSoft,
                                  borderRadius:
                                      BorderRadius.circular(AppRadii.pill),
                                ),
                                child: const Text(
                                  '⚠ Deadline missed',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.error,
                                  ),
                                ),
                              ),
                            if (dispute.status == DisputeStatus.resolved)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.accentSoft,
                                  borderRadius:
                                      BorderRadius.circular(AppRadii.pill),
                                ),
                                child: const Text(
                                  '✓ Resolved',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.success,
                                  ),
                                ),
                              ),
                            const SizedBox(width: 8),
                            Text(
                              dispute.type.compensationLabel ??
                                  'Guidance mode',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondaryLight,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // RBI timeline card
              RbiTimeline(
                headerLabel: _timelineHeader(),
                steps: _timelineSteps(comp, l10n),
              ),
              const SizedBox(height: 14),
              // Escalate row
              if (dispute.type != DisputeType.wrongTransfer) ...[
                Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        label: deadlineMissed ? 'Escalate now' : 'Escalate',
                        color: AppColors.alert,
                        onTap: () => context.push('/wizard/${dispute.id}'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _IconAction(
                      emoji: '📧',
                      onTap: () => context.push('/escalate/${dispute.id}'),
                    ),
                    const SizedBox(width: 8),
                    _IconAction(
                      emoji: '📝',
                      onTap: () {
                        // B3 gate: Ombudsman letter generator is premium-only
                        // (spec §4.3 / comparison table on the paywall).
                        final isPremium = ref.read(isPremiumProvider);
                        if (!isPremium) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Ombudsman letter generator is a Premium feature.'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                          context.push(
                              '/paywall?return=/disputes/${dispute.id}&trigger=ombudsman_letter');
                          return;
                        }
                        context.push('/ombudsman/${dispute.id}');
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 14),
              ],
              // Activity log
              ActivityLog(
                headerLabel: l10n?.detailActivityHeader(_activityLog(l10n).length) ??
                    'Activity · ${_activityLog(l10n).length} events',
                entries: _activityLog(l10n),
              ),
            ],
          ),
        ),
        // sticky footer
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          decoration: const BoxDecoration(
            color: AppColors.surfaceLight,
            border: Border(
              top: BorderSide(color: AppColors.dividerLight, width: 1),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: dispute.status != DisputeStatus.resolved
                    ? RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondaryLight,
                            height: 1.3,
                          ),
                          children: [
                            const TextSpan(
                              text: '🔴 ',
                              style: TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                            TextSpan(
                              text: deadlineMissed
                                  ? 'Window expired'
                                  : '$hoursLeft hours until T+${dispute.type.tatDays ?? 5} deadline',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: deadlineMissed
                                    ? AppColors.error
                                    : AppColors.alert,
                              ),
                            ),
                          ],
                        ),
                      )
                    : const Text(
                        'This dispute is resolved.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondaryLight,
                        ),
                      ),
              ),
              _ActionButton(
                label: dispute.status == DisputeStatus.resolved
                    ? 'Reopen'
                    : 'Mark resolved',
                color: AppColors.surfaceAltLight,
                textColor: AppColors.primary,
                onTap: () => _toggleResolved(context, ref),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _headerSubtitle() {
    final parts = <String>[];
    if (dispute.entityName != null && dispute.entityName!.isNotEmpty) {
      parts.add(dispute.entityName!);
    }
    parts.add(_typeShort());
    final ticket = dispute.ticketNumbers['l1'];
    if (ticket != null && ticket.isNotEmpty) {
      parts.add('Ticket $ticket');
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

  String _timelineHeader() => dispute.type == DisputeType.fastag
      ? 'FASTag timeline (30-day window)'
      : dispute.type == DisputeType.bankCharge
          ? 'Bank timeline (30-day window)'
          : 'RBI timeline (T-day = 0)';

  List<RbiTimelineStep> _timelineSteps(CompensationResult comp, AppLocalizations? l10n) {
    final tat = dispute.type.tatDays ?? 5;
    if (dispute.type == DisputeType.wrongTransfer) {
      return [
        const RbiTimelineStep(
            title: 'Request to own bank',
            detail: 'Contact your bank to reach the beneficiary',
            state: RbiStepState.done),
        const RbiTimelineStep(
            title: 'NPCI DRM entry',
            detail: 'Within 3 days — wrong-transfer portal'),
        const RbiTimelineStep(
            title: 'Cyber cell complaint',
            detail: 'If fraud suspected'),
        const RbiTimelineStep(
            title: 'Legal notice',
            detail: 'Final escalation'),
      ];
    }
    if (dispute.type == DisputeType.fastag) {
      return [
        const RbiTimelineStep(
            title: 'Reported',
            detail: 'Day 0 · transaction flagged',
            state: RbiStepState.done),
        RbiTimelineStep(
            title: 'Issuer bank',
            detail: dispute.entityName != null
                ? '${dispute.entityName} dispute section · 7-10 days'
                : 'Issuer bank · 7-10 days',
            state: RbiStepState.active),
        const RbiTimelineStep(
            title: '1033 Helpline',
            detail: 'If no reply in 7 days'),
        const RbiTimelineStep(
            title: 'IHMCL false-deduction email',
            detail: 'falsededuction@ihmcl.com'),
        const RbiTimelineStep(
            title: 'RBI Ombudsman',
            detail: 'If unresolved after 30 days'),
      ];
    }
    final ackDone = dispute.status != DisputeStatus.draft;
    final refundDone = dispute.status == DisputeStatus.resolved;
    final refundActive = comp.isExpired && !refundDone;
    final l2Done = dispute.status == DisputeStatus.filedL2 ||
        dispute.status == DisputeStatus.ombudsman;
    final l3Done = dispute.status == DisputeStatus.ombudsman;
    return [
      RbiTimelineStep(
          title: l10n?.detailTimelineReported ?? 'Reported',
          detail: l10n?.detailTimelineReportedDetail(_fmtDate(dispute.txnDate)) ??
              'T+0 · ${_fmtDate(dispute.txnDate)}',
          state: RbiStepState.done),
      RbiTimelineStep(
          title: l10n?.detailTimelineAck ?? 'Bank must acknowledge',
          detail: ackDone
              ? (l10n?.detailTimelineAckDone ?? 'T+1 · acknowledged')
              : (l10n?.detailTimelineAckPending ?? 'T+1 · by today'),
          state: ackDone ? RbiStepState.done : RbiStepState.active),
      RbiTimelineStep(
          title: l10n?.detailTimelineRefund ?? 'Refund due',
          detail: refundDone
              ? (l10n?.detailTimelineRefundDone('$tat') ?? 'T+$tat · refunded')
              : (refundActive
                  ? (l10n?.detailTimelineRefundMissed('$tat') ??
                      'T+$tat · deadline missed — escalate')
                  : (l10n?.detailTimelineRefundPending('$tat',
                          _fmtDate(dispute.txnDate.add(Duration(days: tat))),
                          comp.daysElapsed) ??
                      'T+$tat · ${_fmtDate(dispute.txnDate.add(Duration(days: tat)))} (in ${comp.daysElapsed}d)')),
          state: refundDone
              ? RbiStepState.done
              : (refundActive ? RbiStepState.active : RbiStepState.pending)),
      RbiTimelineStep(
          title: l10n?.detailTimelineEscalate ?? 'Escalate to nodal officer',
          detail: l2Done
              ? (l10n?.detailTimelineL2Detail(dispute.ticketNumbers['l2'] ?? '—') ??
                  'Filed · ${dispute.ticketNumbers['l2'] ?? "—"}')
              : (l10n?.detailTimelineL2Pending('$tat') ?? 'If no refund by T+$tat'),
          state: l2Done ? RbiStepState.done : RbiStepState.pending),
      RbiTimelineStep(
          title: l10n?.detailTimelineOmbudsman ?? 'RBI Banking Ombudsman',
          detail: l3Done
              ? (l10n?.detailTimelineL3Detail(dispute.ticketNumbers['l3'] ?? '—') ??
                  'Filed · ${dispute.ticketNumbers['l3'] ?? "—"}')
              : (l10n?.detailTimelineL3Pending ??
                  'If unresolved after T+10 (30 days)'),
          state: l3Done ? RbiStepState.done : RbiStepState.pending),
    ];
  }

  List<ActivityEntry> _activityLog(AppLocalizations? l10n) {
    final entries = <ActivityEntry>[];
    final l1Ticket = dispute.ticketNumbers['l1'];
    if (l1Ticket != null && l1Ticket.isNotEmpty) {
      entries.add(ActivityEntry(
        label: l10n?.detailActivityTicket(l1Ticket) ?? 'Ticket $l1Ticket filed',
        meta: l10n?.detailActivityTicketMeta(_fmtDate(dispute.filedDates['l1'] ?? dispute.createdAt)) ??
            'Auto-generated · ${_fmtDate(dispute.filedDates['l1'] ?? dispute.createdAt)}',
        highlighted: true,
      ));
    }
    if (dispute.txnId.isNotEmpty) {
      entries.add(ActivityEntry(
        label: l10n?.detailActivityAutoUtr ?? 'Auto-detected UTR from SMS',
        meta: _fmtDate(dispute.txnDate),
      ));
    }
    entries.add(ActivityEntry(
      label: l10n?.detailActivityMarkedActive ?? 'Dispute marked active',
      meta: _fmtDate(dispute.createdAt),
    ));
    if (dispute.status == DisputeStatus.resolved && dispute.resolvedAt != null) {
      entries.insert(0, ActivityEntry(
        label: l10n?.detailActivityResolved ?? 'Dispute resolved',
        meta: _fmtDate(dispute.resolvedAt!),
        highlighted: true,
      ));
    }
    return entries;
  }

  String _fmtDate(DateTime d) =>
      '${d.day} ${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][d.month - 1]}, ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  Future<void> _toggleResolved(BuildContext context, WidgetRef ref) async {
    final nextStatus = dispute.status == DisputeStatus.resolved
        ? DisputeStatus.filedL1
        : DisputeStatus.resolved;
    final repo = ref.read(disputeRepositoryProvider);
    final updated = dispute.copyWith(
      status: nextStatus,
      resolvedAt: nextStatus == DisputeStatus.resolved ? DateTime.now() : null,
    );
    await repo.saveDispute(uid, updated);
    // B6: lifecycle changed → re-sync reminders + local notifications.
    await syncRemindersForDispute(ref, uid, updated);
    ref.invalidate(disputesProvider(uid));
    ref.invalidate(remindersProvider(uid));
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final Color? textColor;
  final VoidCallback onTap;
  const _ActionButton({
    required this.label,
    required this.color,
    required this.onTap,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.md),
        onTap: onTap,
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppTypography.family,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textColor ?? Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  final String emoji;
  final VoidCallback onTap;
  const _IconAction({required this.emoji, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceAltLight,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.md),
        onTap: onTap,
        child: Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          child: Text(emoji, style: const TextStyle(fontSize: 18)),
        ),
      ),
    );
  }
}
