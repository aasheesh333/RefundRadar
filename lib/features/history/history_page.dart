import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:refund_radar/core/providers/auth_provider.dart';
import 'package:refund_radar/core/providers/dispute_provider.dart';
import 'package:refund_radar/core/theme/app_theme_colors.dart';
import 'package:refund_radar/core/theme/app_tokens.dart';
import 'package:refund_radar/data/extensions/dispute_type_display.dart';
import 'package:refund_radar/data/models/dispute.dart';
import 'package:refund_radar/l10n/app_localizations.dart';
import 'package:refund_radar/services/compensation_calculator.dart';
import 'package:refund_radar/shared/widgets/branded_error_banner.dart';
import 'package:refund_radar/shared/widgets/filter_pills.dart';
import 'package:refund_radar/shared/widgets/skeleton.dart';

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
            if (uid == null) return const _Loading();
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
                message: e.toString(),
                onRetry: () => ref.invalidate(disputesProvider(uid)),
              ),
            );
          },
          loading: () => const _Loading(),
          error: (e, _) => BrandedErrorBanner(
            message: e.toString(),
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
    final filtered = past.where((d) {
      switch (filter) {
        case 'Won':
          return d.status == DisputeStatus.resolved &&
              (d.resolvedAmount ?? 0) > 0;
        case 'Lost':
          return d.status == DisputeStatus.expired ||
              (d.status == DisputeStatus.resolved &&
                  (d.resolvedAmount ?? 0) == 0);
        case 'Escalated':
          return d.status == DisputeStatus.ombudsman;
        default:
          return true;
      }
    }).toList();

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
    final won = dispute.status == DisputeStatus.resolved &&
        (dispute.resolvedAmount ?? 0) > 0;
    final lost = dispute.status == DisputeStatus.expired ||
        (dispute.status == DisputeStatus.resolved &&
            (dispute.resolvedAmount ?? 0) == 0);
    final partial = dispute.status == DisputeStatus.resolved &&
        won &&
        (dispute.resolvedAmount ?? 0) < dispute.amount;

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
          'PARTIAL'
        ),
      (true, _, _) => (
          tc.divider,
          tc.accentSoft,
          AppColors.accent,
          AppColors.accent,
          'WON'
        ),
      (_, true, _) => (
          tc.errorSoft,
          tc.errorSoft,
          AppColors.error,
          AppColors.error,
          'LOST'
        ),
      _ => (
          tc.divider,
          tc.premiumGoldSoft,
          tc.textPrimary,
          AppColors.premiumGold,
          'FILED'
        ),
    };

    return InkWell(
      onTap: () => context.push('/disputes/${dispute.id}'),
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
      final days = resolved.difference(l1).inDays;
      final comp = (dispute.resolvedAmount ?? 0) > dispute.amount
          ? ' · ₹100 comp included'
          : ' · ₹${dispute.type.compensationPerDay ?? 100} comp';
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Filed ${_fmtDate(l1)} · resolved in $days days',
            style: TextStyle(fontSize: 11, color: tc.textSecondary),
          ),
          Text(
            comp,
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
              onPressed: () => context.push('/disputes/create'),
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
