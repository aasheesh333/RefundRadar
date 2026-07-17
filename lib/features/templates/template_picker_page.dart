import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:refund_radar/core/providers/auth_provider.dart';
import 'package:refund_radar/core/providers/dispute_provider.dart';
import 'package:refund_radar/core/providers/premium_provider.dart';
import 'package:refund_radar/core/theme/app_tokens.dart';
import 'package:refund_radar/core/theme/app_theme_colors.dart';
import 'package:refund_radar/data/models/dispute.dart';
import 'package:refund_radar/data/models/template.dart';
import 'package:refund_radar/data/repositories/rules_engine_repository.dart';
import 'package:refund_radar/data/repositories/template_repository.dart';
import 'package:refund_radar/features/templates/template_preview_page.dart';
import 'package:refund_radar/l10n/app_localizations.dart';

/// Full-screen Template Picker shown when the user taps the pencil on the
/// Dispute Detail / Timeline card.
///
/// Wave 4a — clean-minimal Material 3 page. Filters to the **dispute's
/// category** (UPI / IMPS / ATM, FASTag, Bank charges, Wrong transfer)
/// and renders both Level 1 (bank) and Level 2 (NPCI / portal) rows.
/// Tap a template to open the full-screen Preview (which then writes
/// the selection back to the dispute).
class TemplatePickerPage extends ConsumerWidget {
  final String disputeId;
  const TemplatePickerPage({super.key, required this.disputeId});

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
          l10n?.templatePickerTitle ?? 'Pick a template',
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
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              l10n?.escalateMailFailed ?? 'Could not load templates',
              style: TextStyle(color: tc.textPrimary),
            ),
          ),
        ),
        data: (all) {
          // Resolve the dispute from the uid stream.
          return uidAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text('$e',
                    style: TextStyle(color: tc.textPrimary)),
              ),
            ),
            data: (uid) {
              if (uid == null || uid.isEmpty) {
                return _empty(tc, l10n);
              }
              final disputesAsync = ref.watch(disputesProvider(uid));
              return disputesAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text('$e',
                        style: TextStyle(color: tc.textPrimary)),
                  ),
                ),
                data: (disputes) {
                  if (disputes.isEmpty) return _empty(tc, l10n);
                  final d = disputes.firstWhere(
                    (d) => d.id == disputeId,
                    orElse: () => disputes.first,
                  );
                  final freeIds = rulesAsync.maybeWhen(
                    data: (r) => r.freeTemplateIds.toSet(),
                    orElse: () => const <String>{},
                  );
                  return _buildList(context, ref, d, all, freeIds,
                      isPremium, tc, l10n);
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _empty(AppThemeColors tc, AppLocalizations? l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          l10n?.templatePickerEmpty ?? 'No templates for this category',
          style: TextStyle(color: tc.textSecondary, fontSize: 14),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    WidgetRef ref,
    Dispute d,
    List<Template> all,
    Set<String> freeIds,
    bool isPremium,
    AppThemeColors tc,
    AppLocalizations? l10n,
  ) {
    final repo = ref.read(templateRepositoryProvider);
    final locale = Localizations.localeOf(context).languageCode;
    final category = TemplateRepository.categoryFor(d.type);
    final candidates = all
        .where((t) =>
            t.category == category &&
            (t.escalationLevel == 1 || t.escalationLevel == 2))
        .toList();

    if (candidates.isEmpty) return _empty(tc, l10n);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
          child: Text(
            l10n?.templatePickerSubtitle(
                  '${candidates.length}',
                  category,
                ) ??
                '$category · ${candidates.length}',
            style: TextStyle(
              fontSize: 12,
              color: tc.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            itemCount: candidates.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final t = candidates[i];
              final locked =
                  repo.isLocked(t, freeIds, isPremiumUser: isPremium);
              return _TemplateTile(
                template: t,
                locked: locked,
                locale: locale,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TemplatePreviewPage(
                        disputeId: d.id,
                        templateId: t.id,
                      ),
                      fullscreenDialog: true,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TemplateTile extends StatelessWidget {
  final Template template;
  final bool locked;
  final String locale;
  final VoidCallback onTap;
  const _TemplateTile({
    required this.template,
    required this.locked,
    required this.locale,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    final l10n = AppLocalizations.of(context);
    return Material(
      color: tc.surface,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.md),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(color: tc.divider),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      template.titleFor(locale),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTypography.family,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: tc.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: locked
                                ? AppColors.premiumGoldSoft
                                : tc.accentSoft,
                            borderRadius:
                                BorderRadius.circular(AppRadii.pill),
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
                        const SizedBox(width: 6),
                        Text(
                          'L${template.escalationLevel}',
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
              ),
              const SizedBox(width: 8),
              Icon(
                locked ? Icons.lock_outline : Icons.chevron_right,
                size: 18,
                color: locked
                    ? AppColors.premiumGold
                    : tc.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
