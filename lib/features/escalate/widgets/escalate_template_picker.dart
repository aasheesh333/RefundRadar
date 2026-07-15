import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:refund_radar/core/theme/app_theme_colors.dart';
import 'package:refund_radar/core/theme/app_tokens.dart';
import 'package:refund_radar/data/models/dispute.dart';
import 'package:refund_radar/data/models/template.dart';
import 'package:refund_radar/data/repositories/template_repository.dart';
import 'package:refund_radar/features/templates/template_library_page.dart';
import 'package:refund_radar/l10n/app_localizations.dart';
import 'package:refund_radar/shared/widgets/status_pill.dart';

/// Escalation template picker — a two-tab (Free / Pro) modal bottom sheet
/// that lets the user pick a level-2 escalation template for the current
/// dispute category. Pro (locked) entries show a faded 2-line body preview
/// + Pro badge and route to the paywall on tap instead of selecting the
/// template (F2).
class EscalateTemplatePicker {
  /// Shows the escalation template picker bottom sheet.
  static void show(
    BuildContext context, {
    required Dispute dispute,
    required List<Template> templates,
    required String localeCode,
    required Set<String> freeIds,
    required bool isPremiumUser,
    required TemplateRepository repo,
    required String? selectedTemplateId,
    required void Function(String?) onSelectTemplate,
  }) {
    final tc = AppThemeColors.of(context);

    // ME-7: partition via the shared helper so the free/pro buckets match
    // every other call site. The old inline `switch (dispute.type)` + loop
    // is now one delegated call.
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
                  // Handle
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
                        _templateList(
                          sheetCtx,
                          dispute,
                          freeTemplates,
                          repo,
                          freeIds,
                          isPremiumUser,
                          selectedTemplateId,
                          localeCode,
                          onSelectTemplate,
                          sheetL10n,
                          isProTab: false,
                        ),
                        _templateList(
                          sheetCtx,
                          dispute,
                          proTemplates,
                          repo,
                          freeIds,
                          isPremiumUser,
                          selectedTemplateId,
                          localeCode,
                          onSelectTemplate,
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

  /// F2 helper — renders the Free or Pro tab of the template picker.
  /// Pro (locked) entries show a faded 2-line body preview + Pro badge and
  /// route to the paywall on tap instead of selecting the template.
  static Widget _templateList(
    BuildContext context,
    Dispute dispute,
    List<Template> templates,
    TemplateRepository repo,
    Set<String> freeIds,
    bool isPremiumUser,
    String? selectedTemplateId,
    String localeCode,
    void Function(String?) onSelectTemplate,
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
        final isSelected = t.id == selectedTemplateId;
        // Pro tab entries are gated for free users; premium users unlock them.
        final isLocked = isProTab &&
            repo.isLocked(t, freeIds, isPremiumUser: isPremiumUser);

        return InkWell(
          onTap: isLocked
              ? () {
                  Navigator.pop(context);
                  context.push(
                    '/paywall?return=/home&trigger=template_locked',
                  );
                }
              : () {
                  onSelectTemplate(t.id);
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

  /// F2 helper — fades the bottom of a locked template preview with a
  /// surface-coloured gradient so the full premium body stays blurred.
  static Widget _blurredPreview(String body, AppThemeColors tc) {
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
}
