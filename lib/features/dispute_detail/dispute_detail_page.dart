import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:refund_radar/core/router/app_routes.dart';
import 'package:refund_radar/core/providers/app_state_provider.dart';
import 'package:refund_radar/core/providers/auth_provider.dart';
import 'package:refund_radar/core/providers/dispute_provider.dart';
import 'package:refund_radar/core/providers/theme_provider.dart';
import 'package:refund_radar/core/theme/app_tokens.dart';
import 'package:refund_radar/core/theme/app_theme_colors.dart';
import 'package:refund_radar/data/extensions/dispute_type_display.dart';
import 'package:refund_radar/data/models/activity_log_entry.dart';
import 'package:refund_radar/data/models/dispute.dart';
import 'package:refund_radar/data/models/template.dart';
import 'package:refund_radar/data/repositories/reminder_repository.dart';
import 'package:refund_radar/data/repositories/rules_engine_repository.dart';
import 'package:refund_radar/data/repositories/template_repository.dart';
import 'package:refund_radar/features/templates/template_library_page.dart';
import 'package:refund_radar/l10n/app_localizations.dart';
import 'package:refund_radar/services/compensation_calculator.dart';
import 'package:refund_radar/shared/widgets/app_back_button.dart';
import 'package:refund_radar/shared/widgets/rbi_timeline.dart';
import 'package:refund_radar/shared/widgets/activity_log.dart';
import 'package:refund_radar/shared/widgets/branded_error_banner.dart';
import 'package:refund_radar/shared/utils/error_mapper.dart';
import 'package:refund_radar/shared/widgets/skeleton.dart';
import 'package:refund_radar/shared/widgets/status_pill.dart';

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
                message: l10n?.commonCouldNotSignIn ?? 'Could not sign in. Tap retry.',
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
                message: l10n?.commonDisputeNotFound ?? 'Dispute not found.',
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

  /// HI-4: re-entrancy guard for the Mark Resolved / Reopen action. While a
  /// save is in flight the action button is disabled so a rapid double-tap
  /// can't enqueue duplicate writes or interleave two copyWith chains.
  bool _toggling = false;

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final tc = AppThemeColors.of(context);
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

    // F3: template picker inputs — used by the template card section.
    final templatesAsync = ref.watch(templatesProvider);
    final rulesAsync = ref.watch(rulesEngineProvider);
    final freeIds =
        rulesAsync.asData?.value.freeTemplateIds.toSet() ?? const <String>{};
    final isPremiumUser = ref.watch(isPremiumProvider);
    final localeCode = ref.watch(localeProvider).languageCode;
    final repo = ref.read(templateRepositoryProvider);
    // Resolve the currently-selected template (user pick wins over auto-match).
    Template? matchedTemplate;
    final allTemplates = templatesAsync.asData?.value ?? const <Template>[];
    if (_selectedTemplateId != null) {
      for (final t in allTemplates) {
        if (t.id == _selectedTemplateId) {
          matchedTemplate = t;
          break;
        }
      }
    }
    matchedTemplate ??= _matchDisputeTemplate(allTemplates, dispute, repo, freeIds, isPremiumUser);

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
                      dispute.type.localizedName(l10n),
                      style: TextStyle(
                        fontFamily: AppTypography.family,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: tc.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _headerSubtitle(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: tc.textSecondary,
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
                      color: dispute.type.softColorFor(tc),
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
                          style: TextStyle(
                            fontFamily: AppTypography.family,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: tc.ctaBackground,
                            letterSpacing: -0.5,
                            fontFeatures: const [FontFeature.tabularFigures()],
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
                                  color: tc.alertSoft,
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
                                  color: tc.errorSoft,
                                  borderRadius:
                                      BorderRadius.circular(AppRadii.pill),
                                ),
                                child: Text(
                                  l10n?.detailDeadlineMissed ?? '⚠ Deadline missed',
                                  style: const TextStyle(
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
                                  color: tc.accentSoft,
                                  borderRadius:
                                      BorderRadius.circular(AppRadii.pill),
                                ),
                                child: Text(
                                  l10n?.detailResolved ?? '✓ Resolved',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.success,
                                  ),
                                ),
                              ),
                            const SizedBox(width: 8),
                            Text(
                              dispute.type.localizedCompensation(l10n) ??
                                  'Guidance mode',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: tc.textSecondary,
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
                headerLabel: _timelineHeader(l10n),
                steps: _timelineSteps(comp, l10n),
              ),
              const SizedBox(height: 14),
              // Escalate row
              if (dispute.type != DisputeType.wrongTransfer) ...[
                Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        label: deadlineMissed ? (l10n?.detailEscalateNow ?? 'Escalate now') : (l10n?.detailEscalate ?? 'Escalate'),
                        color: AppColors.alert,
                        onTap: () => context.push(AppRoutes.wizard(dispute.id)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _IconAction(
                      emoji: '📧',
                      onTap: () => context.push(AppRoutes.escalate(dispute.id)),
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
                            SnackBar(
                              content: Text(
                                  l10n?.detailOmbudsmanPremium ?? 'Ombudsman letter generator is a Premium feature.'),
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
                ),
                const SizedBox(height: 14),
              ],
              // F3: template card — shows the auto-matched (or user-picked)
              // L1/L2 template for this dispute, with a pencil icon to open
              // the same Free/Pro picker as the escalate screen.
              if (dispute.type != DisputeType.wrongTransfer) ...[
                _buildTemplateCard(
                  context,
                  tc: tc,
                  l10n: l10n,
                  matchedTemplate: matchedTemplate,
                  templates: allTemplates,
                  freeIds: freeIds,
                  isPremiumUser: isPremiumUser,
                  localeCode: localeCode,
                  repo: repo,
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
          decoration: BoxDecoration(
            color: tc.surface,
            border: Border(
              top: BorderSide(color: tc.divider, width: 1),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: dispute.status != DisputeStatus.resolved
                    ? RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: tc.textSecondary,
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
                                  ? (l10n?.detailWindowExpired ?? 'Window expired')
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
                    : Text(
                        l10n?.detailResolvedMessage ?? 'This dispute is resolved.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: tc.textSecondary,
                        ),
                      ),
              ),
              _ActionButton(
                label: dispute.status == DisputeStatus.resolved
                    ? (l10n?.detailReopen ?? 'Reopen')
                    : (l10n?.detailMarkResolved ?? 'Mark resolved'),
                color: tc.surfaceAlt,
                textColor: tc.ctaBackground,
                onTap: _toggling
                    ? null
                    : () => _confirmToggle(ref),
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

  String _timelineHeader(AppLocalizations? l10n) =>
      dispute.type == DisputeType.fastag
          ? (l10n?.detailTimelineFastagHeader ??
              'FASTag timeline (30-day window)')
          : dispute.type == DisputeType.bankCharge
              ? (l10n?.detailTimelineBankHeader ??
                  'Bank timeline (30-day window)')
              : (l10n?.detailTimelineRbiHeader ?? 'RBI timeline (T-day = 0)');

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
            detail:
                l10n?.detailTlFtIhmclDetail ?? 'falsededuction@ihmcl.com'),
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
    // Prefer the persisted activity log (Track G) when present — this
    // includes dispute_created, escalation_email_sent, template_used,
    // resolved, status_changed, etc. written at each action point.
    if (dispute.activityLog.isNotEmpty) {
      return dispute.activityLog
          .map((e) => ActivityEntry.fromLogEntry(e))
          .toList();
    }

    // Legacy / migration fallback: old disputes have an empty persisted
    // log, so surface the historically-computed events so the card is
    // never blank for existing users.
    final entries = <ActivityEntry>[];
    final l1Ticket = dispute.ticketNumbers['l1'];
    if (l1Ticket != null && l1Ticket.isNotEmpty) {
      entries.add(ActivityEntry(
        label: l10n?.detailActivityTicket(l1Ticket) ?? 'Ticket $l1Ticket filed',
        meta: l10n?.detailActivityTicketMeta(_fmtDate(dispute.filedDates['l1'] ?? dispute.createdAt)) ??
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
    if (dispute.status == DisputeStatus.resolved && dispute.resolvedAt != null) {
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

  /// F3 — auto-match a template for the dispute's category. Delegates to
  /// the shared [TemplateRepository.matchForCategory] (ME-7) so the
  /// dispute-detail preview stays in lockstep with the escalate auto-match.
  Template? _matchDisputeTemplate(
    List<Template> templates,
    Dispute d,
    TemplateRepository repo,
    Set<String> freeIds,
    bool isPremiumUser,
  ) =>
      repo.matchForCategory(
        templates,
        d.type,
        freeIds,
        isPremiumUser: isPremiumUser,
      );

  /// F3 — the template card shown on the dispute detail screen.
  Widget _buildTemplateCard(
    BuildContext context, {
    required AppThemeColors tc,
    required AppLocalizations? l10n,
    required Template? matchedTemplate,
    required List<Template> templates,
    required Set<String> freeIds,
    required bool isPremiumUser,
    required String localeCode,
    required TemplateRepository repo,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tc.surface,
        border: Border.all(color: tc.divider, width: 1),
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'TEMPLATE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: tc.textSecondary,
                  ),
                ),
              ),
              Tooltip(
                message: l10n?.escalateEditTemplate ?? 'Pick template',
                child: IconButton(
                  onPressed: templates.isEmpty
                      ? null
                      : () => _showTemplatePickerForDispute(
                            context,
                            templates,
                            repo,
                            freeIds,
                            isPremiumUser,
                            localeCode,
                            l10n,
                          ),
                  padding: const EdgeInsets.all(12),
                  splashRadius: 24,
                  icon: Icon(
                    Icons.edit_outlined,
                    size: 18,
                    color: tc.ctaBackground,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (matchedTemplate == null)
            Text(
              l10n?.detailNoTemplateFound ?? 'No template found for this category',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: tc.textTertiary,
              ),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    matchedTemplate.titleFor(localeCode),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: tc.textPrimary,
                    ),
                  ),
                ),
                Text(
                  'Level ${matchedTemplate.escalationLevel} · ${matchedTemplate.category}',
                  style: TextStyle(
                    fontSize: 11,
                    color: tc.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              (_selectedTemplateId == null
                  ? 'Auto-matched (tap pencil to change)'
                  : 'Custom template') +
                  (matchedTemplate.isPremium &&
                          !isPremiumUser &&
                          !freeIds.contains(matchedTemplate.id)
                      ? ' · Pro'
                      : ''),
              style: TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: tc.textTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// F3 — opens the Free/Pro template picker for this dispute (same
  /// structure as the escalate-page picker). Selecting a template updates
  /// local state (preview-only; not persisted to the dispute record).
  void _showTemplatePickerForDispute(
    BuildContext context,
    List<Template> templates,
    TemplateRepository repo,
    Set<String> freeIds,
    bool isPremiumUser,
    String localeCode,
    AppLocalizations? l10n,
  ) {
    final tc = AppThemeColors.of(context);
    // ME-7: partition via the shared helper so free/pro buckets match
    // the escalate picker exactly.
    final buckets = repo.splitForCategory(
      templates,
      dispute.type,
      freeIds,
      isPremiumUser: isPremiumUser,
    );
    final freeTemplates = buckets.free;
    final proTemplates = buckets.pro;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: tc.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        final sheetTc = AppThemeColors.of(sheetCtx);
        final sheetL10n = AppLocalizations.of(sheetCtx);
        return SafeArea(
          child: DefaultTabController(
            length: 2,
            child: SizedBox(
              height: MediaQuery.of(sheetCtx).size.height * 0.65,
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    decoration: BoxDecoration(
                      color: sheetTc.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        sheetL10n?.escalatePickTemplate ??
                            'Pick escalation template',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: sheetTc.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  TabBar(
                    tabs: [
                      Tab(text: 'Free (${freeTemplates.length})'),
                      Tab(
                        text:
                            '${sheetL10n?.templateProBadge ?? 'Pro'} (${proTemplates.length})',
                      ),
                    ],
                    labelColor: AppColors.accent,
                    unselectedLabelColor: sheetTc.textTertiary,
                    indicatorColor: AppColors.accent,
                    indicatorSize: TabBarIndicatorSize.label,
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _disputeTemplateList(
                          sheetCtx,
                          freeTemplates,
                          repo,
                          freeIds,
                          isPremiumUser,
                          localeCode,
                          sheetL10n,
                          isProTab: false,
                        ),
                        _disputeTemplateList(
                          sheetCtx,
                          proTemplates,
                          repo,
                          freeIds,
                          isPremiumUser,
                          localeCode,
                          sheetL10n,
                          isProTab: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// F3 helper — renders a Free or Pro tab for the dispute-detail picker.
  Widget _disputeTemplateList(
    BuildContext context,
    List<Template> templates,
    TemplateRepository repo,
    Set<String> freeIds,
    bool isPremiumUser,
    String localeCode,
    AppLocalizations? l10n, {
    required bool isProTab,
  }) {
    final tc = AppThemeColors.of(context);
    if (templates.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            isProTab
                ? 'No Pro templates for this category'
                : 'No free templates for this category',
            style: TextStyle(color: tc.textTertiary, fontSize: 14),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: templates.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final t = templates[index];
        final isSelected = t.id == _selectedTemplateId;
        final isLocked = isProTab &&
            repo.isLocked(t, freeIds, isPremiumUser: isPremiumUser);

        return InkWell(
          onTap: isLocked
              ? () {
                  Navigator.pop(context);
                  context.push(
                    AppRoutes.paywallWithParams(
                      trigger: 'template_locked',
                      returnPath: AppRoutes.disputeDetail(dispute.id),
                      templateId: t.id,
                      templateTitle: t.titleFor(localeCode),
                    ),
                  );
                }
              : () {
                  setState(() => _selectedTemplateId = t.id);
                  Navigator.pop(context);
                },
          borderRadius: BorderRadius.circular(AppRadii.lg),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(
                color: isSelected ? AppColors.accent : tc.divider,
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(AppRadii.lg),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        t.titleFor(localeCode),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isLocked ? tc.textTertiary : tc.textPrimary,
                        ),
                      ),
                    ),
                    if (isLocked)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: StatusPill(
                          label: l10n?.templateProBadge ?? 'Pro',
                          fg: AppColors.premiumGold,
                          bg: tc.premiumGoldSoft,
                          prefix: '🔒',
                        ),
                      ),
                    if (isSelected)
                      const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Icon(
                          Icons.check_circle,
                          size: 20,
                          color: AppColors.accent,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Level ${t.escalationLevel} · ${t.category}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isLocked ? tc.textTertiary : tc.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                if (isLocked)
                  _blurredPreview(
                    filledTemplateBody(t, localeCode, dispute),
                    tc,
                  )
                else
                  Text(
                    filledTemplateBody(t, localeCode, dispute),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: tc.textSecondary,
                      height: 1.4,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// F3 helper — fades the bottom of a locked template preview.
  Widget _blurredPreview(String body, AppThemeColors tc) {
    return ClipRect(
      child: Stack(
        children: [
          Text(
            body,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: tc.textSecondary,
              height: 1.4,
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 20,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    tc.surface.withValues(alpha: 0),
                    tc.surface,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Task 9.5 — show a confirmation dialog before toggling the dispute status
  /// (Mark Resolved / Reopen). Prevents accidental status changes and sets
  /// user expectation about reminders stopping/resuming.
  Future<void> _confirmToggle(WidgetRef ref) async {
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
    if (confirmed == true && mounted) await _toggleResolved(ref);
  }

  Future<void> _toggleResolved(WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final isResolved = dispute.status == DisputeStatus.resolved;
    final nextStatus =
        isResolved ? dispute.reopenTarget() : DisputeStatus.resolved;
    final now = DateTime.now();
    final repo = ref.read(disputeRepositoryProvider);

    // HI-4: re-entrancy guard — disable the action button while saving.
    setState(() => _toggling = true);

    // HI-2: on reopen, refresh the filedDate for the target stage so the
    // reminder generator schedules follow-ups from "today" rather than the
    // (possibly months-old) original filing date. Resolved→resolved is a
    // no-op so no date reset is needed on the resolve path.
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
      // HI-5: capture the freshly saved Dispute so the detail body shows the
      // new status/activity immediately rather than staling on the snapshot
      // taken at navigation time. We do NOT call setState with `updated`
      // (which lacks the server-assigned id for new rows) — the
      // `disputesProvider` invalidate below is the source of truth for the
      // next rebuild, and `_toggling` is reset here so the button recovers.
      await repo.saveDispute(uid, updated);
      await syncRemindersForDispute(ref, uid, updated);
      ref.invalidate(disputesProvider(uid));
      ref.invalidate(remindersProvider(uid));
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  /// Maps a [DisputeStatus] to its `filedDates` map key, used by
  /// [_toggleResolved] to reset the anchor date on reopen.
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

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final Color? textColor;
  final VoidCallback? onTap;
  const _ActionButton({
    required this.label,
    required this.color,
    required this.onTap,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
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
              color: textColor ?? tc.ctaForeground,
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
    final tc = AppThemeColors.of(context);
    return Material(
      color: tc.surfaceAlt,
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
