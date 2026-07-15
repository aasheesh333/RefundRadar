import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/providers/app_state_provider.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/dispute_provider.dart';
import '../../data/models/dispute.dart';
import '../../data/models/template.dart';
import '../../data/models/template_fill.dart';
import '../../data/repositories/rules_engine_repository.dart';
import '../../data/repositories/template_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/filter_pills.dart';
import '../../shared/widgets/status_pill.dart';
import 'package:refund_radar/shared/widgets/branded_error_banner.dart';
import 'package:refund_radar/shared/widgets/skeleton.dart';
import 'package:refund_radar/shared/utils/indian_number_formatter.dart';
import 'package:refund_radar/core/router/app_routes.dart';

Map<String, String> templateFillValues(Dispute? dispute) =>
    fillValuesForDispute(dispute);

String filledTemplateBody(Template t, String localeCode, Dispute? dispute) {
  return filledBody(t.bodyFor(localeCode), dispute);
}

class TemplateLibraryPage extends ConsumerStatefulWidget {
  const TemplateLibraryPage({super.key});
  @override
  ConsumerState<TemplateLibraryPage> createState() =>
      _TemplateLibraryPageState();
}

class _TemplateLibraryPageState extends ConsumerState<TemplateLibraryPage> {
  String _selectedCategory = 'All';
  String? _selectedDisputeId;
  static const _categories = [
    'All',
    'UPI / IMPS / ATM',
    'FASTag',
    'Bank charges',
    'Wrong transfer',
    'Advanced / legal',
  ];

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    final templatesAsync = ref.watch(templatesProvider);
    final rulesAsync = ref.watch(rulesEngineProvider);
    final isPremium = ref.watch(isPremiumProvider);
    final locale = ref.watch(localeProvider);
    final uid = ref.watch(userIdProvider).asData?.value;
    final disputesAsync = uid == null ? null : ref.watch(disputesProvider(uid));
    final disputes = disputesAsync?.asData?.value ?? const <Dispute>[];
    return Scaffold(
      backgroundColor: tc.bg,
      body: SafeArea(
        child: templatesAsync.when(
          data: (templates) => rulesAsync.when(
            data: (rules) => _buildBody(
              templates: templates,
              freeIds: rules.freeTemplateIds.toSet(),
              isPremiumUser: isPremium,
              localeCode: locale.languageCode,
              disputes: disputes,
            ),
            loading: () => const SkeletonList(itemCount: 4),
            error: (e, _) => BrandedErrorBanner(message: e.toString()),
          ),
          loading: () => const SkeletonList(itemCount: 4),
          error: (e, _) => BrandedErrorBanner(message: e.toString()),
        ),
      ),
    );
  }

  Dispute? _selectedDispute(List<Dispute> disputes) {
    if (disputes.isEmpty) return null;
    if (_selectedDisputeId != null) {
      for (final d in disputes) {
        if (d.id == _selectedDisputeId) return d;
      }
    }
    return disputes.first;
  }

  Widget _buildBody({
    required List<Template> templates,
    required Set<String> freeIds,
    required bool isPremiumUser,
    required String localeCode,
    required List<Dispute> disputes,
  }) {
    final selected = _selectedDispute(disputes);
    final tc = AppThemeColors.of(context);
    final repo = ref.read(templateRepositoryProvider);
    final filtered = _selectedCategory == 'All'
        ? templates
        : templates.where((t) => t.category == _selectedCategory).toList();
    final totalCount = templates.length;

    return Column(
      children: [
        // header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Templates',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: tc.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'RBI-compliant dispute letters',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: tc.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (disputes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: DropdownButtonFormField<String>(
              initialValue: selected?.id,
              decoration: InputDecoration(
                labelText: 'Fill from dispute',
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
              ),
              items: [
                for (final d in disputes)
                  DropdownMenuItem(
                    value: d.id,
                    child: Text(
                      // LO-1: Indian-grouped amount in the dispute selector.
                      '${d.entityName ?? d.type.id} · ₹${IndianNumberFormatter.format(d.amount)}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (id) => setState(() => _selectedDisputeId = id),
            ),
          ),
        // filter pills
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: FilterPills(
            pills: _categories
                .map(
                  (c) => (
                    label: c == 'All' ? 'All $totalCount' : c,
                    selected: _selectedCategory == c,
                    onTap: () => setState(() => _selectedCategory = c),
                  ),
                )
                .toList(),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            itemCount: filtered.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (c, i) {
              final t = filtered[i];
              final locked = repo.isLocked(
                t,
                freeIds,
                isPremiumUser: isPremiumUser,
              );
              return _TemplateCard(
                template: t,
                locked: locked,
                localeCode: localeCode,
                onTap: () {
                  if (locked) {
                    _showLockedPreview(
                      c,
                      t,
                      localeCode,
                      dispute: selected,
                    );
                  } else {
                    _showTemplatePreview(c, t, localeCode, dispute: selected);
                  }
                },
              );
            },
          ),
        ),
        // sources footer
        Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          color: tc.surfaceAlt,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('📚', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Sources · RBI Master Directions DPSS.CO.PD.No.629/02.03.001 (2018) · Banking Ombudsman Scheme 2006 · NPCI FASTag dispute guidelines',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: tc.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showTemplatePreview(
    BuildContext context,
    Template t,
    String localeCode, {
    Dispute? dispute,
  }) {
    final l10n = AppLocalizations.of(context);
    final body = filledTemplateBody(t, localeCode, dispute);
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(t.titleFor(localeCode)),
        content: SingleChildScrollView(child: SelectableText(body)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text(l10n?.commonClose ?? 'Close'),
          ),
          FilledButton(
            onPressed: () => Clipboard.setData(ClipboardData(text: body)),
            child: Text(l10n?.ombudsmanCopy ?? 'Copy'),
          ),
        ],
      ),
    );
  }

  /// Task 7.3 — locked-card tap opens a bottom sheet with a blurred body
  /// preview and an "Unlock with Premium" CTA (rather than jumping straight
  /// to the paywall). Users can read the first part of the template to
  /// decide whether it's worth buying, then tap through to the paywall with
  /// the template's id/title already wired through `paywallWithParams`.
  void _showLockedPreview(
    BuildContext context,
    Template t,
    String localeCode, {
    Dispute? dispute,
  }) {
    final tc = AppThemeColors.of(context);
    final l10n = AppLocalizations.of(context);
    final body = filledTemplateBody(t, localeCode, dispute);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: tc.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: tc.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Title + Pro badge
              Row(
                children: [
                  Expanded(
                    child: Text(
                      t.titleFor(localeCode),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: tc.textPrimary,
                      ),
                    ),
                  ),
                  StatusPill(
                    label: l10n?.templateProBadge ?? 'Pro',
                    fg: AppColors.premiumGold,
                    bg: tc.premiumGoldSoft,
                    prefix: '🔒',
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${t.category} · Level ${t.escalationLevel}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: tc.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              // Blurred preview — show the top ~30% of the template body
              // behind a soft scrim so the user gets a sense of structure
              // without being able to read the full text. The remaining
              // lines are masked by a gradient fade to "Locked to continue".
              Stack(
                children: [
                  // Faded/blurred preview text.
                  ClipRect(
                    child: Container(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.22,
                      ),
                      child: SingleChildScrollView(
                        physics: const NeverScrollableScrollPhysics(),
                        child: Text(
                          body,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: tc.textSecondary,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Gradient fade to "locked" affordance.
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              tc.surface.withValues(alpha: 0),
                              tc.surface.withValues(alpha: 0.6),
                              tc.surface.withValues(alpha: 1),
                            ],
                            stops: const [0.45, 0.75, 1],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // CTA: Unlock with Premium → paywall with template context
              // (Task 7.4). The paywall headline names this template.
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(c);
                    context.push(
                      AppRoutes.paywallWithParams(
                        trigger: 'template_locked',
                        returnPath: AppRoutes.templates,
                        templateId: t.id,
                        templateTitle: t.titleFor(localeCode),
                      ),
                    );
                  },
                  icon: const Icon(Icons.lock_open, size: 18),
                  label: Text(
                    l10n?.templateUnlockCta ?? 'Unlock with Premium',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: Text(
                  l10n?.commonClose ?? 'Close',
                  style: TextStyle(color: tc.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Template card matching mockup Screen 10. Each card has:
/// - soft-color emoji tile, title, level/category subtitle,
/// - "Used N×" / "New" / 🔒 chip on the right,
/// - body preview (2-line clamp), and footer row with reference + Use → link.
class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.locked,
    required this.localeCode,
    required this.onTap,
  });

  final Template template;
  final bool locked;
  final String localeCode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tc = AppThemeColors.of(context);
    final levelBadge = locked
        ? StatusPill(
            label: l10n?.templateProBadge ?? 'Pro',
            fg: AppColors.premiumGold,
            bg: tc.premiumGoldSoft,
            prefix: '🔒',
          )
        : StatusPill(
            label:
                l10n?.templateLevelLabel(template.escalationLevel) ??
                'Level ${template.escalationLevel}',
            fg: AppColors.accent,
            bg: tc.accentSoft,
          );

    // Body preview: render the actual template body (tokens fill with
    // fallbacks without a dispute) so the user sees what they'd unlock —
    // matches the Escalate picker's preview. Locked cards keep the Pro
    // badge + "Unlock →" CTA below to signal the paywall (Task 7.2).
    final preview = filledTemplateBody(template, localeCode, null);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: tc.surface,
          border: Border.all(color: tc.divider, width: 1),
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon tile
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _softColorFor(template.category, tc),
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              child: Center(
                child: Text(
                  _emojiFor(template.category, template.escalationLevel),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Body
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          template.titleFor(localeCode),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: tc.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      levelBadge,
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${template.category} · Level ${template.escalationLevel}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: tc.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    preview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: tc.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'RBI/NPCI compliant',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      Text(
                        locked ? 'Unlock →' : 'Use →',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accent,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _softColorFor(String category, AppThemeColors tc) => switch (category) {
    'UPI / IMPS / ATM' => tc.alertSoft,
    'FASTag' => tc.accentSoft,
    'Advanced / legal' => tc.premiumGoldSoft,
    _ => tc.surfaceAlt,
  };

  String _emojiFor(String category, int level) => switch (category) {
    'UPI / IMPS / ATM' => '📧',
    'FASTag' => '🚗',
    'Advanced / legal' => '🏛️',
    _ => '📄',
  };
}
