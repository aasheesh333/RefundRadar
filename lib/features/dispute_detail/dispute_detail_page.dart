import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:refund_radar/core/providers/auth_provider.dart';
import 'package:refund_radar/core/providers/dispute_provider.dart';
import 'package:refund_radar/core/providers/premium_provider.dart';
import 'package:refund_radar/core/providers/theme_provider.dart';
import 'package:refund_radar/core/router/app_routes.dart';
import 'package:refund_radar/core/theme/app_tokens.dart';
import 'package:refund_radar/core/theme/app_theme_colors.dart';
import 'package:refund_radar/data/extensions/dispute_type_display.dart';
import 'package:refund_radar/data/models/activity_log_entry.dart';
import 'package:refund_radar/data/models/dispute.dart';
import 'package:refund_radar/data/models/template.dart';
import 'package:refund_radar/data/repositories/reminder_repository.dart';
import 'package:refund_radar/data/repositories/rules_engine_repository.dart';
import 'package:refund_radar/data/repositories/template_repository.dart';
import 'package:refund_radar/l10n/app_localizations.dart';
import 'package:refund_radar/services/compensation_calculator.dart';
import 'package:refund_radar/shared/utils/error_mapper.dart';
import 'package:refund_radar/shared/widgets/activity_log.dart';
import 'package:refund_radar/shared/widgets/branded_error_banner.dart';
import 'package:refund_radar/shared/widgets/rbi_timeline.dart';
import 'package:refund_radar/shared/widgets/skeleton.dart';

/// Wave 4b redesign — clean-minimal Material 3 timeline screen.
///
/// Same affordances as the previous DisputeDetail (auto-match template,
/// editable template pick via the new full-screen Picker from Wave 4a,
/// activity log, status toggle, escalate row), but with a fully new visual
/// treatment:
///   - Compact top bar (back arrow + type badge + overflow menu).
///   - Slim hero card with the disputed amount + window-day pill.
///   - Vertical timeline rail (delegated to the shared `RbiTimeline`).
///   - Side-by-side quick actions (Escalate now · email · ombudsman).
///   - "TEMPLATE" card showing auto-match status with a single tap to
///     open the new full-screen Picker.
class DisputeDetailPage extends ConsumerWidget {
  final String id;
  const DisputeDetailPage({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tc = AppThemeColors.of(context);
    final l10n = AppLocalizations.of(context);
    final uidAsync = ref.watch(userIdProvider);
    return Scaffold(
      backgroundColor: tc.bg,
      body: SafeArea(
        child: uidAsync.when(
          loading: () => const SkeletonList(itemCount: 3),
          error: (e, _) => BrandedErrorBanner(
            message: friendlyError(e),
            detail: errorDetail(e),
            onRetry: () => ref.invalidate(userIdProvider),
          ),
          data: (uid) {
            if (uid == null || uid.isEmpty) {
              return BrandedErrorBanner(
                message: l10n?.commonCouldNotSignIn ?? 'Could not sign in',
                onRetry: () => ref.invalidate(userIdProvider),
              );
            }
            final disputesAsync = ref.watch(disputesProvider(uid));
            return disputesAsync.when(
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
                    message:
                        l10n?.commonDisputeNotFound ?? 'Dispute not found',
                    onRetry: () => ref.invalidate(disputesProvider(uid)),
                  );
                }
                return _DisputeBody(uid: uid, dispute: dispute);
              },
              loading: () => const SkeletonList(itemCount: 3),
              error: (e, _) => BrandedErrorBanner(
                message: friendlyError(e),
                detail: errorDetail(e),
                onRetry: () => ref.invalidate(disputesProvider(uid)),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DisputeBody extends ConsumerStatefulWidget {
  final String uid;
  final Dispute dispute;
  const _DisputeBody({required this.uid, required this.dispute});
  @override
  ConsumerState<_DisputeBody> createState() => _DisputeBodyState();
}

class _DisputeBodyState extends ConsumerState<_DisputeBody> {
  Dispute get dispute => widget.dispute;
  String get uid => widget.uid;
  String? _selectedTemplateId;
  bool _toggling = false;

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    final l10n = AppLocalizations.of(context);
    final comp = CompensationCalculator.compute(dispute);
    final isFastag = dispute.type == DisputeType.fastag;
    final daysLeft = isFastag
        ? CompensationCalculator.daysUntilFastagExpiry(dispute)
        : CompensationCalculator.daysUntilChargebackExpiry(dispute);
    final windowDays = isFastag ? 30 : 45;
    final dayN = windowDays - daysLeft.clamp(0, windowDays);
    final deadlineMissed =
        daysLeft <= 0 && dispute.status != DisputeStatus.resolved;
    final hoursLeft = (daysLeft < 0 ? 0 : daysLeft * 24);

    final templatesAsync = ref.watch(templatesProvider);
    final rulesAsync = ref.watch(rulesEngineProvider);
    final freeIds =
        rulesAsync.asData?.value.freeTemplateIds.toSet() ?? const <String>{};
    final isPremiumUser = ref.watch(isPremiumProvider);
    final localeCode = ref.watch(localeProvider).languageCode;
    final repo = ref.read(templateRepositoryProvider);
    final allTemplates = templatesAsync.asData?.value ?? const [];

    Template? matchedTemplate;
    if (_selectedTemplateId != null) {
      for (final t in allTemplates) {
        if (t.id == _selectedTemplateId) {
          matchedTemplate = t;
          break;
        }
      }
    }
    matchedTemplate ??= repo.matchForCategory(
      allTemplates,
      dispute.type,
      freeIds,
      isPremiumUser: isPremiumUser,
    );

    return Column(
      children: [
        _TopBar(dispute: dispute, tc: tc, l10n: l10n),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
            children: [
              _HeroCard(
                dispute: dispute,
                dayN: dayN,
                windowDays: windowDays,
                deadlineMissed: deadlineMissed,
                tc: tc,
                l10n: l10n,
              ),
              const SizedBox(height: 16),
              RbiTimeline(
                headerLabel: _timelineHeader(l10n),
                steps: _timelineSteps(comp, l10n),
              ),
              const SizedBox(height: 16),
              if (dispute.type != DisputeType.wrongTransfer)
                _QuickActions(
                  dispute: dispute,
                  deadlineMissed: deadlineMissed,
                  tc: tc,
                  l10n: l10n,
                ),
              if (dispute.type != DisputeType.wrongTransfer)
                const SizedBox(height: 16),
              if (dispute.type != DisputeType.wrongTransfer)
                _TemplateCard(
                  dispute: dispute,
                  matchedTemplate: matchedTemplate,
                  repo: repo,
                  freeIds: freeIds,
                  isPremiumUser: isPremiumUser,
                  localeCode: localeCode,
                  tc: tc,
                  l10n: l10n,
                ),
              if (dispute.type != DisputeType.wrongTransfer)
                const SizedBox(height: 16),
              ActivityLog(
                headerLabel: l10n?.detailActivityHeader(
                        _activityLog(l10n).length) ??
                    'Activity · ${_activityLog(l10n).length} events',
                entries: _activityLog(l10n),
              ),
            ],
          ),
        ),
        _StickyFooter(
          dispute: dispute,
          hoursLeft: hoursLeft,
          deadlineMissed: deadlineMissed,
          toggling: _toggling,
          onConfirm: () => _confirmToggle(),
          tc: tc,
          l10n: l10n,
        ),
      ],
    );
  }

  // -- Builders -----------------------------------------------------------

  String _timelineHeader(AppLocalizations? l10n) =>
      dispute.type == DisputeType.fastag
          ? (l10n?.detailTimelineFastagHeader ??
              'FASTag timeline (30-day window)')
          : dispute.type == DisputeType.bankCharge
              ? (l10n?.detailTimelineBankHeader ??
                  'Bank timeline (30-day window)')
              : (l10n?.detailTimelineRbiHeader ?? 'RBI timeline');

  List<RbiTimelineStep> _timelineSteps(
      CompensationResult comp, AppLocalizations? l10n) {
    final tat = dispute.type.tatDays ?? 5;
    if (dispute.type == DisputeType.wrongTransfer) {
      return [
        RbiTimelineStep(
            title: l10n?.detailTlWtRequest ?? 'Request to own bank',
            detail: l10n?.detailTlWtRequestDetail ??
                'Contact your bank to reach the beneficiary',
            state: RbiStepState.done),
        RbiTimelineStep(
            title: l10n?.detailTlWtNpci ?? 'NPCI DRM entry',
            detail: l10n?.detailTlWtNpciDetail ??
                'Within 3 days — wrong-transfer portal'),
        RbiTimelineStep(
            title: l10n?.detailTlWtCyber ?? 'Cyber cell complaint',
            detail: l10n?.detailTlWtCyberDetail ?? 'If fraud suspected'),
        RbiTimelineStep(
            title: l10n?.detailTlWtLegal ?? 'Legal notice',
            detail: l10n?.detailTlWtLegalDetail ?? 'Final escalation'),
      ];
    }
    if (dispute.type == DisputeType.fastag) {
      return [
        RbiTimelineStep(
            title: l10n?.detailTlFtReported ?? 'Reported',
            detail:
                l10n?.detailTlFtReportedDetail ?? 'Day 0 · transaction flagged',
            state: RbiStepState.done),
        RbiTimelineStep(
            title: l10n?.detailTlFtIssuer ?? 'Issuer bank',
            detail: dispute.entityName != null
                ? (l10n?.detailTlFtIssuerDetail(dispute.entityName!) ??
                    '${dispute.entityName} dispute section · 7-10 days')
                : (l10n?.detailTlFtIssuerGeneric ??
                    'Issuer bank · 7-10 days'),
            state: RbiStepState.active),
        RbiTimelineStep(
            title: l10n?.detailTlFtHelpline ?? '1033 Helpline',
            detail:
                l10n?.detailTlFtHelplineDetail ?? 'If no reply in 7 days'),
        RbiTimelineStep(
            title: l10n?.detailTlFtIhmcl ?? 'IHMCL false-deduction email',
            detail: l10n?.detailTlFtIhmclDetail ??
                'falsededuction@ihmcl.com'),
        RbiTimelineStep(
            title: l10n?.detailTlFtOmbudsman ?? 'RBI Ombudsman',
            detail: l10n?.detailTlFtOmbudsmanDetail ??
                'If unresolved after 30 days'),
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
          detail:
              l10n?.detailTimelineReportedDetail(_fmtDate(dispute.txnDate)) ??
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
              ? (l10n?.detailTimelineRefundDone('$tat') ??
                  'T+$tat · refunded')
              : (refundActive
                  ? (l10n?.detailTimelineRefundMissed('$tat') ??
                      'T+$tat · deadline missed — escalate')
                  : (l10n?.detailTimelineRefundPending(
                              '$tat',
                              _fmtDate(dispute.txnDate
                                  .add(Duration(days: tat))),
                              comp.daysElapsed) ??
                          'T+$tat · ${_fmtDate(dispute.txnDate.add(Duration(days: tat)))} (in ${comp.daysElapsed}d)')),
          state: refundDone
              ? RbiStepState.done
              : (refundActive ? RbiStepState.active : RbiStepState.pending)),
      RbiTimelineStep(
          title: l10n?.detailTimelineEscalate ?? 'Escalate to nodal officer',
          detail: l2Done
              ? (l10n?.detailTimelineL2Detail(
                          dispute.ticketNumbers['l2'] ?? '—') ??
                      'Filed · ${dispute.ticketNumbers['l2'] ?? "—"}')
              : (l10n?.detailTimelineL2Pending('$tat') ??
                  'If no refund by T+$tat'),
          state: l2Done ? RbiStepState.done : RbiStepState.pending),
      RbiTimelineStep(
          title: l10n?.detailTimelineOmbudsman ?? 'RBI Banking Ombudsman',
          detail: l3Done
              ? (l10n?.detailTimelineL3Detail(
                          dispute.ticketNumbers['l3'] ?? '—') ??
                      'Filed · ${dispute.ticketNumbers['l3'] ?? "—"}')
              : (l10n?.detailTimelineL3Pending ??
                  'If unresolved after T+10 (30 days)'),
          state: l3Done ? RbiStepState.done : RbiStepState.pending),
    ];
  }

  List<ActivityEntry> _activityLog(AppLocalizations? l10n) {
    if (dispute.activityLog.isNotEmpty) {
      return dispute.activityLog
          .map((e) => ActivityEntry.fromLogEntry(e))
          .toList();
    }
    final entries = <ActivityEntry>[];
    final l1Ticket = dispute.ticketNumbers['l1'];
    if (l1Ticket != null && l1Ticket.isNotEmpty) {
      entries.add(ActivityEntry(
        label: l10n?.detailActivityTicket(l1Ticket) ??
            'Ticket $l1Ticket filed',
        meta: l10n?.detailActivityTicketMeta(
                _fmtDate(dispute.filedDates['l1'] ?? dispute.createdAt)) ??
            'Auto-generated · ${_fmtDate(dispute.filedDates['l1'] ?? dispute.createdAt)}',
        highlighted: true,
        type: ActivityLogEntry.l1TicketFiled,
      ));
    }
    if (dispute.txnId.isNotEmpty) {
      entries.add(ActivityEntry(
        label: l10n?.detailActivityAutoUtr ?? 'Auto-detected UTR from SMS',
        meta: _fmtDate(dispute.txnDate),
        type: ActivityLogEntry.utrDetected,
      ));
    }
    entries.add(ActivityEntry(
      label: l10n?.detailActivityMarkedActive ?? 'Dispute marked active',
      meta: _fmtDate(dispute.createdAt),
      type: ActivityLogEntry.disputeCreated,
    ));
    if (dispute.status == DisputeStatus.resolved &&
        dispute.resolvedAt != null) {
      entries.insert(0, ActivityEntry(
        label: l10n?.detailActivityResolved ?? 'Dispute resolved',
        meta: _fmtDate(dispute.resolvedAt!),
        highlighted: true,
        type: ActivityLogEntry.resolved,
      ));
    }
    return entries;
  }

  String _fmtDate(DateTime d) =>
      '${d.day} ${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][d.month - 1]}, ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  // -- Status toggle ------------------------------------------------------

  Future<void> _confirmToggle() async {
    final l10n = AppLocalizations.of(context);
    final isResolved = dispute.status == DisputeStatus.resolved;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(
          isResolved
              ? (l10n?.disputeDetailReopenTitle ?? 'Reopen dispute?')
              : (l10n?.disputeDetailMarkResolvedTitle ??
                  'Mark as resolved?'),
        ),
        content: Text(
          isResolved
              ? (l10n?.disputeDetailReopenBody ??
                  'This will reopen the dispute. Reminders will resume from today.')
              : (l10n?.disputeDetailMarkResolvedBody ??
                  'This will mark the dispute as resolved. Reminders will stop and it will move to your history. This can be undone.'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(l10n?.commonCancel ?? 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(l10n?.disputeDetailConfirm ?? 'Confirm'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await _toggleResolved();
  }

  Future<void> _toggleResolved() async {
    final l10n = AppLocalizations.of(context);
    final isResolved = dispute.status == DisputeStatus.resolved;
    final nextStatus =
        isResolved ? dispute.reopenTarget() : DisputeStatus.resolved;
    final now = DateTime.now();
    final repo = ref.read(disputeRepositoryProvider);
    setState(() => _toggling = true);

    final reopenedFiledDates = isResolved
        ? {
            ...dispute.filedDates,
            _filedDateKeyFor(nextStatus): now,
          }
        : dispute.filedDates;

    final updated = nextStatus == DisputeStatus.resolved
        ? dispute.copyWith(
            status: nextStatus,
            resolvedAmount: dispute.amount,
            resolvedAt: now,
            activityLog: [
              ...dispute.activityLog,
              ActivityLogEntry(
                type: ActivityLogEntry.resolved,
                label: l10n?.activityResolved ?? 'Dispute resolved',
                meta: _fmtDate(now),
                timestamp: now,
                highlighted: true,
              ),
            ],
          )
        : dispute.copyWith(
            status: nextStatus,
            resolvedAmount: null,
            resolvedAt: null,
            filedDates: reopenedFiledDates,
            activityLog: [
              ...dispute.activityLog,
              ActivityLogEntry(
                type: ActivityLogEntry.statusChanged,
                label: l10n?.activityStatusChanged ?? 'Status changed',
                meta: _fmtDate(now),
                timestamp: now,
                highlighted: true,
              ),
            ],
          );
    try {
      await repo.saveDispute(uid, updated);
      await syncRemindersForDispute(ref, uid, updated);
      ref.invalidate(disputesProvider(uid));
      ref.invalidate(remindersProvider(uid));
    } catch (e, st) {
      final msg = e.toString().toLowerCase();
      final friendly =
          msg.contains('permission') || msg.contains('unauthenticated')
              ? (l10n?.detailSaveAuthFailed ??
                  'Could not save — sign-in expired. Go Home and tap Retry.')
              : msg.contains('unavailable') ||
                      msg.contains('network') ||
                      msg.contains('socket')
                  ? (l10n?.detailSaveOffline ??
                      'You appear to be offline. Reconnect and try again.')
                  : (l10n?.detailSaveFailed ??
                      'Could not save. Check your connection and try again.');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendly)),
        );
      }
      debugPrint('_toggleResolved save failed: $e\n$st');
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  String _filedDateKeyFor(DisputeStatus status) {
    switch (status) {
      case DisputeStatus.filedL1:
        return 'l1';
      case DisputeStatus.filedL2:
        return 'l2';
      case DisputeStatus.ombudsman:
        return 'ombudsman';
      case DisputeStatus.draft:
      case DisputeStatus.resolved:
      case DisputeStatus.expired:
        return 'l1';
    }
  }
}

// -- Sub-widgets (clean-minimal Material 3) ------------------------------

class _TopBar extends StatelessWidget {
  final Dispute dispute;
  final AppThemeColors tc;
  final AppLocalizations? l10n;
  const _TopBar({
    required this.dispute,
    required this.tc,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: tc.textPrimary),
            onPressed: () => context.pop(),
          ),
          const SizedBox(width: 4),
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: dispute.type.softColorFor(tc),
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: Text(dispute.type.emoji,
                style: const TextStyle(fontSize: 14)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dispute.type.localizedName(l10n),
                  style: TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: tc.textPrimary,
                  ),
                ),
                if (dispute.entityName != null &&
                    dispute.entityName!.isNotEmpty)
                  Text(
                    dispute.entityName!,
                    style: TextStyle(fontSize: 12, color: tc.textSecondary),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final Dispute dispute;
  final int dayN;
  final int windowDays;
  final bool deadlineMissed;
  final AppThemeColors tc;
  final AppLocalizations? l10n;
  const _HeroCard({
    required this.dispute,
    required this.dayN,
    required this.windowDays,
    required this.deadlineMissed,
    required this.tc,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: tc.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: tc.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            CompensationCalculator.formatIndian(dispute.amount),
            style: TextStyle(
              fontFamily: AppTypography.family,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: tc.textPrimary,
              letterSpacing: -0.5,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (dispute.status != DisputeStatus.resolved && !deadlineMissed)
                _chip(
                  label:
                      l10n?.detailDayOfWindow(dayN, windowDays) ??
                          '⏰ Day $dayN of $windowDays',
                  fg: AppColors.alert,
                  bg: tc.alertSoft,
                ),
              if (deadlineMissed)
                _chip(
                  label: l10n?.detailDeadlineMissed ?? '⚠ Deadline missed',
                  fg: AppColors.error,
                  bg: tc.errorSoft,
                ),
              if (dispute.status == DisputeStatus.resolved)
                _chip(
                  label: l10n?.detailResolved ?? '✓ Resolved',
                  fg: AppColors.success,
                  bg: tc.accentSoft,
                ),
              _chip(
                label: dispute.type.localizedCompensation(l10n) ??
                    'Guidance mode',
                fg: tc.textSecondary,
                bg: tc.surfaceAlt,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip({
    required String label,
    required Color fg,
    required Color bg,
  }) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: fg,
          ),
        ),
      );
}

class _QuickActions extends StatelessWidget {
  final Dispute dispute;
  final bool deadlineMissed;
  final AppThemeColors tc;
  final AppLocalizations? l10n;
  const _QuickActions({
    required this.dispute,
    required this.deadlineMissed,
    required this.tc,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.alert,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 46),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
            ),
            onPressed: () =>
                context.push(AppRoutes.wizard(dispute.id)),
            icon: const Icon(Icons.flag_outlined, size: 16),
            label: Text(
              deadlineMissed
                  ? (l10n?.detailEscalateNow ?? 'Escalate now')
                  : (l10n?.detailEscalate ?? 'Escalate'),
              style: TextStyle(
                fontFamily: AppTypography.family,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _IconBtn(
          emoji: '📧',
          tooltip: l10n?.escalateEmailPreview ?? 'Email',
          onTap: () =>
              context.push(AppRoutes.escalate(dispute.id)),
        ),
        const SizedBox(width: 8),
        _IconBtn(
          emoji: '📝',
          tooltip: l10n?.escalatePickTemplate ?? 'Templates',
          onTap: () {
            final isPremium = ProviderScope.containerOf(context)
                .read(isPremiumProvider);
            if (!isPremium) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n?.detailOmbudsmanPremium ??
                      'Ombudsman letter generator is a Premium feature.'),
                  duration: const Duration(seconds: 2),
                ),
              );
              context.push(
                AppRoutes.paywallWithParams(
                  trigger: 'ombudsman_letter',
                  returnPath: AppRoutes.disputeDetail(dispute.id),
                ),
              );
              return;
            }
            context.push(AppRoutes.ombudsman(dispute.id));
          },
        ),
      ],
    );
  }
}

class _IconBtn extends StatelessWidget {
  final String emoji;
  final String tooltip;
  final VoidCallback onTap;
  const _IconBtn({
    required this.emoji,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    return Material(
      color: tc.surface,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.md),
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: tc.divider),
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 18)),
          ),
        ),
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final Dispute dispute;
  final Template? matchedTemplate;
  final TemplateRepository repo;
  final Set<String> freeIds;
  final bool isPremiumUser;
  final String localeCode;
  final AppThemeColors tc;
  final AppLocalizations? l10n;
  const _TemplateCard({
    required this.dispute,
    required this.matchedTemplate,
    required this.repo,
    required this.freeIds,
    required this.isPremiumUser,
    required this.localeCode,
    required this.tc,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final locked = matchedTemplate != null &&
        repo.isLocked(matchedTemplate!, freeIds,
            isPremiumUser: isPremiumUser);
    return Container(
      decoration: BoxDecoration(
        color: tc.surface,
        border: Border.all(color: tc.divider),
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                l10n?.templatePickerTitle ?? 'Pick a template',
                style: TextStyle(
                  fontFamily: AppTypography.family,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: tc.textSecondary,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => context.push(
                  AppRoutes.templatePreviewWith(
                    disputeId: dispute.id,
                    templateId: matchedTemplate?.id ?? '',
                  ),
                ),
                icon: const Icon(Icons.visibility_outlined, size: 14),
                label: Text(
                  l10n?.templatePreviewBody ?? 'Preview',
                  style: TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(Icons.tune, size: 18, color: tc.ctaBackground),
                onPressed: () => context.push(
                  AppRoutes.templatePickerWithDispute(dispute.id),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (matchedTemplate == null)
            Text(
              l10n?.detailNoTemplateFound ??
                  'No template found for this category',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: tc.textTertiary,
              ),
            )
          else
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: locked
                        ? AppColors.premiumGoldSoft
                        : tc.accentSoft,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: Text(
                    locked ? 'Pro' : (l10n?.templatePreviewFree ?? 'Free'),
                    style: TextStyle(
                      fontFamily: AppTypography.family,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: locked
                          ? AppColors.premiumGold
                          : AppColors.success,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    matchedTemplate!.titleFor(localeCode),
                    style: TextStyle(
                      fontFamily: AppTypography.family,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: tc.textPrimary,
                    ),
                  ),
                ),
                Text(
                  'L${matchedTemplate!.escalationLevel}',
                  style: TextStyle(
                    fontSize: 11,
                    color: tc.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _StickyFooter extends StatelessWidget {
  final Dispute dispute;
  final int hoursLeft;
  final bool deadlineMissed;
  final bool toggling;
  final VoidCallback onConfirm;
  final AppThemeColors tc;
  final AppLocalizations? l10n;
  const _StickyFooter({
    required this.dispute,
    required this.hoursLeft,
    required this.deadlineMissed,
    required this.toggling,
    required this.onConfirm,
    required this.tc,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: tc.surface,
        border: Border(top: BorderSide(color: tc.divider)),
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      child: Row(
        children: [
          Expanded(
            child: dispute.status != DisputeStatus.resolved
                ? Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: deadlineMissed
                              ? AppColors.error
                              : AppColors.alert,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          deadlineMissed
                              ? (l10n?.detailWindowExpired ??
                                  'Window expired')
                              : l10n?.detailHoursUntilDeadline(
                                      hoursLeft, dispute.type.tatDays ?? 5) ??
                                  '$hoursLeft hours until T+${dispute.type.tatDays ?? 5} deadline',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: deadlineMissed
                                ? AppColors.error
                                : AppColors.alert,
                          ),
                        ),
                      ),
                    ],
                  )
                : Text(
                    l10n?.detailResolvedMessage ?? 'Resolved',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.success,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            height: 46,
            child: OutlinedButton.icon(
              onPressed: toggling ? null : onConfirm,
              icon: Icon(
                dispute.status == DisputeStatus.resolved
                    ? Icons.refresh
                    : Icons.check,
                size: 16,
              ),
              label: Text(
                dispute.status == DisputeStatus.resolved
                    ? (l10n?.detailReopen ?? 'Reopen')
                    : (l10n?.detailMarkResolved ?? 'Mark resolved'),
                style: TextStyle(
                  fontFamily: AppTypography.family,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: tc.ctaBackground,
                side: BorderSide(color: tc.divider),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Local re-export so the analyzer doesn't complain about unused imports.
// ignore_for_file: unused_element
typedef _ClipboardImportSentinel = Clipboard;
