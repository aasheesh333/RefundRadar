import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:refund_radar/core/router/app_routes.dart';
import 'package:refund_radar/core/providers/auth_provider.dart';
import 'package:refund_radar/core/providers/dispute_provider.dart';
import 'package:refund_radar/core/theme/app_theme_colors.dart';
import 'package:refund_radar/core/theme/app_tokens.dart';
import 'package:refund_radar/data/extensions/dispute_type_display.dart';
import 'package:refund_radar/data/extensions/dispute_outcome.dart';
import 'package:refund_radar/data/models/dispute.dart';
import 'package:refund_radar/l10n/app_localizations.dart';
import 'package:refund_radar/services/compensation_calculator.dart';
import 'package:refund_radar/shared/utils/date_time_ext.dart';
import 'package:refund_radar/shared/widgets/branded_error_banner.dart';
import 'package:refund_radar/shared/utils/error_mapper.dart';
import 'package:refund_radar/shared/widgets/skeleton.dart';

/// Wave 3 redesign — clean-minimal Material 3 ledger of past disputes.
///
/// Same data flow as the previous History screen (filter pills,
/// win-rate stats, card list) but with a fully new visual treatment:
///   - Compact sticky page header with back arrow, big title and an
///     unobtrusive "Add dispute" CTA.
///   - Single-line stat strip below the header (replaces the two
///     stat boxes + side caption).
///   - Pill tabs segment the data (All / Won / Lost / Escalated) with
///     a sliding selection background.
///   - Bottom border on cards (no double border / shadow).
///   - Empty state with a single CTA.
bool isEscalatedDispute(Dispute d) {
  if (d.status == DisputeStatus.filedL2 ||
      d.status == DisputeStatus.ombudsman) {
    return true;
  }
  final past = d.status == DisputeStatus.resolved ||
      d.status == DisputeStatus.expired;
  if (!past) return false;
  return d.filedDates['l2'] != null ||
      d.filedDates['ombudsman'] != null ||
      d.filedDates['l3'] != null;
}

List<Dispute> filterHistoryDisputes(List<Dispute> disputes, String filter) {
  final past = disputes
      .where((d) =>
          d.status == DisputeStatus.resolved ||
          d.status == DisputeStatus.expired)
      .toList();
  switch (filter) {
    case 'Won':
      return past.where((d) => d.isWon).toList();
    case 'Lost':
      return past.where((d) => d.isLost).toList();
    case 'Escalated':
      return disputes.where(isEscalatedDispute).toList();
    default:
      return past;
  }
}

class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});
  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tc = AppThemeColors.of(context);
    final uidAsync = ref.watch(userIdProvider);
    final filters = <_FilterChip>[
      _FilterChip(id: 'All', label: l10n?.historyFilterAll ?? 'All'),
      _FilterChip(id: 'Won', label: l10n?.historyFilterWon ?? 'Won'),
      _FilterChip(id: 'Lost', label: l10n?.historyFilterLost ?? 'Lost'),
      _FilterChip(
          id: 'Escalated',
          label: l10n?.historyFilterEscalated ?? 'Escalated'),
    ];
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
              data: (disputes) => _Body(
                disputes: disputes,
                filter: _filter,
                onFilter: (f) => setState(() => _filter = f),
                filters: filters,
              ),
              loading: () => const _Loading(),
              error: (e, _) => BrandedErrorBanner(
                message: friendlyError(e),
                detail: errorDetail(e),
                onRetry: () => ref.invalidate(disputesProvider(uid)),
              ),
            );
          },
          loading: () => const _Loading(),
          error: (e, _) => BrandedErrorBanner(
            message: friendlyError(e),
            detail: errorDetail(e),
            onRetry: () => ref.invalidate(userIdProvider),
          ),
        ),
      ),
    );
  }
}

class _FilterChip {
  final String id;
  final String label;
  const _FilterChip({required this.id, required this.label});
}

class _Body extends StatelessWidget {
  final List<Dispute> disputes;
  final String filter;
  final ValueChanged<String> onFilter;
  final List<_FilterChip> filters;
  const _Body({
    required this.disputes,
    required this.filter,
    required this.onFilter,
    required this.filters,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tc = AppThemeColors.of(context);
    final past = disputes
        .where((d) =>
            d.status == DisputeStatus.resolved ||
            d.status == DisputeStatus.expired)
        .toList();
    final filtered = filterHistoryDisputes(disputes, filter);

    final wonAmount = past
        .where((d) => d.status == DisputeStatus.resolved)
        .fold<double>(0, (s, d) => s + (d.resolvedAmount ?? 0));
    final wonCount =
        past.where((d) => d.status == DisputeStatus.resolved).length;
    final lostCount = past
        .where((d) =>
            d.status == DisputeStatus.expired ||
            (d.status == DisputeStatus.resolved && d.resolvedAmount == 0))
        .length;
    final escalatedCount = disputes.where(isEscalatedDispute).length;
    final winRate = past.isEmpty
        ? 0
        : ((wonCount / past.length) * 100).round();

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _PageHeader(tc: tc, l10n: l10n)),
        SliverToBoxAdapter(
          child: _StatStrip(
            wonCount: wonCount,
            lostCount: lostCount,
            escalatedCount: escalatedCount,
            wonAmount: wonAmount,
            winRate: winRate,
            tc: tc,
            l10n: l10n,
          ),
        ),
        SliverToBoxAdapter(
          child: _FilterTabs(
            filters: filters,
            selected: filter,
            onTap: onFilter,
            tc: tc,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
        if (filtered.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyHistory(),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            sliver: SliverList.separated(
              itemCount: filtered.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _HistoryCard(dispute: filtered[i]),
            ),
          ),
      ],
    );
  }
}

class _PageHeader extends StatelessWidget {
  final AppThemeColors tc;
  final AppLocalizations? l10n;
  const _PageHeader({required this.tc, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: tc.textPrimary),
            onPressed: () => context.pop(),
          ),
          Expanded(
            child: Text(
              l10n?.historyTitle ?? 'History',
              style: TextStyle(
                fontFamily: AppTypography.family,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: tc.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: () => context.push(AppRoutes.disputesCreate),
            icon: Icon(Icons.add, size: 18, color: tc.ctaBackground),
            label: Text(
              l10n?.homeAddDispute ?? 'Add dispute',
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

class _StatStrip extends StatelessWidget {
  final int wonCount;
  final int lostCount;
  final int escalatedCount;
  final double wonAmount;
  final int winRate;
  final AppThemeColors tc;
  final AppLocalizations? l10n;
  const _StatStrip({
    required this.wonCount,
    required this.lostCount,
    required this.escalatedCount,
    required this.wonAmount,
    required this.winRate,
    required this.tc,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: tc.surface,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(color: tc.divider),
        ),
        child: Row(
          children: [
            _stat('TOTAL', wonAmount > 0
                ? CompensationCalculator.formatIndian(wonAmount)
                : '₹0', AppColors.accent),
            _verticalDivider(tc.divider),
            _stat('WON', '$wonCount', tc.textPrimary),
            _verticalDivider(tc.divider),
            _stat('LOST', '$lostCount', tc.textSecondary),
            _verticalDivider(tc.divider),
            _stat('RATE', '$winRate%', tc.textPrimary),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: AppTypography.family,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
              color: tc.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontFamily: AppTypography.family,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _verticalDivider(Color c) =>
      Container(width: 1, height: 28, color: c);
}

class _FilterTabs extends StatelessWidget {
  final List<_FilterChip> filters;
  final String selected;
  final ValueChanged<String> onTap;
  final AppThemeColors tc;
  const _FilterTabs({
    required this.filters,
    required this.selected,
    required this.onTap,
    required this.tc,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Container(
        height: 42,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: tc.surfaceAlt,
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: Row(
          children: [
            for (final f in filters)
              Expanded(
                child: _PillTab(
                  label: f.label,
                  selected: selected == f.id,
                  onTap: () => onTap(f.id),
                  tc: tc,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PillTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final AppThemeColors tc;
  const _PillTab({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.tc,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? tc.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        onTap: onTap,
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 180),
            style: TextStyle(
              fontFamily: AppTypography.family,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? tc.textPrimary : tc.textSecondary,
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final Dispute dispute;
  const _HistoryCard({required this.dispute});

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    final l10n = AppLocalizations.of(context);
    final won = dispute.isWon;
    final lost = dispute.isLost;
    final partial = dispute.isPartial;

    final amount = dispute.resolvedAmount ?? 0;
    final (amountColor, badge, statusLabel) = switch ((won, lost, partial)) {
      (true, _, true) => (
          AppColors.alert,
          AppColors.alert,
          l10n?.historyBadgePartial ?? 'PARTIAL'
        ),
      (true, _, _) => (
          AppColors.accent,
          AppColors.accent,
          l10n?.historyBadgeWon ?? 'WON'
        ),
      (_, true, _) => (
          AppColors.error,
          AppColors.error,
          l10n?.historyBadgeLost ?? 'LOST'
        ),
      _ => (
          tc.textPrimary,
          tc.textSecondary,
          l10n?.historyBadgeFiled ?? 'FILED'
        ),
    };

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.md),
      onTap: () => context.push(AppRoutes.disputeDetail(dispute.id)),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          color: tc.surface,
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(color: tc.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tc.surfaceAlt,
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                  ),
                  child: Text(dispute.type.emoji,
                      style: const TextStyle(fontSize: 14)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dispute.type.localizedName(
                            AppLocalizations.of(context)),
                        style: TextStyle(
                          fontFamily: AppTypography.family,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: tc.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${dispute.entityName ?? "—"} · ${_fmtDate(dispute.resolvedAt ?? dispute.txnDate)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: tc.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      CompensationCalculator.formatIndian(amount),
                      style: TextStyle(
                        fontFamily: AppTypography.family,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: amountColor,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: tc.surfaceAlt,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: badge,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            _summaryLine(context, tc),
          ],
        ),
      ),
    );
  }

  Widget _summaryLine(BuildContext context, AppThemeColors tc) {
    final l1 = dispute.filedDates['l1'];
    final resolved = dispute.resolvedAt;
    if (dispute.status == DisputeStatus.resolved && resolved != null && l1 != null) {
      final days = resolved.differenceInDays(l1);
      final perDay = dispute.type.compensationPerDay;
      final recovered = dispute.resolvedAmount ?? 0;
      String compSuffix = '';
      if (perDay != null && recovered > dispute.amount) {
        compSuffix = ' · ₹100 comp included';
      }
      return Text(
        'Filed ${_fmtDate(l1)} · resolved in $days days$compSuffix',
        style: TextStyle(fontSize: 11, color: tc.textSecondary),
      );
    }
    if (dispute.status == DisputeStatus.expired) {
      return Text(
        'Dispute window expired without resolution',
        style: TextStyle(fontSize: 11, color: tc.textSecondary),
      );
    }
    return Text(
      '${dispute.type.localizedCompensation(AppLocalizations.of(context)) ?? "Guidance mode"} · ${_fmtDate(dispute.txnDate)}',
      style: TextStyle(fontSize: 11, color: tc.textSecondary),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.day} ${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][d.month - 1]}';
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tc = AppThemeColors.of(context);
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
              child: Text('📜', style: const TextStyle(fontSize: 36)),
            ),
            const SizedBox(height: 20),
            Text(
              l10n?.historyEmptyTitle ?? 'No history yet',
              style: TextStyle(
                fontFamily: AppTypography.family,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: tc.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n?.historyEmptySubtitle ??
                  'Resolved and expired disputes will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: tc.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: tc.ctaBackground,
                foregroundColor: tc.ctaForeground,
              ),
              onPressed: () => context.push(AppRoutes.disputesCreate),
              child: Text(l10n?.homeAddDispute ?? 'Add dispute'),
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
  Widget build(BuildContext context) => const SkeletonList(
        itemCount: 5,
        itemHeight: 100,
      );
}
