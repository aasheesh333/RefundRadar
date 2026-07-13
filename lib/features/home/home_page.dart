import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:refund_radar/core/providers/auth_provider.dart';
import 'package:refund_radar/core/providers/dispute_provider.dart';
import 'package:refund_radar/core/providers/utr_detection_provider.dart';
import 'package:refund_radar/core/theme/app_theme_colors.dart';
import 'package:refund_radar/core/theme/app_tokens.dart';
import 'package:refund_radar/data/models/dispute.dart';
import 'package:refund_radar/data/models/utr_detection.dart';
import 'package:refund_radar/l10n/app_localizations.dart';
import 'package:refund_radar/services/compensation_calculator.dart';
import 'package:refund_radar/shared/widgets/owed_counter_card.dart';
import 'package:refund_radar/shared/widgets/dispute_card.dart';
import 'package:refund_radar/shared/widgets/branded_error_banner.dart';
import 'package:refund_radar/shared/widgets/skeleton.dart';
import 'package:refund_radar/shared/utils/error_mapper.dart';
import 'package:refund_radar/core/router/app_routes.dart';

/// Non-terminal disputes shown on Home (active only).
/// Drafts are excluded — an incomplete dispute shouldn't inflate the
/// "You're owed" counter or clutter the active list.
List<Dispute> activeHomeDisputes(List<Dispute> disputes) => disputes
    .where((d) =>
        d.status != DisputeStatus.resolved &&
        d.status != DisputeStatus.expired &&
        d.status != DisputeStatus.draft)
    .toList();

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uidAsync = ref.watch(userIdProvider);
    final tc = AppThemeColors.of(context);
    return Scaffold(
      backgroundColor: tc.bg,
      body: SafeArea(
        child: uidAsync.when(
          data: (uid) {
            if (uid == null) {
              final authErr = ref.watch(lastAuthErrorProvider);
              return BrandedErrorBanner(
                message: authErr != null &&
                        authErr.toLowerCase().contains('operation-not-allowed')
                    ? 'Anonymous sign-in is disabled. Enable it in Firebase Console → Authentication → Sign-in method → Anonymous.'
                    : 'Could not sign in. Check your connection and try again.',
                detail: authErr,
                onRetry: () async {
                  await ref.read(reauthProvider)();
                  ref.invalidate(userIdProvider);
                },
              );
            }
            final disputesAsync = ref.watch(disputesProvider(uid));
            return disputesAsync.when(
              data: (disputes) =>
                  _Body(disputes: activeHomeDisputes(disputes)),
              loading: () => const _Loading(),
              error: (e, _) => BrandedErrorBanner(
                message: friendlyError(e),
                detail: errorDetail(e),
                onRetry: () async {
                  await ref.read(reauthProvider)();
                  ref.invalidate(userIdProvider);
                  ref.invalidate(disputesProvider(uid));
                },
              ),
            );
          },
          loading: () => const _Loading(),
          error: (e, _) => BrandedErrorBanner(
            message: friendlyError(e),
            detail: errorDetail(e),
            onRetry: () async {
              await ref.read(reauthProvider)();
              ref.invalidate(userIdProvider);
            },
          ),
        ),
      ),
      floatingActionButton: Padding(
        // SafeArea-aware: honour system inset (notch / gesture nav) on the
        // right + bottom so the FAB doesn't get clipped on landscape or
        // ROM-gesture phones. Manual 16dp fallback when inset is 0.
        padding: EdgeInsets.only(
          right: 16 + MediaQuery.of(context).padding.right,
          bottom: 16 + MediaQuery.of(context).padding.bottom,
        ),
        child: Tooltip(
          message: AppLocalizations.of(context)?.homeNewDispute ?? 'New dispute',
          child: Semantics(
            button: true,
            label: AppLocalizations.of(context)?.homeNewDispute ?? 'New dispute',
            child: Builder(builder: (context) {
              final tc = AppThemeColors.of(context);
              return Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: tc.ctaBackground,
                borderRadius: BorderRadius.circular(AppRadii.pill),
                boxShadow: AppShadows.fab,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  onTap: () => context.push(AppRoutes.disputesCreate),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, color: tc.ctaForeground, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        AppLocalizations.of(context)?.homeNewDispute ??
                            'New dispute',
                        style: TextStyle(
                          fontFamily: AppTypography.family,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: tc.ctaForeground,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
            }),
          ),
        ),
      ),
    );
  }

}

class _Body extends ConsumerWidget {
  final List<Dispute> disputes;
  const _Body({required this.disputes});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tc = AppThemeColors.of(context);
    final detections = ref.watch(utrDetectionsProvider);
    if (disputes.isEmpty && detections.isEmpty) return const _EmptyState();
    final disputedSum = disputes.fold<double>(0, (sum, d) => sum + d.amount);
    final penaltySum = disputes.fold<double>(
        0, (sum, d) => sum + CompensationCalculator.compute(d).compensationDue);
    final totalOwed = disputedSum + penaltySum;
    final perDay = disputes.fold<double>(
        0, (sum, d) => sum + (d.type.compensationPerDay ?? 0).toDouble());
    final breakdown = l10n?.homeBreakdownDisputed(
          _formatIndian(disputedSum),
          _formatIndian(penaltySum),
        ) ??
        '₹${_formatIndian(disputedSum)} disputed · ₹${_formatIndian(penaltySum)} penalty accrued';

    // Build a list of widgets so we can splice the detected-transactions
    // banner before the disputes when there are unclaimed detections.
    final children = <Widget>[
      // header
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)?.appName ?? 'Refund Radar',
                  style: const TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  l10n?.homeActiveDisputes(disputes.length) ??
                      '${disputes.length} active ${disputes.length == 1 ? 'dispute' : 'disputes'}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: tc.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Tooltip(
            message: 'Reminders',
            child: Semantics(
              button: true,
              label: 'Reminders',
              child: InkWell(
                onTap: () => context.push(AppRoutes.reminders),
                borderRadius: BorderRadius.circular(24),
                child: const SizedBox(
                  width: 48,
                  height: 48,
                  child: Icon(Icons.notifications_outlined,
                      size: 22, color: AppColors.primary),
                ),
              ),
            ),
          ),
          Tooltip(
            message: 'Templates',
            child: Semantics(
              button: true,
              label: 'Templates',
              child: InkWell(
                onTap: () => context.push(AppRoutes.templates),
                borderRadius: BorderRadius.circular(24),
                child: const SizedBox(
                  width: 48,
                  height: 48,
                  child: Icon(Icons.description_outlined,
                      size: 22, color: AppColors.primary),
                ),
              ),
            ),
          ),
          Tooltip(
            message: AppLocalizations.of(context)?.settingsTitle ?? 'Settings',
            child: Semantics(
              button: true,
              label: AppLocalizations.of(context)?.settingsTitle ?? 'Settings',
              child: InkWell(
                onTap: () => context.push(AppRoutes.settings),
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: tc.surfaceAlt,
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: AppColors.premiumGold, width: 2),
                    ),
                    child: const Center(
                      child: Text(
                        'A',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      OwedCounterCard(
        totalOwed: totalOwed,
        disputeCount: disputes.length,
        perDay: perDay,
        breakdown: breakdown,
      ),
    ];

    // Detected transactions banner (Task C8). Only show when there are
    // unclaimed detections. Each card taps through to the dispute form
    // pre-filled; dismiss removes the detection from the running list.
    if (detections.isNotEmpty) {
      children
        ..add(const SizedBox(height: 14))
        ..add(_DetectedTransactionsSection(detections: detections));
    }

    if (disputes.isNotEmpty) {
      children.addAll([
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Active disputes',
              style: TextStyle(
                fontFamily: AppTypography.family,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: tc.textPrimary,
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => context.push(AppRoutes.history),
              child: Semantics(
                button: true,
                label: l10n?.homeViewAllDisputes ?? 'View all disputes',
                child: Container(
                  // 48dp minimum tap target; text stays 12px visually.
                  padding: const EdgeInsets.symmetric(
                      horizontal: 4, vertical: 14),
                  child: Text(
                    l10n?.homeViewAllDisputes ?? 'View all →',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.accent,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...disputes.map((d) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: DisputeCard(
                dispute: d,
                onTap: () => context.push(AppRoutes.disputeDetail(d.id)),
              ),
            )),
      ]);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
      children: children,
    );
  }

  /// Format an amount using the Indian numbering system (e.g. 1,00,000)
  /// without the leading ₹ symbol — matches OwedCounterCard._formatIndian
  /// so the breakdown subtitle uses the same digit grouping as the hero.
  static String _formatIndian(double amount) {
    final str = amount.toStringAsFixed(0);
    final parts = <String>[];
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      if (count == 3) {
        parts.insert(0, ',');
      } else if (count > 3 && count % 2 == 1) {
        parts.insert(0, ',');
      }
      parts.insert(0, str[i]);
      count++;
    }
    return parts.join();
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: tc.accentSoft,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('💰', style: TextStyle(fontSize: 36)),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              AppLocalizations.of(context)?.homeEmptyTitle ?? 'No disputes yet',
              style: TextStyle(
                fontFamily: AppTypography.family,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: tc.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              AppLocalizations.of(context)?.homeEmptySubtitle ??
                  'Add your first stuck transaction to start tracking compensation.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: tc.textSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),
            Builder(builder: (context) {
              final cta = AppThemeColors.of(context);
              return Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: cta.ctaBackground,
                borderRadius: BorderRadius.circular(AppRadii.md),
                boxShadow: AppShadows.button,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  onTap: () => context.push(AppRoutes.disputesCreate),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, color: cta.ctaForeground, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        AppLocalizations.of(context)?.homeAddDispute ??
                            'Add dispute',
                        style: TextStyle(
                          fontFamily: AppTypography.family,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: cta.ctaForeground,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
            }),
          ],
        ),
      ),
    );
  }
}

/// Detected-transactions banner section (Task C8). Renders one card per
/// unclaimed [UtrDetection]; tapping the card opens the dispute form
/// pre-filled and marks the detection claimed, the dismiss button drops
/// the detection from the running session list.
class _DetectedTransactionsSection extends ConsumerWidget {
  final List<UtrDetection> detections;
  const _DetectedTransactionsSection({required this.detections});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tc = AppThemeColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('🔍', style: TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              l10n?.homeDetectedTitle ?? 'Detected transactions',
              style: TextStyle(
                fontFamily: AppTypography.family,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: tc.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          l10n?.homeDetectedSubtitle ??
              'Auto-detected from incoming SMS — tap to claim or dismiss.',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w400,
            color: tc.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 10),
        ...detections.map((d) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _DetectedCard(detection: d),
            )),
      ],
    );
  }
}

class _DetectedCard extends ConsumerWidget {
  final UtrDetection detection;
  const _DetectedCard({required this.detection});

  /// Format an integer amount using the Indian numbering system
  /// (1,00,000 etc.) without the leading ₹ symbol — matches the rest of
  /// the home page's grouping.
  static String _formatIndianAmount(double amount) {
    final str = amount.toStringAsFixed(0);
    final parts = <String>[];
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      if (count == 3) {
        parts.insert(0, ',');
      } else if (count > 3 && count % 2 == 1) {
        parts.insert(0, ',');
      }
      parts.insert(0, str[i]);
      count++;
    }
    return parts.join();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tc = AppThemeColors.of(context);
    final amountStr = detection.amount != null
        ? _formatIndianAmount(detection.amount!)
        : '--';
    final sender =
        detection.sender.isEmpty ? 'Unknown sender' : detection.sender;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: tc.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.35),
          width: 1,
        ),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: tc.accentSoft,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('UTR', style: TextStyle(fontSize: 11)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n?.homeDetectedCardAmount(amountStr, sender) ??
                      '₹$amountStr · $sender',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: tc.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n?.homeDetectedCardUtr(detection.utr) ??
                      'UTR ${detection.utr}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: tc.textSecondary,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Dismiss — drops the detection from the running list.
          Tooltip(
            message: l10n?.homeDetectedDismiss ?? 'Dismiss',
            child: Semantics(
              button: true,
              label: l10n?.homeDetectedDismiss ?? 'Dismiss',
              child: InkWell(
                onTap: () => ref
                    .read(utrDetectionsProvider.notifier)
                    .markClaimed(detection.utr),
                borderRadius: BorderRadius.circular(20),
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child:
                      Icon(Icons.close, size: 18, color: AppColors.alert),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Claim — deep-link to the dispute form pre-filled.
          FilledButton(
            onPressed: () {
              // Mark claimed so the banner disappears; tap the router.
              ref
                  .read(utrDetectionsProvider.notifier)
                  .markClaimed(detection.utr);
              final target = AppRoutes.disputesFormWithParams(
                type: 'upi_p2p',
                utr: detection.utr,
                amount: detection.amount?.toStringAsFixed(0),
                sender: detection.sender.isNotEmpty ? detection.sender : null,
              );
              context.push(target);
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
            ),
            child: Text(
              l10n?.homeDetectedClaim ?? 'Claim →',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) {
    // Skeleton list rather than a spinner — the home page renders a
    // stack of dispute cards, so the placeholder should mimic them.
    return const SkeletonList(itemCount: 4, itemHeight: 110);
  }
}
