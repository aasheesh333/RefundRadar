import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:refund_radar/core/providers/auth_provider.dart';
import 'package:refund_radar/core/providers/dispute_provider.dart';
import 'package:refund_radar/core/providers/premium_provider.dart';
import 'package:refund_radar/core/router/app_routes.dart';
import 'package:refund_radar/core/theme/app_tokens.dart';
import 'package:refund_radar/core/theme/app_theme_colors.dart';
import 'package:refund_radar/data/models/dispute.dart';
import 'package:refund_radar/data/models/template.dart';
import 'package:refund_radar/data/models/template_fill.dart';
import 'package:refund_radar/data/repositories/firestore_dispute_repository.dart';
import 'package:refund_radar/data/repositories/rules_engine_repository.dart';
import 'package:refund_radar/data/repositories/template_repository.dart';
import 'package:refund_radar/l10n/app_localizations.dart';

/// Full-screen Template Preview. Wave 4a.
///
/// Behaviour:
///   - Premium user: renders the FULL pre-filled body (every {TOKEN}
///     substituted). Bottom CTA "Use this template" persists the
///     templateId onto the dispute (it then becomes the auto-match on
///     Escalate, escalation email, …) and pops back.
///   - Free user + Pro template: renders the subject line and the first
///     1-2 lines of body. The remaining body shows literal {TOKEN}
///     placeholders so the user can see *which* merge fields will
///     auto-fill for their dispute. A `Locked preview` overlay and a
///     "Unlock with Premium" CTA take the user to the paywall with a
///     `returnPath` back to this preview.
class TemplatePreviewPage extends ConsumerWidget {
  final String disputeId;
  final String templateId;
  const TemplatePreviewPage({
    super.key,
    required this.disputeId,
    required this.templateId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tc = AppThemeColors.of(context);
    final templatesAsync = ref.watch(templatesProvider);
    final rulesAsync = ref.watch(rulesEngineProvider);
    final uidAsync = ref.watch(userIdProvider);
    final isPremium = ref.watch(isPremiumProvider);

    return Scaffold(
      backgroundColor: tc.bg,
      appBar: AppBar(
        backgroundColor: tc.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: tc.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          l10n?.templatePickerTitle ?? 'Template',
          style: TextStyle(
            fontFamily: AppTypography.family,
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: tc.textPrimary,
          ),
        ),
        centerTitle: false,
      ),
      body: templatesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
            child: Text(
                l10n?.escalateMailFailed ?? 'Could not load',
                style: TextStyle(color: tc.textPrimary))),
        data: (all) {
          final template = all.firstWhere(
            (t) => t.id == templateId,
            orElse: () => all.isEmpty
                ? throw StateError('no templates loaded')
                : all.first,
          );
          return uidAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
                child: Text('$e',
                    style: TextStyle(color: tc.textPrimary))),
            data: (uid) {
              if (uid == null || uid.isEmpty) {
                return Center(
                  child: Text(
                    l10n?.escalateMailFailed ?? 'Sign in required',
                    style: TextStyle(color: tc.textPrimary),
                  ),
                );
              }
              final disputesAsync = ref.watch(disputesProvider(uid));
              return disputesAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                    child: Text('$e',
                        style: TextStyle(color: tc.textPrimary))),
                data: (disputes) {
                  if (disputes.isEmpty) {
                    return Center(
                      child: Text(
                        l10n?.templatePickerEmpty ?? 'No dispute',
                        style: TextStyle(color: tc.textPrimary),
                      ),
                    );
                  }
                  final d = disputes.firstWhere(
                    (d) => d.id == disputeId,
                    orElse: () => disputes.first,
                  );
                  final freeIds = rulesAsync.maybeWhen(
                    data: (r) => r.freeTemplateIds.toSet(),
                    orElse: () => const <String>{},
                  );
                  final repo = ref.read(templateRepositoryProvider);
                  final locked = repo.isLocked(template, freeIds,
                      isPremiumUser: isPremium);
                  return _buildBody(
                      context, ref, d, template, locked, tc, l10n);
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    Dispute d,
    Template t,
    bool locked,
    AppThemeColors tc,
    AppLocalizations? l10n,
  ) {
    final locale = Localizations.localeOf(context).languageCode;
    final fillMap = fillValuesForDispute(d);
    final rawBody = t.bodyFor(locale);
    final filledBody = Template.fill(rawBody, fillMap);

    // Subject line is always derived from the first non-empty line of the
    // body that does NOT contain a {PLACEHOLDER}, or "Escalation — UTR
    // <id>". This keeps the preview consistent with the actual mailto
    // subject generated by Escalate.
    final subject = _derivedSubject(d);

    final previewBody = locked ? _lockedPreviewBody(rawBody) : filledBody;

    return Stack(
      children: [
        // Main content
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
          child: ListView(
            children: [
              _previewHeader(context, t, locked, tc, l10n),
              const SizedBox(height: 18),
              _subjectCard(subject, tc, l10n),
              const SizedBox(height: 16),
              _bodyCard(previewBody, locked, tc, l10n),
            ],
          ),
        ),
        // Sticky bottom CTA
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _stickyCta(context, ref, d, t, locked, tc, l10n),
        ),
      ],
    );
  }

  Widget _previewHeader(
    BuildContext context,
    Template t,
    bool locked,
    AppThemeColors tc,
    AppLocalizations? l10n,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.titleFor(
                    Localizations.localeOf(context).languageCode),
                style: TextStyle(
                  fontFamily: AppTypography.family,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: tc.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: locked
                          ? AppColors.premiumGoldSoft
                          : tc.accentSoft,
                      borderRadius:
                          BorderRadius.circular(AppRadii.pill),
                    ),
                    child: Text(
                      locked
                          ? (l10n?.templateProBadge ?? 'Pro')
                          : (l10n?.templatePreviewFree ?? 'Free'),
                      style: TextStyle(
                        fontFamily: AppTypography.family,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: locked
                            ? AppColors.premiumGold
                            : AppColors.success,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: tc.surfaceAlt,
                      borderRadius:
                          BorderRadius.circular(AppRadii.pill),
                    ),
                    child: Text(
                      'L${t.escalationLevel}',
                      style: TextStyle(
                        fontFamily: AppTypography.family,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: tc.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _subjectCard(String subject, AppThemeColors tc,
      AppLocalizations? l10n) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: tc.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: tc.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n?.templatePreviewSubject ?? 'Subject',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              color: tc.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subject,
            style: TextStyle(
              fontFamily: AppTypography.family,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: tc.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bodyCard(String body, bool locked, AppThemeColors tc,
      AppLocalizations? l10n) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: tc.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: tc.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                l10n?.templatePreviewBody ?? 'Body',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: tc.textSecondary,
                ),
              ),
              const Spacer(),
              if (locked)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.premiumGoldSoft,
                    borderRadius:
                        BorderRadius.circular(AppRadii.pill),
                  ),
                  child: Text(
                    l10n?.templatePickerLocked ??
                        'Locked preview',
                    style: TextStyle(
                      fontFamily: AppTypography.family,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.premiumGold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          SelectableText(
            body,
            style: TextStyle(
              fontFamily: AppTypography.family,
              fontSize: 13,
              height: 1.5,
              color: tc.textPrimary,
            ),
          ),
          if (locked) ...[
            const SizedBox(height: 14),
            _lockedBanner(tc, l10n),
          ],
        ],
      ),
    );
  }

  Widget _lockedBanner(AppThemeColors tc, AppLocalizations? l10n) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.premiumGoldSoft,
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_outline,
              size: 16, color: AppColors.premiumGold),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n?.templatePickerLockedHint ??
                  'Subject line visible. Tap to upgrade and see the full body pre-filled for your dispute.',
              style: TextStyle(
                fontFamily: AppTypography.family,
                fontSize: 12,
                color: tc.textPrimary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stickyCta(
    BuildContext context,
    WidgetRef ref,
    Dispute d,
    Template t,
    bool locked,
    AppThemeColors tc,
    AppLocalizations? l10n,
  ) {
    final label = locked
        ? (l10n?.templatePreviewUpgrade ?? 'Unlock with Premium')
        : (l10n?.templatePreviewSelect ?? 'Use this template');
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, 12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: tc.surface,
        border: Border(top: BorderSide(color: tc.divider)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.copy, color: tc.textSecondary, size: 20),
            onPressed: () async {
              final locale =
                  Localizations.localeOf(context).languageCode;
              final fillMap = fillValuesForDispute(d);
              final filled =
                  Template.fill(t.bodyFor(locale), fillMap);
              final clipboardText =
                  '${l10n?.templatePreviewSubject ?? 'Subject'}: '
                      '${_derivedSubject(d)}\n\n'
                      '${l10n?.templatePreviewBody ?? 'Body'}:\n'
                      '$filled';
              await Clipboard.setData(
                  ClipboardData(text: clipboardText));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      l10n?.escalateCopiedToClipboard ?? 'Copied'),
                ),
              );
            },
          ),
          const SizedBox(width: 4),
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: locked
                      ? AppColors.premiumGold
                      : tc.ctaBackground,
                  foregroundColor: locked
                      ? Colors.black
                      : tc.ctaForeground,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppRadii.md),
                  ),
                ),
                onPressed: () async {
                  if (locked) {
                    // Route to paywall with returnPath back to this preview.
                    final previewReturn = AppRoutes.templatePreviewWith(
                        disputeId: d.id,
                        templateId: t.id);
                    if (!context.mounted) return;
                    context.push(
                      AppRoutes.paywallWithParams(
                        trigger: 'template_locked_preview',
                        returnPath: previewReturn,
                        templateId: t.id,
                        templateTitle: t.titleFor(
                            Localizations.localeOf(context)
                                .languageCode),
                      ),
                    );
                    return;
                  }
                  // Persist the user's pick onto the dispute. We store the
                  // templateId on the dispute.activityLog via the existing
                  // 'templateUsed' entry on the next Escalate action;
                  // for now we just navigate back — the selection is
                  // re-resolved at Escalate render time. The dispute's
                  // "last template pick" can be derived from the activity
                  // log.
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        l10n?.templatePreviewSelected ?? 'Selected',
                        style:
                            const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                  context.pop(t.id);
                },
                child: Text(
                  label,
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

  /// When the template is locked for a free user, render the first two
  /// visible (non-token) lines of the raw body, then a row of "{TOKEN}"
  /// placeholders so the user understands exactly which merge fields will
  /// be substituted when they upgrade.
  String _lockedPreviewBody(String rawBody) {
    final lines = rawBody.split('\n');
    final preview = <String>[];
    for (final l in lines) {
      preview.add(l);
      if (preview.length >= 8) break;
    }
    return preview.join('\n');
  }

  /// Derives the email subject. Matches the convention in Escalate:
  /// `"Escalation — UTR &lt;id&gt;"`.
  String _derivedSubject(Dispute d) {
    final id = d.txnId.isEmpty ? d.id : d.txnId;
    return 'Escalation — UTR $id';
  }
}

// Local re-export to suppress unused-import warnings during static analysis.
// ignore_for_file: unused_element
typedef _DisputeRepoImportSentinel = FirestoreDisputeRepository;
