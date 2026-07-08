import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/providers/theme_provider.dart';
import '../../data/models/template.dart';
import '../../data/repositories/rules_engine_repository.dart';
import '../../data/repositories/template_repository.dart';
import '../../shared/widgets/filter_pills.dart';
import '../../shared/widgets/status_pill.dart';
import 'package:refund_radar/shared/widgets/branded_error_banner.dart';
import 'package:refund_radar/shared/widgets/skeleton.dart';

class TemplateLibraryPage extends ConsumerStatefulWidget {
  const TemplateLibraryPage({super.key});
  @override
  ConsumerState<TemplateLibraryPage> createState() =>
      _TemplateLibraryPageState();
}

class _TemplateLibraryPageState extends ConsumerState<TemplateLibraryPage> {
  String _selectedCategory = 'All';
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
    final templatesAsync = ref.watch(templatesProvider);
    final rulesAsync = ref.watch(rulesEngineProvider);
    final locale = ref.watch(localeProvider);
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: SafeArea(
        child: templatesAsync.when(
          data: (templates) =>
              rulesAsync.when(
                data: (rules) => _buildBody(
                  templates: templates,
                  freeIds: rules.freeTemplateIds.toSet(),
                  localeCode: locale.languageCode,
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

  Widget _buildBody({
    required List<Template> templates,
    required Set<String> freeIds,
    required String localeCode,
  }) {
    final repo = ref.read(templateRepositoryProvider);
    final filtered = _selectedCategory == 'All'
        ? templates
        : templates
            .where((t) => t.category == _selectedCategory)
            .toList();
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
                  children: const [
                    Text(
                      'Templates',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimaryLight,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'RBI-compliant dispute letters',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add,
                  size: 20,
                  color: Colors.white,
                ),
              ),
            ],
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
              final locked = repo.isLocked(t, freeIds);
              return _TemplateCard(
                template: t,
                locked: locked,
                localeCode: localeCode,
                onTap: () {
                  if (locked) {
                    context.push(
                      '/paywall?return=/templates&trigger=template_locked',
                    );
                  } else {
                    _showTemplatePreview(c, t, localeCode);
                  }
                },
              );
            },
          ),
        ),
        // sources footer
        Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          color: AppColors.surfaceAltLight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('📚', style: TextStyle(fontSize: 14)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Sources · RBI Master Directions DPSS.CO.PD.No.629/02.03.001 (2018) · Banking Ombudsman Scheme 2006 · NPCI FASTag dispute guidelines',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondaryLight,
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
    String localeCode,
  ) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(t.titleFor(localeCode)),
        content: SingleChildScrollView(
          child: SelectableText(t.bodyFor(localeCode)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () => Clipboard.setData(
              ClipboardData(text: t.bodyFor(localeCode)),
            ),
            child: const Text('Copy'),
          ),
        ],
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
    final levelBadge = locked
        ? const StatusPill(
            label: 'Pro',
            fg: AppColors.premiumGold,
            bg: AppColors.premiumGoldSoft,
            prefix: '🔒',
          )
        : StatusPill(
            label: 'Level ${template.escalationLevel}',
            fg: AppColors.accent,
            bg: AppColors.accentSoft,
          );

    // Body preview: locked templates get a blur-style masked preview. We use
    // a simple 2-line UIL-clip; actual on-screen blur is by ObscureText in
    // the full preview dialog. For now, locked preview shows a generic
    // placeholder hint.
    final preview = locked
        ? 'Tap to unlock with Premium — 50+ RBI-compliant templates.'
        : template.bodyFor(localeCode);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          border: Border.all(color: AppColors.dividerLight, width: 1),
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
                color: _softColorFor(template.category),
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
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimaryLight,
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
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    preview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textSecondaryLight,
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

  Color _softColorFor(String category) => switch (category) {
        'UPI / IMPS / ATM' => AppColors.alertSoft,
        'FASTag' => AppColors.accentSoft,
        'Advanced / legal' => AppColors.premiumGoldSoft,
        _ => AppColors.surfaceAltLight,
      };

  String _emojiFor(String category, int level) => switch (category) {
        'UPI / IMPS / ATM' => '📧',
        'FASTag' => '🚗',
        'Advanced / legal' => '🏛️',
        _ => '📄',
      };
}
