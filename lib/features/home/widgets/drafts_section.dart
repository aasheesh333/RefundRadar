import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:refund_radar/core/theme/app_theme_colors.dart';
import 'package:refund_radar/core/theme/app_tokens.dart';
import 'package:refund_radar/data/extensions/dispute_type_display.dart';
import 'package:refund_radar/data/models/dispute.dart';
import 'package:refund_radar/data/models/dispute_draft.dart';
import 'package:refund_radar/data/repositories/draft_repository.dart';
import 'package:refund_radar/l10n/app_localizations.dart';

/// Home screen "Drafts" section: lists device-local in-progress disputes
/// persisted by [DraftRepository]. Renders NOTHING when there are no
/// drafts (AsyncData of an empty list, or error/loading — drafts are a
/// nicety, never worth an error banner on home).
///
/// Each row is swipe-to-delete (red background) and tap pre-fills the
/// create flow via [onTap].
class DraftsSection extends ConsumerWidget {
  final void Function(DisputeDraft draft) onTap;
  const DraftsSection({super.key, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draftsAsync = ref.watch(draftsProvider);
    final drafts = draftsAsync.asData?.value ?? const <DisputeDraft>[];
    if (drafts.isEmpty) return const SizedBox.shrink();

    final tc = AppThemeColors.of(context);

    return Semantics(
      container: true,
      label: 'Drafts',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
            child: Row(
              children: [
                Text(
                  'Drafts',
                  style: AppTypography.h3(color: tc.textPrimary),
                ),
                const SizedBox(width: 6),
                Text(
                  '(${drafts.length})',
                  style: AppTypography.micro(color: tc.textSecondary),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: tc.surface,
              border: Border.all(color: tc.divider, width: 1),
              borderRadius: BorderRadius.circular(AppRadii.lg),
              boxShadow: AppShadows.card,
            ),
            child: Column(
              children: [
                for (var i = 0; i < drafts.length; i++) ...[
                  if (i > 0)
                    Divider(height: 1, thickness: 1, color: tc.divider),
                  _DraftRow(
                    key: ValueKey(drafts[i].id),
                    draft: drafts[i],
                    onTap: () => onTap(drafts[i]),
                    onDismissed: () => ref
                        .read(draftRepositoryProvider)
                        .delete(drafts[i].id),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DraftRow extends ConsumerWidget {
  final DisputeDraft draft;
  final VoidCallback onTap;
  final VoidCallback onDismissed;
  const _DraftRow({
    super.key,
    required this.draft,
    required this.onTap,
    required this.onDismissed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tc = AppThemeColors.of(context);
    final type = _typeFor(draft.typeId);

    return Dismissible(
      key: ValueKey('draft_${draft.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismissed(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: Semantics(
        button: true,
        label: _semanticLabel(context, type),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Soft-tinted type tile, mirroring DisputeCard.
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: type != null
                        ? type.softColorFor(tc)
                        : tc.bg,
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                  ),
                  child: Center(
                    child: Icon(
                      type?.icon ?? Icons.edit_note,
                      size: 20,
                      color: type?.iconColor ?? tc.textSecondary,
                      semanticLabel: _title(context, type),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _title(context, type),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: tc.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Saved ${_relativeAge(draft.savedAt)}',
                        style: AppTypography.micro(color: tc.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right,
                    size: 20, color: tc.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Resolve the stored `DisputeType.id` back to the enum WITHOUT the
  /// `fromId` fallback-to-upiP2p behaviour — an unrecognised/empty typeId
  /// must render as "Untitled draft", not mislabel the row as UPI.
  static DisputeType? _typeFor(String? typeId) {
    if (typeId == null) return null;
    for (final t in DisputeType.values) {
      if (t.id == typeId) return t;
    }
    return null;
  }

  String _title(BuildContext context, DisputeType? type) =>
      // Only non-null l10n keys used; new draft strings are hardcoded
      // English (fallbacks) until l10n keys are generated.
      type?.localizedName(AppLocalizations.of(context)) ?? 'Untitled draft';

  String _semanticLabel(BuildContext context, DisputeType? type) {
    final base = _title(context, type);
    return '$base, draft, saved ${_relativeAge(draft.savedAt)}';
  }

  /// Compact relative time: "just now", "Xm", "Xh", "Xd". No intl
  /// dependency required — the home card style is already compact
  /// ("Day N of M").
  static String _relativeAge(DateTime savedAt) {
    final d = DateTime.now().difference(savedAt);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }
}
