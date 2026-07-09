import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:refund_radar/core/providers/auth_provider.dart';
import 'package:refund_radar/core/providers/dispute_provider.dart';
import 'package:refund_radar/core/theme/app_theme_colors.dart';
import 'package:refund_radar/core/theme/app_tokens.dart';
import 'package:refund_radar/data/models/dispute.dart';
import 'package:refund_radar/l10n/app_localizations.dart';
import 'package:refund_radar/services/compensation_calculator.dart';
import 'package:refund_radar/shared/widgets/owed_counter_card.dart';
import 'package:refund_radar/shared/widgets/dispute_card.dart';
import 'package:refund_radar/shared/widgets/branded_error_banner.dart';
import 'package:refund_radar/shared/widgets/skeleton.dart';

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
              return BrandedErrorBanner(
                message:
                    'Could not sign in. Check your connection and try again.',
                onRetry: () async {
                  await ref.read(reauthProvider)();
                  ref.invalidate(userIdProvider);
                },
              );
            }
            final disputesAsync = ref.watch(disputesProvider(uid));
            return disputesAsync.when(
              data: (disputes) => _Body(disputes: disputes),
              loading: () => const _Loading(),
              error: (e, _) => BrandedErrorBanner(
                message: _friendlyError(e),
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
            message: _friendlyError(e),
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
            child: Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(AppRadii.pill),
                boxShadow: AppShadows.fab,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  onTap: () => context.push('/disputes/create'),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        AppLocalizations.of(context)?.homeNewDispute ??
                            'New dispute',
                        style: const TextStyle(
                          fontFamily: AppTypography.family,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Map raw Firebase exceptions to short, user-facing copy. Never dump
  /// `[cloud_firestore/permission-denied] ...` into the UI.
  static String _friendlyError(Object e) {
    final s = e.toString().toLowerCase();
    if (s.contains('permission-denied') || s.contains('permission_denied')) {
      return 'Could not load your disputes. Pull to retry — if this keeps happening, sign out and back in from Settings.';
    }
    if (s.contains('unavailable') ||
        s.contains('network') ||
        s.contains('socket')) {
      return 'You appear to be offline. Check your connection and retry.';
    }
    if (s.contains('unauthenticated')) {
      return 'Session expired. Tap Retry to sign in again.';
    }
    return 'Could not load disputes. Tap Retry.';
  }
}

class _Body extends StatelessWidget {
  final List<Dispute> disputes;
  const _Body({required this.disputes});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tc = AppThemeColors.of(context);
    if (disputes.isEmpty) return const _EmptyState();
    final totalOwed = disputes.fold<double>(
        0, (sum, d) => sum + CompensationCalculator.compute(d).compensationDue);
    final perDay = disputes.fold<double>(
        0, (sum, d) => sum + (d.type.compensationPerDay ?? 0).toDouble());

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
      children: [
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
                  onTap: () => context.push('/reminders'),
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
                  onTap: () => context.push('/templates'),
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
                  onTap: () => context.push('/settings'),
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
        ),
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
              onTap: () => context.push('/history'),
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
                onTap: () => context.push('/disputes/${d.id}'),
              ),
            )),
      ],
    );
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
              'No disputes yet',
              style: TextStyle(
                fontFamily: AppTypography.family,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: tc.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
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
            Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(AppRadii.md),
                boxShadow: AppShadows.button,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  onTap: () => context.push('/disputes/create'),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Add dispute',
                        style: TextStyle(
                          fontFamily: AppTypography.family,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
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
