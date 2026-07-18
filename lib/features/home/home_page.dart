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
import 'package:refund_radar/shared/utils/indian_number_formatter.dart';
import 'package:refund_radar/core/router/app_routes.dart';
import 'package:refund_radar/core/providers/app_state_provider.dart';

List<Dispute> activeHomeDisputes(List<Dispute> disputes) => disputes
    .where((d) =>
        d.status != DisputeStatus.resolved &&
        d.status != DisputeStatus.expired)
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
    final isPremium = ref.watch(isPremiumProvider);
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

    final children = <Widget>[
      _PageHeader(disputeCount: disputes.length, tc: tc, l10n: l10n),
      const SizedBox(height: 12),
      OwedCounterCard(
        totalOwed: totalOwed,
        disputeCount: disputes.length,
        perDay: perDay,
        breakdown: breakdown,
      ),
    ];

    if (!isPremium) {
      children
        ..add(const SizedBox(height: 14))
        ..add(const _HomeProUpsellCard());
    }

    if (detections.isNotEmpty) {
      children
        ..add(const SizedBox(height: 18))
        ..add(_DetectedTransactionsSection(detections: detections));
    }

    if (disputes.isNotEmpty) {
      children.addAll([
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n?.homeActiveDisputesTitle ?? 'Active disputes',
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 4, vertical: 14),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n?.homeViewAllDisputes ?? 'View all',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: tc.ctaBackground,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.arrow_forward,
                          size: 13, color: tc.ctaBackground),
                    ],
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

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          sliver: SliverList.list(children: children),
        ),
      ],
    );
  }

  static String _formatIndian(double amount) =>
      IndianNumberFormatter.format(amount);
}

class _PageHeader extends StatelessWidget {
  final int disputeCount;
  final AppThemeColors tc;
  final AppLocalizations? l10n;
  const _PageHeader({
    required this.disputeCount,
    required this.tc,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)?.appName ?? 'Refund Radar',
                  style: TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: tc.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  l10n?.homeActiveDisputes(disputeCount) ??
                      '$disputeCount active ${disputeCount == 1 ? 'dispute' : 'disputes'}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: tc.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: l10n?.homeRemindersTooltip ?? 'Reminders',
            icon: Icon(Icons.notifications_outlined,
                size: 21, color: tc.textPrimary),
            onPressed: () => context.push(AppRoutes.reminders),
          ),
          IconButton(
            tooltip: l10n?.homeTemplatesTooltip ?? 'Templates',
            icon: Icon(Icons.description_outlined,
                size: 21, color: tc.textPrimary),
            onPressed: () => context.push(AppRoutes.templates),
          ),
          GestureDetector(
            onTap: () => context.push(AppRoutes.settings),
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tc.surfaceAlt,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.premiumGold, width: 1.5),
              ),
              child: Text(
                'A',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: tc.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tc.surfaceAlt,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('💰', style: TextStyle(fontSize: 36)),
            ),
            const SizedBox(height: 20),
            Text(
              l10n?.homeEmptyTitle ?? 'No disputes yet',
              style: TextStyle(
                fontFamily: AppTypography.family,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: tc.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n?.homeEmptySubtitle ??
                  'Add your first stuck transaction to start tracking compensation.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: tc.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: tc.ctaBackground,
                foregroundColor: tc.ctaForeground,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
              ),
              onPressed: () => context.push(AppRoutes.disputesCreate),
              icon: const Icon(Icons.add, size: 18),
              label: Text(l10n?.homeAddDispute ?? 'Add dispute'),
            ),
          ],
        ),
      ),
    );
  }
}

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
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tc.accentSoft,
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              child: const Text('🔍', style: TextStyle(fontSize: 11)),
            ),
            const SizedBox(width: 8),
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

  static String _formatIndianAmount(double amount) =>
      IndianNumberFormatter.format(amount);

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
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: tc.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tc.accentSoft,
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: Text(
              'UTR',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: tc.ctaBackground,
              ),
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
                    fontFamily: AppTypography.family,
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
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(Icons.close,
                      size: 16, color: tc.textTertiary),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          FilledButton(
            onPressed: () {
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
              backgroundColor: tc.ctaBackground,
              foregroundColor: tc.ctaForeground,
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
    return const SkeletonList(itemCount: 4, itemHeight: 110);
  }
}

class _HomeProUpsellCard extends StatelessWidget {
  const _HomeProUpsellCard();
  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    final l10n = AppLocalizations.of(context);
    return GestureDetector(
      onTap: () => context.push(
        AppRoutes.paywallWithParams(
          trigger: 'home_banner',
          returnPath: AppRoutes.home,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: tc.surface,
          border: Border.all(color: AppColors.premiumGold, width: 1),
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tc.premiumGoldSoft,
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              child: const Icon(
                Icons.workspace_premium,
                color: AppColors.premiumGold,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n?.homeUpsellTitle ??
                        'Recover every rupee with Pro',
                    style: TextStyle(
                      fontFamily: AppTypography.family,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: tc.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n?.homeUpsellBody ??
                        'Unlimited disputes, 50+ templates, Ombudsman generator.',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: tc.textSecondary,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.premiumGold,
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              child: Text(
                l10n?.homeUpsellCta ?? 'Upgrade',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
