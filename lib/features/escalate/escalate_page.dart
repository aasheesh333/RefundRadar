import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:refund_radar/core/providers/app_state_provider.dart';
import 'package:refund_radar/core/providers/auth_provider.dart';
import 'package:refund_radar/core/providers/dispute_provider.dart';
import 'package:refund_radar/core/providers/theme_provider.dart';
import 'package:refund_radar/core/theme/app_theme_colors.dart';
import 'package:refund_radar/core/theme/app_tokens.dart';
import 'package:refund_radar/core/utils/url_launcher_helper.dart';
import 'package:refund_radar/data/constants/bank_catalog.dart';
import 'package:refund_radar/data/models/activity_log_entry.dart';
import 'package:refund_radar/data/models/dispute.dart';
import 'package:refund_radar/data/models/template.dart';
import 'package:refund_radar/data/repositories/rules_engine_repository.dart';
import 'package:refund_radar/data/repositories/template_repository.dart';
import 'package:refund_radar/features/escalate/widgets/escalate_post_send_dialog.dart';
import 'package:refund_radar/features/escalate/widgets/escalate_template_picker.dart';
import 'package:refund_radar/features/escalate/widgets/footer_button.dart';
import 'package:refund_radar/features/escalate/widgets/recipient_row.dart';
import 'package:refund_radar/features/templates/template_library_page.dart';
import 'package:refund_radar/l10n/app_localizations.dart';
import 'package:refund_radar/services/compensation_calculator.dart';
import 'package:refund_radar/shared/widgets/app_back_button.dart';
import 'package:refund_radar/shared/widgets/branded_error_banner.dart';
import 'package:refund_radar/shared/utils/error_mapper.dart';
import 'package:refund_radar/shared/widgets/skeleton.dart';
import 'package:refund_radar/shared/widgets/toggle_switch.dart';

/// Escalate page — mockup Screen 8. Dark green hero with "Maximum penalty
/// you can claim" → ₹{refund+comp}, send-to list with selected Nodal Officer
/// + toggleable "CC RBI Ombudsman", auto-drafted email preview, sticky
/// footer with Edit + "Send escalation →".
class EscalatePage extends ConsumerStatefulWidget {
  final String disputeId;
  const EscalatePage({super.key, required this.disputeId});

  @override
  ConsumerState<EscalatePage> createState() => _EscalatePageState();
}

class _EscalatePageState extends ConsumerState<EscalatePage>
    with TickerProviderStateMixin {
  bool _ccOmbudsman = true;
  String? _selectedTemplateId;
  late final AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _selectTemplate(String? id) => setState(() => _selectedTemplateId = id);

  /// Staggered entrance wrapper — 80ms stagger between cards, fade + slight
  /// upward slide while constraining the overall interval to ~300ms each.
  Widget _staggeredBox(int index, Widget child) {
    final start = (index * 0.08).clamp(0.0, 0.8);
    final end = start + 0.3;
    return FadeTransition(
      opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _animController,
          curve: Interval(start, end, curve: Curves.easeOutCubic),
        ),
      ),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.05),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: _animController,
            curve: Interval(start, end, curve: Curves.easeOutCubic),
          ),
        ),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    final uidAsync = ref.watch(userIdProvider);
    return Scaffold(
      backgroundColor: tc.bg,
      body: SafeArea(
        child: uidAsync.when(
          loading: () => const SkeletonList(itemCount: 4),
          error: (e, _) => BrandedErrorBanner(
            message: friendlyError(e),
            detail: errorDetail(e),
            onRetry: () => ref.invalidate(userIdProvider),
          ),
          data: (uid) {
            if (uid == null || uid.isEmpty) {
              return BrandedErrorBanner(
                message: 'Could not sign in. Tap retry.',
                onRetry: () => ref.invalidate(userIdProvider),
              );
            }
            final disputesAsync = ref.watch(disputesProvider(uid));
            return disputesAsync.when(
              data: (disputes) {
                Dispute? dispute;
                for (final d in disputes) {
                  if (d.id == widget.disputeId) {
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
                return _Body(
                  dispute: dispute,
                  ccOmbudsman: _ccOmbudsman,
                  onToggleCc: (v) => setState(() => _ccOmbudsman = v),
                  selectedTemplateId: _selectedTemplateId,
                  onSelectTemplate: _selectTemplate,
                  staggeredBox: _staggeredBox,
                );
              },
              loading: () => const SkeletonList(itemCount: 4),
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

class _Body extends ConsumerWidget {
  final Dispute dispute;
  final bool ccOmbudsman;
  final ValueChanged<bool> onToggleCc;
  final String? selectedTemplateId;
  final void Function(String?) onSelectTemplate;
  final Widget Function(int index, Widget child) staggeredBox;
  const _Body({
    required this.dispute,
    required this.ccOmbudsman,
    required this.onToggleCc,
    required this.selectedTemplateId,
    required this.onSelectTemplate,
    required this.staggeredBox,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tc = AppThemeColors.of(context);
    final comp = CompensationCalculator.compute(dispute);
    final refund = dispute.amount;
    final maxClaim = refund + comp.compensationDue;
    final deadlineMissed = comp.isExpired;
    final templatesAsync = ref.watch(templatesProvider);
    final locale = ref.watch(localeProvider);
    final localeCode = locale.languageCode;
    final rulesAsync = ref.watch(rulesEngineProvider);
    final freeIds = rulesAsync.asData?.value.freeTemplateIds.map((s) => s).toSet() ?? const <String>{};
    final isPremiumUser = ref.watch(isPremiumProvider);

    return templatesAsync.when(
      loading: () => const SkeletonList(itemCount: 4),
      error: (e, _) => BrandedErrorBanner(
        message: friendlyError(e),
        detail: errorDetail(e),
        onRetry: () => ref.invalidate(templatesProvider),
      ),
      data: (templates) {
        // User-picked template wins; fall back to auto-matched level-2 template.
        Template? picked;
        if (selectedTemplateId != null) {
          for (final t in templates) {
            if (t.id == selectedTemplateId) {
              picked = t;
              break;
            }
          }
        }
        final repo = ref.read(templateRepositoryProvider);
        final match = picked ??
            _matchEscalationTemplate(
              templates,
              dispute,
              repo,
              freeIds,
              isPremiumUser,
            );
        return _buildBody(
          context,
          ref,
          l10n: l10n,
          tc: tc,
          comp: comp,
          refund: refund,
          maxClaim: maxClaim,
          deadlineMissed: deadlineMissed,
          localeCode: localeCode,
          matchedTemplate: match,
          templates: templates,
          freeIds: freeIds,
          isPremiumUser: isPremiumUser,
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref, {
    required AppLocalizations? l10n,
    required AppThemeColors tc,
    required CompensationResult comp,
    required double refund,
    required double maxClaim,
    required bool deadlineMissed,
    required String localeCode,
    required Template? matchedTemplate,
    required List<Template> templates,
    required Set<String> freeIds,
    required bool isPremiumUser,
  }) {
    final deadlineDays = deadlineMissed
        ? 0
        : comp.deadlineDate.difference(DateTime.now()).inDays;
    return Column(
      children: [
        Expanded(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(context, tc, l10n, deadlineMissed)),
              SliverList(
                delegate: SliverChildListDelegate([
                  staggeredBox(0, _buildHero(tc, l10n, comp, refund, maxClaim, deadlineMissed, deadlineDays)),
                  const SizedBox(height: 16),
                  staggeredBox(1, _buildSendToCard(context, tc, l10n, dispute, ccOmbudsman, onToggleCc)),
                  const SizedBox(height: 16),
                  staggeredBox(
                    2,
                    _buildEmailPreviewCard(
                      context,
                      ref,
                      tc: tc,
                      l10n: l10n,
                      dispute: dispute,
                      ccOmbudsman: ccOmbudsman,
                      matchedTemplate: matchedTemplate,
                      localeCode: localeCode,
                      templates: templates,
                      freeIds: freeIds,
                      isPremiumUser: isPremiumUser,
                      repo: ref.read(templateRepositoryProvider),
                    ),
                  ),
                  if (deadlineMissed) ...[
                    const SizedBox(height: 16),
                    staggeredBox(3, _buildAmberCallout(tc, l10n, comp)),
                  ],
                  const SizedBox(height: 20),
                ]),
              ),
            ],
          ),
        ),
        _buildFooter(
          tc,
          context,
          ref,
          l10n,
          matchedTemplate,
          localeCode,
          repo: ref.read(templateRepositoryProvider),
          freeIds: freeIds,
          isPremiumUser: isPremiumUser,
        ),
      ],
    );
  }

  Widget _buildHeader(
    BuildContext context,
    AppThemeColors tc,
    AppLocalizations? l10n,
    bool deadlineMissed,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
      child: Row(
        children: [
          AppBackButton(onTap: () => context.pop()),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n?.escalateAppBarTitle ?? 'Escalate',
                  style: TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: tc.textPrimary,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '${l10n?.escalateNodalOfficer ?? 'Nodal Officer'} · ${dispute.entityName ?? "your bank"}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: tc.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (deadlineMissed)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: tc.alertSoft,
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
              child: Text(
                l10n?.escalateT5Missed ?? '⚠ T+5 missed',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.alert,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHero(
    AppThemeColors tc,
    AppLocalizations? l10n,
    CompensationResult comp,
    double refund,
    double maxClaim,
    bool deadlineMissed,
    int deadlineDays,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: tc.ctaBackground,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TOTAL CLAIMABLE',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: tc.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            CompensationCalculator.formatIndian(maxClaim),
            style: TextStyle(
              fontFamily: AppTypography.family,
              fontSize: 30,
              fontWeight: FontWeight.w800,
              height: 1,
              color: tc.ctaForeground,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                deadlineMissed ? Icons.warning_amber_rounded : Icons.access_time,
                size: 14,
                    color: deadlineMissed
                        ? AppColors.alert
                        : tc.ctaForeground.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 4),
              Text(
                deadlineMissed
                    ? 'T+5 deadline missed — claim full penalty'
                    : 'T+5 deadline in $deadlineDays days',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: deadlineMissed
                      ? AppColors.alert
                      : tc.ctaForeground.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            refund == 0
                ? (l10n?.escalateNoAmount ??
                      'No transaction amount on this dispute')
                : (l10n?.escalateRefundPlusComp(
                        CompensationCalculator.formatIndian(refund),
                        CompensationCalculator.formatIndian(
                          comp.compensationDue,
                        ),
                        comp.daysElapsed,
                      ) ??
                      '${CompensationCalculator.formatIndian(refund)} refund + ${CompensationCalculator.formatIndian(comp.compensationDue)} comp (${comp.daysElapsed} days × ₹100/day)'),
            style: TextStyle(
              fontSize: 11,
              color: tc.ctaForeground.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSendToCard(
    BuildContext context,
    AppThemeColors tc,
    AppLocalizations? l10n,
    Dispute dispute,
    bool ccOmbudsman,
    ValueChanged<bool> onToggleCc,
  ) {
    return _card(
      context,
      label: l10n?.escalateSendTo ?? 'SEND TO',
      children: [
        RecipientRow(
          emojiTile: '🎯',
          bgTileColor: tc.alertSoft,
          title: l10n?.escalateNodalOfficer ?? 'Nodal Officer',
          detail:
              l10n?.escalateSlaDays(_nodalEmail(dispute)) ??
              '${_nodalEmail(dispute)} · SLA 10d',
          selected: true,
        ),
        const SizedBox(height: 8),
        RecipientRow(
          emojiTile: '✉',
          bgTileColor: tc.surfaceAlt,
          title: l10n?.escalateCcOmbudsman ?? 'CC RBI Ombudsman',
          detail: 'crpc@rbi.org.in',
          selected: ccOmbudsman,
          trailing: ToggleSwitch(value: ccOmbudsman, onChanged: onToggleCc),
        ),
      ],
    );
  }

  Widget _buildEmailPreviewCard(
    BuildContext context,
    WidgetRef ref, {
    required AppThemeColors tc,
    required AppLocalizations? l10n,
    required Dispute dispute,
    required bool ccOmbudsman,
    required Template? matchedTemplate,
    required String localeCode,
    required List<Template> templates,
    required Set<String> freeIds,
    required bool isPremiumUser,
    required TemplateRepository repo,
  }) {
    final isMatchLocked = matchedTemplate != null &&
        repo.isLocked(matchedTemplate, freeIds, isPremiumUser: isPremiumUser);
    return _card(
      context,
      label: l10n?.escalateEmailPreview ?? 'EMAIL PREVIEW',
      labelAction: Tooltip(
        message: l10n?.escalateEditTemplate ?? 'Pick template',
        child: InkWell(
          onTap: () => EscalateTemplatePicker.show(
            context,
            dispute: dispute,
            templates: templates,
            localeCode: localeCode,
            freeIds: freeIds,
            isPremiumUser: isPremiumUser,
            repo: repo,
            selectedTemplateId: selectedTemplateId,
            onSelectTemplate: onSelectTemplate,
          ),
          borderRadius: BorderRadius.circular(AppRadii.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 4,
              vertical: 2,
            ),
            child: Icon(
              Icons.edit_outlined,
              size: 18,
              color: AppColors.accent,
            ),
          ),
        ),
      ),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: tc.surfaceAlt,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            l10n?.escalateEmailSubject(dispute.txnId) ??
                'Subject: Escalation — UTR ${dispute.txnId}',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: tc.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${l10n?.escalateToLabel ?? 'TO:'} ${_nodalEmail(dispute)}',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: tc.textPrimary,
          ),
        ),
        if (ccOmbudsman)
          Text(
            '${l10n?.escalateCcLabel ?? 'CC:'} crpc@rbi.org.in',
            style: TextStyle(fontSize: 11, color: tc.textSecondary),
          ),
        const SizedBox(height: 10),
        if (isMatchLocked) ...[
          // F1: matched template is premium & user is free — show first
          // 2 lines + blur/fade + Pro badge + paywall CTA instead of the
          // full premium body (prevents the auto-match leak).
          ClipRect(
            child: Stack(
              children: [
                Text(
                  _emailBody(matchedTemplate, localeCode, dispute),
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: tc.textSecondary,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: 22,
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
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => context.push(
              '/paywall?return=/home&trigger=template_locked',
            ),
            borderRadius: BorderRadius.circular(AppRadii.sm),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: tc.premiumGoldSoft,
                borderRadius: BorderRadius.circular(AppRadii.sm),
                border: Border.all(
                  color: AppColors.premiumGold.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                children: [
                  const Text('🔒', style: TextStyle(fontSize: 13)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This is a Pro template — unlock to view & send',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.premiumGold,
                      ),
                    ),
                  ),
                  Text(
                    l10n?.templateProBadge ?? 'Pro',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.premiumGold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
        ] else ...[
          Text(
            l10n?.escalateEmailGreeting ?? 'Dear Nodal Officer,',
            style: TextStyle(
              fontSize: 12,
              height: 1.45,
              color: tc.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => _showFullEmail(
              context,
              body: _emailBody(matchedTemplate, localeCode, dispute),
            ),
            child: Text(
              _emailBody(matchedTemplate, localeCode, dispute),
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: tc.textSecondary,
              ),
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => _showFullEmail(
              context,
              body: _emailBody(matchedTemplate, localeCode, dispute),
            ),
            child: Text(
              '${l10n?.escalateTapToExpand ?? 'Tap to view full email'} \u25BE',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: tc.textTertiary,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n?.escalateEmailAutoDrafted ??
                '[auto-drafted, tap to edit]',
            style: TextStyle(
              fontSize: 10,
              fontStyle: FontStyle.italic,
              color: tc.textTertiary,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Row(
          children: [
            const Text(
              '✓',
              style: TextStyle(fontSize: 10, color: AppColors.accent),
            ),
            const SizedBox(width: 6),
            Text(
              l10n?.escalateStandardsCompliant ??
                  'Standards-compliant · view source',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.accent,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAmberCallout(
    AppThemeColors tc,
    AppLocalizations? l10n,
    CompensationResult comp,
  ) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: tc.alertSoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '⚠',
            style: TextStyle(fontSize: 13, color: AppColors.alert),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: tc.textPrimary,
                  height: 1.4,
                ),
                children: [
                  TextSpan(
                    text:
                        l10n?.escalateSendWithinPrefix ??
                        'Send within ',
                  ),
                  TextSpan(
                    text: l10n?.escalateSendWithin24h ?? '24 hours',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(
                    text:
                        l10n?.escalateSendWithinSuffix(
                          CompensationCalculator.formatIndian(
                            comp.compensationDue,
                          ),
                        ) ??
                        ' to claim full ${CompensationCalculator.formatIndian(comp.compensationDue)} comp retroactively.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(
    AppThemeColors tc,
    BuildContext context,
    WidgetRef ref,
    AppLocalizations? l10n,
    Template? matchedTemplate,
    String localeCode, {
    required TemplateRepository repo,
    required Set<String> freeIds,
    required bool isPremiumUser,
  }) {
    final isMatchLocked = matchedTemplate != null &&
        repo.isLocked(matchedTemplate, freeIds, isPremiumUser: isPremiumUser);
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: tc.surface,
        border: Border(top: BorderSide(color: tc.divider, width: 1)),
      ),
      child: Row(
        children: [
          FooterButton(
            label: l10n?.ombudsmanCopy ?? 'Copy',
            color: tc.surfaceAlt,
            textColor: tc.isDark ? AppColors.accent : AppColors.primary,
            onTap: () => _copyEmail(
              context,
              matchedTemplate: matchedTemplate,
              localeCode: localeCode,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FooterButton(
              label: l10n?.escalateSend ?? 'Send escalation →',
              color: tc.ctaBackground,
              textColor: tc.ctaForeground,
              elevation: true,
              onTap: () {
                // F1: if the matched template is locked for a free user,
                // route to the paywall instead of leaking the premium body.
                if (isMatchLocked) {
                  context.push(
                    '/paywall?return=/home&trigger=template_locked',
                  );
                  return;
                }
                _sendEmail(
                  context,
                  ref: ref,
                  matchedTemplate: matchedTemplate,
                  localeCode: localeCode,
                  isPremiumUser: isPremiumUser,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(
    BuildContext context, {
    required String label,
    required List<Widget> children,
    Widget? labelAction,
  }) {
    final tc = AppThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tc.surface,
        border: Border.all(color: tc.divider, width: 1),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: tc.textSecondary,
                  ),
                ),
              ),
              ?labelAction,
            ],
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  String _nodalEmail(Dispute d) {
    final catalog = BankCatalog.nodalEmailFor(d.entityId ?? '');
    if (catalog != null) return catalog;
    final bank = (d.entityName ?? 'bank').toLowerCase();
    if (bank.contains('hdfc')) return 'nodal.officer@hdfcbank.net';
    if (bank.contains('icici')) return 'nodal.officer@icicibank.com';
    if (bank.contains('axis')) return 'nodal.officer@axisbank.com';
    if (bank.contains('sbi')) return 'nodal.officer@sbi.co.in';
    return 'nodal.officer@yourbank.in';
  }

  String _fmtDate(DateTime d) =>
      '${d.day} ${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][d.month - 1]} ${d.year}, ${((d.hour % 12) == 0 ? 12 : d.hour % 12)}:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'AM' : 'PM'}';

  String _emailBody(Template? matchedTemplate, String localeCode, Dispute d) {
    if (matchedTemplate != null) {
      return filledTemplateBody(matchedTemplate, localeCode, d);
    }
    return 'I am writing to escalate a refund dispute under RBI Master Direction '
        'DPSS.CO.PD.No.629 — failed transaction UTR ${d.txnId} for '
        '${CompensationCalculator.formatIndian(d.amount)} on '
        '${d.txnDate.day} ${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][d.txnDate.month - 1]} '
        'remains unresolved past T+${d.type.tatDays ?? 5}. I request '
        'immediate reversal plus ₹100/day compensation…';
  }

  Template? _matchEscalationTemplate(
    List<Template> templates,
    Dispute d,
    TemplateRepository repo,
    Set<String> freeIds,
    bool isPremiumUser,
  ) {
    final category = switch (d.type) {
      DisputeType.upiP2p ||
      DisputeType.upiP2m ||
      DisputeType.atm ||
      DisputeType.imps => 'UPI / IMPS / ATM',
      DisputeType.fastag => 'FASTag',
      DisputeType.bankCharge => 'Bank charges',
      DisputeType.wrongTransfer => 'Wrong transfer',
    };
    // First try unlocked level-2 templates only — prevents the auto-match
    // from leaking premium template bodies to free users (Task F1).
    for (final t in templates) {
      if (t.escalationLevel == 2 &&
          t.category == category &&
          !repo.isLocked(t, freeIds, isPremiumUser: isPremiumUser)) {
        return t;
      }
    }
    // Fallback: any free (non-premium) template in this category & level.
    for (final t in templates) {
      if (t.escalationLevel == 2 && t.category == category && !t.isPremium) {
        return t;
      }
    }
    // Last resort: any template in category (may be locked — picker & body
    // preview handle the gating from here).
    for (final t in templates) {
      if (t.escalationLevel == 2 && t.category == category) return t;
    }
    return null;
  }

  void _showFullEmail(BuildContext context, {required String body}) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l10n?.escalateEmailPreview ?? 'EMAIL PREVIEW'),
        content: SingleChildScrollView(child: SelectableText(body)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text(l10n?.commonClose ?? 'Close'),
          ),
        ],
      ),
    );
  }

  void _copyEmail(
    BuildContext context, {
    required Template? matchedTemplate,
    required String localeCode,
  }) {
    final body = 'Subject: Escalation — UTR ${dispute.txnId}\n\n'
        '${_emailBody(matchedTemplate, localeCode, dispute)}';
    Clipboard.setData(ClipboardData(text: body));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context)?.escalateCopiedToClipboard ??
              'Email copied to clipboard',
        ),
      ),
    );
  }

  Future<void> _sendEmail(
    BuildContext context, {
    required WidgetRef ref,
    required Template? matchedTemplate,
    required String localeCode,
    required bool isPremiumUser,
  }) async {
    // Capture l10n synchronously before any await — using BuildContext
    // across an async gap triggers use_build_context_synchronously.
    final l10n = AppLocalizations.of(context);
    final subject = 'Escalation — UTR ${dispute.txnId}';
    final body = _emailBody(matchedTemplate, localeCode, dispute);
    final to = _nodalEmail(dispute);
    final cc = ccOmbudsman ? 'crpc@rbi.org.in' : null;
    final ok = await launchEmail(to, subject: subject, body: body, cc: cc);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? (AppLocalizations.of(context)?.escalateOpeningMail ??
                    'Opening mail app…')
              : (AppLocalizations.of(context)?.escalateMailFailed ??
                    'Could not open mail app — email copied instead.'),
        ),
      ),
    );
    if (!ok) {
      await Clipboard.setData(
        ClipboardData(
          text:
              'To: $to\n${cc != null ? 'CC: $cc\n' : ''}Subject: $subject\n\n$body',
        ),
      );
    }

    // Track the escalation event in the persisted activity log so it
    // survives cold-boot and appears on the dispute detail timeline.
    try {
      final now = DateTime.now();
      final meta = _fmtDate(now);
      final updatedLog = <ActivityLogEntry>[
        ...dispute.activityLog,
        ActivityLogEntry(
          type: ActivityLogEntry.escalationEmailSent,
          label: l10n?.activityEscalationSent ?? 'Escalation email sent',
          meta: meta,
          timestamp: now,
          highlighted: true,
        ),
        if (matchedTemplate != null)
          ActivityLogEntry(
            type: ActivityLogEntry.templateUsed,
            label:
                '${l10n?.activityTemplateUsed ?? 'Template used'}: ${matchedTemplate.titleEn}',
            meta: meta,
            timestamp: now,
          ),
      ];
      final repo = ref.read(disputeRepositoryProvider);
      final updated = dispute.copyWith(activityLog: updatedLog);
      await repo.saveDispute(dispute.uid, updated);
      ref.invalidate(disputesProvider(dispute.uid));
    } catch (e) {
      // Best-effort: don't block the user if the log write fails.
      debugPrint('activity log write failed: $e');
    }

    // F4: post-send upsell — after a successful escalation, show a
    // "What's next?" dialog nudging users toward the Ombudsman (L3)
    // letter. Free users see a paywall CTA; premium users navigate
    // straight to the ombudsman letter generator.
    if (ok && context.mounted) {
      EscalatePostSendDialog.show(context, dispute, isPremiumUser);
    }
  }

}

/// Re-export so the analyzer keeps the import used (used by router).
class EscalatePageRouteArg {
  final String disputeId;
  const EscalatePageRouteArg(this.disputeId);
}
