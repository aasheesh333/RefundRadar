import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:refund_radar/core/providers/auth_provider.dart';
import 'package:refund_radar/core/providers/dispute_provider.dart';
import 'package:refund_radar/core/providers/premium_provider.dart';
import 'package:refund_radar/core/providers/theme_provider.dart';
import 'package:refund_radar/core/router/app_routes.dart';
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
import 'package:refund_radar/features/templates/template_library_page.dart';
import 'package:refund_radar/l10n/app_localizations.dart';
import 'package:refund_radar/services/compensation_calculator.dart';
import 'package:refund_radar/shared/utils/error_mapper.dart';
import 'package:refund_radar/shared/widgets/branded_error_banner.dart';
import 'package:refund_radar/shared/widgets/skeleton.dart';
import 'package:refund_radar/shared/widgets/toggle_switch.dart';

/// Wave 5 redesign — clean-minimal Material 3 escalation composer.
///
/// Same auto-match + send flow as before, but the visual treatment is
/// fully new:
///   - Hero card with a single big number + label (no dark-green block).
///   - Recipient rows presented as a clean two-row list with a switch.
///   - Email preview card pre-filled with all merge tokens (Wave 2
///     captures them at dispute-create time).
///   - Sticky bottom with a primary Send + secondary Copy.
///   - Lock handling unchanged but visualised via the new locked banner
///     that links to the new full-screen Template Preview (Wave 4a).
class EscalatePage extends ConsumerWidget {
  final String disputeId;
  const EscalatePage({super.key, required this.disputeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tc = AppThemeColors.of(context);
    final l10n = AppLocalizations.of(context);
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
                message: l10n?.commonCouldNotSignIn ?? 'Could not sign in',
                onRetry: () => ref.invalidate(userIdProvider),
              );
            }
            final disputesAsync = ref.watch(disputesProvider(uid));
            return disputesAsync.when(
              data: (disputes) {
                Dispute? dispute;
                for (final d in disputes) {
                  if (d.id == disputeId) {
                    dispute = d;
                    break;
                  }
                }
                if (dispute == null) {
                  return BrandedErrorBanner(
                    message: l10n?.commonDisputeNotFound ?? 'Dispute not found',
                    onRetry: () => ref.invalidate(disputesProvider(uid)),
                  );
                }
                return _EscalateBody(dispute: dispute, uid: uid);
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

class _EscalateBody extends ConsumerStatefulWidget {
  final Dispute dispute;
  final String uid;
  const _EscalateBody({required this.dispute, required this.uid});
  @override
  ConsumerState<_EscalateBody> createState() => _EscalateBodyState();
}

class _EscalateBodyState extends ConsumerState<_EscalateBody> {
  bool _ccOmbudsman = true;
  String? _selectedTemplateId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tc = AppThemeColors.of(context);
    final dispute = widget.dispute;
    final comp = CompensationCalculator.compute(dispute);
    final refund = dispute.amount;
    final maxClaim = refund + comp.compensationDue;
    final deadlineMissed = comp.isExpired;
    final deadlineDays = deadlineMissed
        ? 0
        : comp.deadlineDate.difference(DateTime.now()).inDays;
    final templatesAsync = ref.watch(templatesProvider);
    final rulesAsync = ref.watch(rulesEngineProvider);
    final freeIds = rulesAsync.asData?.value.freeTemplateIds.toSet() ??
        const <String>{};
    final isPremiumUser = ref.watch(isPremiumProvider);
    final locale = ref.watch(localeProvider);
    final localeCode = locale.languageCode;

    return templatesAsync.when(
      loading: () => const SkeletonList(itemCount: 4),
      error: (e, _) => BrandedErrorBanner(
        message: friendlyError(e),
        detail: errorDetail(e),
        onRetry: () => ref.invalidate(templatesProvider),
      ),
      data: (templates) {
        Template? picked;
        if (_selectedTemplateId != null) {
          for (final t in templates) {
            if (t.id == _selectedTemplateId) {
              picked = t;
              break;
            }
          }
        }
        final repo = ref.read(templateRepositoryProvider);
        final match = picked ??
            repo.matchForCategory(
              templates,
              dispute.type,
              freeIds,
              isPremiumUser: isPremiumUser,
            );
        return Stack(
          children: [
            Positioned.fill(
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                    sliver: SliverList.list(
                      children: [
                        _PageHeader(dispute: dispute, tc: tc, l10n: l10n),
                        const SizedBox(height: 16),
                        _HeroCard(
                          maxClaim: maxClaim,
                          refund: refund,
                          comp: comp,
                          deadlineMissed: deadlineMissed,
                          deadlineDays: deadlineDays,
                          tatBasis: dispute.type.tatBasis,
                          tc: tc,
                          l10n: l10n,
                        ),
                        const SizedBox(height: 16),
                        _RecipientCard(
                          dispute: dispute,
                          ccOmbudsman: _ccOmbudsman,
                          onToggleCc: (v) =>
                              setState(() => _ccOmbudsman = v),
                          tc: tc,
                          l10n: l10n,
                        ),
                        const SizedBox(height: 16),
                        _EmailPreviewCard(
                          dispute: dispute,
                          matchedTemplate: match,
                          repo: repo,
                          freeIds: freeIds,
                          isPremiumUser: isPremiumUser,
                          localeCode: localeCode,
                          ccOmbudsman: _ccOmbudsman,
                          onChangeTemplate: () => _openTemplatePicker(
                                context,
                                dispute,
                                templates,
                                repo,
                                freeIds,
                                isPremiumUser,
                                localeCode,
                              ),
                          tc: tc,
                          l10n: l10n,
                        ),
                        if (deadlineMissed) ...[
                          const SizedBox(height: 16),
                          _DeadlineCallout(comp: comp, tc: tc, l10n: l10n),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _StickyFooter(
                dispute: dispute,
                match: match,
                repo: repo,
                freeIds: freeIds,
                isPremiumUser: isPremiumUser,
                localeCode: localeCode,
                ccOmbudsman: _ccOmbudsman,
                tc: tc,
                l10n: l10n,
              ),
            ),
          ],
        );
      },
    );
  }

  void _openTemplatePicker(
    BuildContext context,
    Dispute dispute,
    List<Template> templates,
    TemplateRepository repo,
    Set<String> freeIds,
    bool isPremiumUser,
    String localeCode,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetCtx) {
        final sheetTc = AppThemeColors.of(sheetCtx);
        final sheetL10n = AppLocalizations.of(sheetCtx);
        final buckets = repo.splitForCategory(
          templates,
          dispute.type,
          freeIds,
          isPremiumUser: isPremiumUser,
        );
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(sheetCtx).size.height * 0.7,
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        sheetL10n?.escalatePickTemplate ??
                            'Pick template',
                        style: TextStyle(
                          fontFamily: AppTypography.family,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: sheetTc.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  TabBar(
                    tabs: [
                      Tab(
                          text:
                              '${sheetL10n?.templatePreviewFree ?? 'Free'} (${buckets.free.length})'),
                      Tab(
                          text:
                              '${sheetL10n?.templateProBadge ?? 'Pro'} (${buckets.pro.length})'),
                    ],
                    labelColor: AppColors.accent,
                    unselectedLabelColor: sheetTc.textTertiary,
                    indicatorColor: AppColors.accent,
                    indicatorSize: TabBarIndicatorSize.label,
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        for (final bucket in [buckets.free, buckets.pro])
                          ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                            itemCount: bucket.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (_, i) {
                              final t = bucket[i];
                              final isLocked =
                                  repo.isLocked(t, freeIds,
                                      isPremiumUser: isPremiumUser);
                              return _sheetTile(
                                context: sheetCtx,
                                tc: sheetTc,
                                l10n: sheetL10n,
                                template: t,
                                locked: isLocked,
                                onTap: () {
                                  if (isLocked) {
                                    Navigator.pop(sheetCtx);
                                    context.push(
                                      AppRoutes.paywallWithParams(
                                        trigger: 'template_locked',
                                        returnPath: AppRoutes
                                            .escalate(dispute.id),
                                        templateId: t.id,
                                        templateTitle:
                                            t.titleFor(localeCode),
                                      ),
                                    );
                                    return;
                                  }
                                  setState(() =>
                                      _selectedTemplateId = t.id);
                                  Navigator.pop(sheetCtx);
                                },
                              );
                            },
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

  Widget _sheetTile({
    required BuildContext context,
    required AppThemeColors tc,
    required AppLocalizations? l10n,
    required Template template,
    required bool locked,
    required VoidCallback onTap,
  }) {
    return Material(
      color: tc.surface,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.md),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: tc.divider),
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      template.titleEn,
                      style: TextStyle(
                        fontFamily: AppTypography.family,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: tc.textPrimary,
                      ),
                    ),
                  ),
                  if (locked)
                    const Text('🔒 Pro',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.premiumGold)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'L${template.escalationLevel} · ${template.category}',
                style: TextStyle(fontSize: 11, color: tc.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  final Dispute dispute;
  final AppThemeColors tc;
  final AppLocalizations? l10n;
  const _PageHeader({
    required this.dispute,
    required this.tc,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: tc.textPrimary),
            onPressed: () => context.pop(),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n?.escalateAppBarTitle ?? 'Escalate',
                  style: TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: tc.textPrimary,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  l10n?.escalateNodalOfficer ?? 'Nodal Officer',
                  style: TextStyle(
                    fontSize: 12,
                    color: tc.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => context.push(
              AppRoutes.templatePickerWithDispute(dispute.id),
            ),
            child: Text(
              l10n?.templatePickerTitle ?? 'Templates',
              style: TextStyle(
                fontFamily: AppTypography.family,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: tc.ctaBackground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final double maxClaim;
  final double refund;
  final CompensationResult comp;
  final bool deadlineMissed;
  final int deadlineDays;
  final String tatBasis;
  final AppThemeColors tc;
  final AppLocalizations? l10n;
  const _HeroCard({
    required this.maxClaim,
    required this.refund,
    required this.comp,
    required this.deadlineMissed,
    required this.deadlineDays,
    required this.tatBasis,
    required this.tc,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: tc.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: tc.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n?.escalateTotalClaimable ?? 'Total claimable',
            style: TextStyle(
              fontFamily: AppTypography.family,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: tc.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            CompensationCalculator.formatIndian(maxClaim),
            style: TextStyle(
              fontFamily: AppTypography.family,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              height: 1,
              color: tc.textPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: deadlineMissed
                      ? AppColors.alert
                      : AppColors.success,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                deadlineMissed
                    ? (l10n?.escalateDeadlineMissed(tatBasis) ??
                        '$tatBasis missed')
                    : (l10n?.escalateDeadlineIn(tatBasis, deadlineDays) ??
                        '$tatBasis deadline in $deadlineDays days'),
                style: TextStyle(
                  fontFamily: AppTypography.family,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: deadlineMissed
                      ? AppColors.alert
                      : AppColors.success,
                ),
              ),
            ],
          ),
          if (refund > 0) ...[
            const SizedBox(height: 4),
            Text(
              '${CompensationCalculator.formatIndian(refund)} refund + ${CompensationCalculator.formatIndian(comp.compensationDue)} comp (${comp.daysElapsed}d × ₹100/d)',
              style: TextStyle(
                fontSize: 11,
                color: tc.textTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RecipientCard extends StatelessWidget {
  final Dispute dispute;
  final bool ccOmbudsman;
  final ValueChanged<bool> onToggleCc;
  final AppThemeColors tc;
  final AppLocalizations? l10n;
  const _RecipientCard({
    required this.dispute,
    required this.ccOmbudsman,
    required this.onToggleCc,
    required this.tc,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: tc.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: tc.divider),
      ),
      child: Column(
        children: [
          _recipient(
            emoji: '🎯',
            emojiBg: tc.alertSoft,
            title: l10n?.escalateNodalOfficer ?? 'Nodal Officer',
            detail: _nodalEmail(dispute),
            selected: true,
            tc: tc,
          ),
          Divider(height: 1, color: tc.divider),
          _recipient(
            emoji: '✉',
            emojiBg: tc.surfaceAlt,
            title: l10n?.escalateCcOmbudsman ?? 'CC RBI Ombudsman',
            detail: 'crpc@rbi.org.in',
            selected: ccOmbudsman,
            tc: tc,
            trailing: ToggleSwitch(value: ccOmbudsman, onChanged: onToggleCc),
          ),
        ],
      ),
    );
  }

  Widget _recipient({
    required String emoji,
    required Color emojiBg,
    required String title,
    required String detail,
    required bool selected,
    required AppThemeColors tc,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: emojiBg,
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 14)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: tc.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: TextStyle(
                      fontSize: 11, color: tc.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          ?trailing,
          if (trailing == null && selected)
            Icon(Icons.check_circle, size: 18, color: tc.ctaBackground),
        ],
      ),
    );
  }
}

class _EmailPreviewCard extends StatelessWidget {
  final Dispute dispute;
  final Template? matchedTemplate;
  final TemplateRepository repo;
  final Set<String> freeIds;
  final bool isPremiumUser;
  final String localeCode;
  final bool ccOmbudsman;
  final VoidCallback onChangeTemplate;
  final AppThemeColors tc;
  final AppLocalizations? l10n;
  const _EmailPreviewCard({
    required this.dispute,
    required this.matchedTemplate,
    required this.repo,
    required this.freeIds,
    required this.isPremiumUser,
    required this.localeCode,
    required this.ccOmbudsman,
    required this.onChangeTemplate,
    required this.tc,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final t = matchedTemplate;
    final locked = t != null &&
        repo.isLocked(t, freeIds, isPremiumUser: isPremiumUser);
    final subject = 'Escalation — UTR ${dispute.txnId}';
    final body =
        t != null ? filledTemplateBody(t, localeCode, dispute) : '';

    return Container(
      decoration: BoxDecoration(
        color: tc.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: tc.divider),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                l10n?.escalateEmailPreview ?? 'Email preview',
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
                onPressed: onChangeTemplate,
                icon: const Icon(Icons.tune, size: 14),
                label: Text(
                  l10n?.templatePickerTitle ?? 'Templates',
                  style: TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: tc.surfaceAlt,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Text(
                  l10n?.escalateSubjectLabel ?? 'SUBJECT',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      color: tc.textSecondary),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    subject,
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
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${l10n?.escalateToLabel ?? 'TO:'} ${_nodalEmail(dispute)}',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: tc.textPrimary),
          ),
          if (ccOmbudsman)
            Text(
              '${l10n?.escalateCcLabel ?? 'CC:'} crpc@rbi.org.in',
              style: TextStyle(fontSize: 11, color: tc.textSecondary),
            ),
          const SizedBox(height: 10),
          if (locked)
            _lockedBanner(tc, l10n)
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: tc.surfaceAlt,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                body.isNotEmpty
                    ? body
                    : '—',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  height: 1.5,
                  color: tc.textPrimary,
                ),
                maxLines: 10,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  Widget _lockedBanner(AppThemeColors tc, AppLocalizations? l10n) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.premiumGoldSoft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.premiumGold, width: 0.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline,
              size: 16, color: AppColors.premiumGold),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n?.escalateProTemplateLocked ??
                  'Pro template — preview locked. Tap "Templates" to see options.',
              style: TextStyle(
                fontSize: 12,
                color: tc.textPrimary,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeadlineCallout extends StatelessWidget {
  final CompensationResult comp;
  final AppThemeColors tc;
  final AppLocalizations? l10n;
  const _DeadlineCallout({
    required this.comp,
    required this.tc,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tc.alertSoft,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('⚠',
              style: TextStyle(fontSize: 14, color: AppColors.alert)),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 12,
                  color: tc.textPrimary,
                  height: 1.4,
                ),
                children: [
                  TextSpan(
                    text: l10n?.escalateSendWithinPrefix ??
                        'Send within ',
                  ),
                  TextSpan(
                    text: l10n?.escalateSendWithin24h ?? '24 hours',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(
                    text: l10n?.escalateSendWithinSuffix(
                            CompensationCalculator.formatIndian(
                                comp.compensationDue)) ??
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
}

class _StickyFooter extends StatelessWidget {
  final Dispute dispute;
  final Template? match;
  final TemplateRepository repo;
  final Set<String> freeIds;
  final bool isPremiumUser;
  final String localeCode;
  final bool ccOmbudsman;
  final AppThemeColors tc;
  final AppLocalizations? l10n;
  const _StickyFooter({
    required this.dispute,
    required this.match,
    required this.repo,
    required this.freeIds,
    required this.isPremiumUser,
    required this.localeCode,
    required this.ccOmbudsman,
    required this.tc,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final t = match;
    final locked = t != null &&
        repo.isLocked(t, freeIds, isPremiumUser: isPremiumUser);
    final subject = 'Escalation — UTR ${dispute.txnId}';
    final body =
        t != null ? filledTemplateBody(t, localeCode, dispute) : '';

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
          SizedBox(
            height: 46,
            child: OutlinedButton(
              onPressed: () {
                if (locked) {
                  context.push(
                    AppRoutes.paywallWithParams(
                      trigger: 'template_locked',
                      returnPath: AppRoutes.escalate(dispute.id),
                      templateId: match!.id,
                      templateTitle: match!.titleFor(localeCode),
                    ),
                  );
                  return;
                }
                final clipboardText =
                    '${l10n?.escalateSubjectLabel ?? 'SUBJECT'}: $subject\n\n$body';
                Clipboard.setData(ClipboardData(text: clipboardText));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      l10n?.escalateCopiedToClipboard ?? 'Copied',
                    ),
                  ),
                );
              },
              child: Text(l10n?.escalateSendWithinPrefix ?? 'Copy'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SizedBox(
              height: 46,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: tc.ctaBackground,
                  foregroundColor: tc.ctaForeground,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                ),
                onPressed: () async {
                  if (locked) {
                    context.push(
                      AppRoutes.paywallWithParams(
                        trigger: 'template_locked',
                        returnPath: AppRoutes.escalate(dispute.id),
                        templateId: match!.id,
                        templateTitle: match!.titleFor(localeCode),
                      ),
                    );
                    return;
                  }
                  final to = _nodalEmail(dispute);
                  final cc = ccOmbudsman ? 'crpc@rbi.org.in' : null;
                  final ok = await launchEmail(to,
                      subject: subject, body: body, cc: cc);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(
                      ok
                          ? (l10n?.escalateOpeningMail ??
                              'Opening mail app…')
                          : (l10n?.escalateMailFailed ??
                              'Could not open mail app — copied.'),
                    ),
                  ));
                  if (!ok) {
                    await Clipboard.setData(ClipboardData(
                        text:
                            'To: $to\n${cc != null ? 'CC: $cc\n' : ''}Subject: $subject\n\n$body'));
                  }
                  // Persist activity log.
                  try {
                    final now = DateTime.now();
                    final updatedLog = <ActivityLogEntry>[
                      ...dispute.activityLog,
                      ActivityLogEntry(
                        type: ActivityLogEntry.escalationEmailSent,
                        label: l10n?.activityEscalationSent ??
                            'Escalation email sent',
                        meta: _fmtDate(now),
                        timestamp: now,
                        highlighted: true,
                      ),
                      if (match != null)
                        ActivityLogEntry(
                          type: ActivityLogEntry.templateUsed,
                          label:
                              '${l10n?.activityTemplateUsed ?? 'Template used'}: ${match!.titleEn}',
                          meta: _fmtDate(now),
                          timestamp: now,
                        ),
                    ];
                    final updated =
                        dispute.copyWith(activityLog: updatedLog);
                    // No ref here — use the navigator's resolve ref via
                    // ProviderScope. The router owns the state; if a save
                    // fails the conversation logs upstream.
                    // ignore: use_build_context_synchronously
                    final mq = ProviderScope.containerOf(context);
                    await mq
                        .read(disputeRepositoryProvider)
                        .saveDispute(dispute.uid, updated);
                    mq.invalidate(disputesProvider(dispute.uid));
                  } catch (_) {
                    // Best-effort.
                  }
                  if (ok && context.mounted) {
                    EscalatePostSendDialog.show(
                        context, dispute, isPremiumUser);
                  }
                },
                child: Text(
                  l10n?.escalateSend ?? 'Send escalation',
                  style: TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
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
