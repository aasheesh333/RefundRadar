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
import 'package:refund_radar/shared/widgets/filter_pills.dart';
import 'package:refund_radar/shared/widgets/skeleton.dart';

/// True when dispute is open at L2/ombudsman, or past with L2/ombudsman/l3 filing.
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

/// History filter over disputes. Escalated uses the full list; others use past only.
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

/// History (Ledger) page matching mockup Screen 9.
/// Filter pills + win-rate stats header + card list of past/resolved disputes
/// + "Load older" footer.
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
    final uidAsync = ref.watch(userIdProvider);
    final filters = [
      (id: 'All', label: l10n?.historyFilterAll ?? 'All'),
      (id: 'Won', label: l10n?.historyFilterWon ?? 'Won'),
      (id: 'Lost', label: l10n?.historyFilterLost ?? 'Lost'),
      (id: 'Escalated', label: l10n?.historyFilterEscalated ?? 'Escalated'),
    ];
    final tc = AppThemeColors.of(context);
    return Scaffold(
      backgroundColor: tc.bg,
      body: SafeArea(
        child: uidAsync.when(
          data: (uid) {
            if (uid == null) {
              // Auth failed (not "loading"): show a retry banner, not a
              // permanent skeleton that masquerades as loading. Mirror
              // Home's auth-error banner so the cause is visible.
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

class _Body extends StatelessWidget {
  final List<Dispute> disputes;
  final String filter;
  final ValueChanged<String> onFilter;
  final List<({String id, String label})> filters;
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
    final totalResolved = past.where((d) => d.status == DisputeStatus.resolved).length;
    final totalDecided = past.length;
    final winRate =
        totalDecided == 0 ? 0 : ((totalResolved / totalDecided) * 100).round();

    return Column(
      children: [
        // header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n?.historyTitle ?? 'History',
                style: TextStyle(
                  fontFamily: AppTypography.family,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: tc.textPrimary,
                ),
              ),
            ],
          ),
        ),
        // filter pills
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: FilterPills(
            pills: filters
                .map((f) => (
                      label: f.label,
                      selected: filter == f.id,
                      onTap: () => onFilter(f.id),
                    ))
                .toList(),
          ),
        ),
        // stats row
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  _StatBox(
                    label: l10n?.historyTotalWon ?? 'TOTAL WON',
                    value: CompensationCalculator.formatIndian(wonAmount),
                    valueColor: AppColors.accent,
                  ),
                  const SizedBox(width: 24),
                  _StatBox(
                    label: l10n?.historyWinRate ?? 'WIN RATE',
                    value: '$winRate%',
                    valueColor: tc.textPrimary,
                  ),
                ],
              ),
              Text(
                l10n?.historyThisYear ?? 'This year',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: tc.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const _EmptyHistory()
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _HistoryCard(dispute: filtered[i]),
                ),
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  const _StatBox({required this.label, required this.value, required this.valueColor});

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: tc.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: valueColor,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
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
    // ME-4: use the shared outcome helpers instead of inlining the
    // (status, resolvedAmount) predicates; keeps the filter pills and the
    // card in lockstep.
    final won = dispute.isWon;
    final lost = dispute.isLost;
    final partial = dispute.isPartial;

    final amount = dispute.resolvedAmount ?? 0;
    final (cardBorderColor, emojiBg, amountColor, badge, statusLabel) = switch ((
      won,
      lost,
      partial
    )) {
      (true, _, true) => (
          tc.alertSoft,
          tc.alertSoft,
          AppColors.alert,
          AppColors.alert,
          l10n?.historyBadgePartial ?? 'PARTIAL'
        ),
      (true, _, _) => (
          tc.divider,
          tc.accentSoft,
          AppColors.accent,
          AppColors.accent,
          l10n?.historyBadgeWon ?? 'WON'
        ),
      (_, true, _) => (
          tc.errorSoft,
          tc.errorSoft,
          AppColors.error,
          AppColors.error,
          l10n?.historyBadgeLost ?? 'LOST'
        ),
      _ => (
          tc.divider,
          tc.premiumGoldSoft,
          tc.textPrimary,
          AppColors.premiumGold,
          l10n?.historyBadgeFiled ?? 'FILED'
        ),
    };

    return InkWell(
      onTap: () => context.push(AppRoutes.disputeDetail(dispute.id)),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: tc.surface,
          border: Border.all(color: cardBorderColor, width: 1),
          borderRadius: BorderRadius.circular(AppRadii.lg),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: emojiBg,
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                  ),
                  child: Center(
                    child: Text(dispute.type.emoji,
                        style: const TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dispute.type.localizedName(AppLocalizations.of(context)),
                        style: TextStyle(
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
                          fontWeight: FontWeight.w500,
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
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: amountColor,
                      ),
                    ),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: badge,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: tc.divider,
                    width: 1,
                    style: BorderStyle.solid,
                  ),
                ),
              ),
              child: _footerText(context, tc),
            ),
          ],
        ),
      ),
    );
  }

  Widget _footerText(BuildContext context, AppThemeColors tc) {
    final l1 = dispute.filedDates['l1'];
    final resolved = dispute.resolvedAt;
    if (dispute.status == DisputeStatus.resolved && resolved != null && l1 != null) {
      // ME-2: calendar-day math so a resolution that lands the morning
      // after an evening L1 filing isn't truncated to 0 days.
      final days = resolved.differenceInDays(l1);
      // LO-3: only show the comp suffix when the type actually carries
      // daily compensation (TAT types) AND the resolved amount exceeds the
      // debited principal — i.e. the user actually got comp. For
      // fastag / bank_charge / wrong_transfer (compensationPerDay == null)
      // and for plain refund-only outcomes, hide the label.
      final perDay = dispute.type.compensationPerDay;
      final recovered = dispute.resolvedAmount ?? 0;
      final compLabel = (perDay == null || recovered <= dispute.amount)
          ? ''
          : (recovered > dispute.amount
              ? ' · ₹100 comp included'
              : ' · ₹$perDay comp');
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Filed ${_fmtDate(l1)} · resolved in $days days',
            style: TextStyle(fontSize: 11, color: tc.textSecondary),
          ),
          if (compLabel.isNotEmpty)
            Text(
              compLabel,
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.accent),
            ),
        ],
      );
    }
    return Text(
      dispute.status == DisputeStatus.expired
          ? 'Dispute window expired without resolution'
          : '${dispute.type.localizedCompensation(AppLocalizations.of(context)) ?? "Guidance mode"} · ${_fmtDate(dispute.txnDate)}',
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
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('📜', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text(
              l10n?.historyEmptyTitle ?? 'No history yet',
              style: TextStyle(
                fontFamily: AppTypography.family,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: tc.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n?.historyEmptySubtitle ??
                  'Resolved and expired disputes will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: tc.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
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
