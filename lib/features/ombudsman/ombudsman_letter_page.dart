import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:refund_radar/core/router/app_routes.dart';
import 'package:refund_radar/core/providers/premium_provider.dart';
import 'package:refund_radar/core/providers/auth_provider.dart';
import 'package:refund_radar/core/providers/dispute_provider.dart';
import 'package:refund_radar/data/repositories/rules_engine_repository.dart';
import 'package:refund_radar/core/utils/url_launcher_helper.dart';
import 'package:refund_radar/core/theme/app_theme_colors.dart';
import 'package:refund_radar/core/theme/app_tokens.dart';
import 'package:refund_radar/l10n/app_localizations.dart';
import 'package:refund_radar/services/compensation_calculator.dart';
import 'package:refund_radar/data/models/dispute.dart';
import 'package:refund_radar/shared/widgets/branded_error_banner.dart';
import 'package:refund_radar/shared/utils/error_mapper.dart';
import 'package:refund_radar/shared/widgets/skeleton.dart';

String ombudsmanLetterPaywallLocation(String disputeId) =>
    AppRoutes.paywallWithParams(
      trigger: 'ombudsman_letter',
      returnPath: AppRoutes.disputeDetail(disputeId),
    );

bool shouldGateOmbudsmanLetter(bool isPremium) => !isPremium;

class OmbudsmanLetterPage extends ConsumerStatefulWidget {
  final String disputeId;
  const OmbudsmanLetterPage({super.key, required this.disputeId});

  @override
  ConsumerState<OmbudsmanLetterPage> createState() =>
      _OmbudsmanLetterPageState();
}

class _OmbudsmanLetterPageState extends ConsumerState<OmbudsmanLetterPage> {
  String _letter = '';
  bool _paywallRedirectScheduled = false;

  void _redirectFreeUserToPaywall() {
    if (_paywallRedirectScheduled) return;
    _paywallRedirectScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.go(ombudsmanLetterPaywallLocation(widget.disputeId));
    });
  }

  void _generateLetter(Dispute dispute) {
    final comp = CompensationCalculator.compute(dispute);
    final letter =
        '''Complaint against: ${dispute.entityName ?? 'Bank'} (Bank / Payment System Participant)
Category: Deficiency in Service - ${_subcategory(dispute.type)}

Facts:
1. On ${_fmtDate(dispute.txnDate)}, Rs. ${dispute.amount.toStringAsFixed(0)} was debited via ${dispute.type.id.toUpperCase()} (UTR: ${dispute.txnId}) but the transaction failed / was not reversed.
2. I complained to the entity (${dispute.ticketNumbers['l1'] ?? 'ticket number pending'}) on ${_fmtDate(dispute.filedDates['l1'] ?? dispute.createdAt)}.
3. No reply for 30 days / Rejected / Unsatisfactory reply.
4. Under RBI's TAT Harmonisation circular, I am entitled to reversal + Rs.100/day compensation. Total due: Rs. ${comp.compensationDue.toStringAsFixed(0)}.

Relief sought: Refund of Rs. ${dispute.amount.toStringAsFixed(0)} + compensation Rs. ${comp.compensationDue.toStringAsFixed(0)} + Rs. 5,000 for time and effort as per RB-IOS 2026.

Documents: transaction proof, complaint acknowledgement, bank reply (if any).
''';
    setState(() => _letter = letter);
  }

  String _subcategory(DisputeType type) {
    switch (type) {
      case DisputeType.fastag:
        return 'FASTag wrong deduction';
      case DisputeType.bankCharge:
        return 'wrong charges';
      default:
        return 'failed transaction not reversed';
    }
  }

  String _fmtDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final premiumStatus = ref.watch(premiumStatusProvider);
    final isPremium = premiumStatus.valueOrNull ?? false;
    if (premiumStatus.isLoading) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (shouldGateOmbudsmanLetter(isPremium)) {
      _redirectFreeUserToPaywall();
      return const Scaffold(body: SizedBox.shrink());
    }

    final rulesAsync = ref.watch(rulesEngineProvider);
    final uidAsync = ref.watch(userIdProvider);
    final tc = AppThemeColors.of(context);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: tc.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: tc.textPrimary),
                    onPressed: () => context.pop(),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n?.ombudsmanLetterTitle ?? 'Ombudsman letter',
                          style: TextStyle(
                            fontFamily: AppTypography.family,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                            color: tc.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          AppLocalizations.of(context)
                                  ?.ombudsmanPremiumFeature ??
                              'Premium feature',
                          style: TextStyle(
                            fontFamily: AppTypography.family,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.premiumGold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: uidAsync.when(
                loading: () => const SkeletonList(itemCount: 3),
                error: (e, _) => BrandedErrorBanner(
                  message: friendlyError(e),
                  detail: errorDetail(e),
                  onRetry: () => ref.invalidate(userIdProvider),
                ),
                data: (uid) {
                  if (uid == null || uid.isEmpty) {
                    return BrandedErrorBanner(
                      message: 'Could not sign in. Tap retry.',
                      onRetry: () => ref.invalidate(userIdProvider),
                    );
                  }
                  final disputesAsync = ref.watch(disputesProvider(uid));
                  return rulesAsync.when(
                    data: (rules) {
                      return disputesAsync.when(
                        loading: () => const SkeletonList(itemCount: 3),
                        error: (e, _) => BrandedErrorBanner(
                          message: friendlyError(e),
                          detail: errorDetail(e),
                          onRetry: () =>
                              ref.invalidate(disputesProvider(uid)),
                        ),
                        data: (disputes) {
                          Dispute? dispute;
                          for (final d in disputes) {
                            if (d.id == widget.disputeId) {
                              dispute = d;
                              break;
                            }
                          }
                          if (dispute == null) {
                            return BrandedErrorBanner(
                              message: 'Dispute not found.',
                              onRetry: () =>
                                  ref.invalidate(disputesProvider(uid)),
                            );
                          }
                          final liveDispute = dispute;
                          return ListView(
                            padding:
                                const EdgeInsets.fromLTRB(16, 8, 16, 32),
                            children: [
                              _PremiumHero(tc: tc, l10n: l10n),
                              const SizedBox(height: 16),
                              if (_letter.isEmpty)
                                Center(
                                  child: FilledButton.icon(
                                    onPressed: () =>
                                        _generateLetter(liveDispute),
                                    icon: const Icon(Icons.auto_fix_high,
                                        size: 18),
                                    label: Text(
                                      AppLocalizations.of(context)
                                              ?.ombudsmanGenerate ??
                                          'Generate letter',
                                      style: TextStyle(
                                        fontFamily: AppTypography.family,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: tc.ctaBackground,
                                      foregroundColor: tc.ctaForeground,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                            AppRadii.md),
                                      ),
                                    ),
                                  ),
                                )
                              else ...[
                                _LetterCard(
                                  letter: _letter,
                                  tc: tc,
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: SizedBox(
                                        height: 46,
                                        child: OutlinedButton.icon(
                                          onPressed: () {
                                            Clipboard.setData(
                                              ClipboardData(text: _letter),
                                            );
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  l10n
                                                          ?.escalateCopiedToClipboard ??
                                                      'Copied',
                                                ),
                                              ),
                                            );
                                          },
                                          icon: const Icon(Icons.copy,
                                              size: 16),
                                          label: Text(
                                            AppLocalizations.of(context)
                                                    ?.ombudsmanCopy ??
                                                'Copy',
                                            style: TextStyle(
                                              fontFamily:
                                                  AppTypography.family,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            side: BorderSide(
                                                color: tc.divider),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      AppRadii.md),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: SizedBox(
                                        height: 46,
                                        child: FilledButton.icon(
                                          onPressed: () => launchExternalUrl(
                                            rules.officialLinks['rbi_cms'] ??
                                                'https://cms.rbi.org.in',
                                          ),
                                          icon: const Icon(Icons.open_in_new,
                                              size: 16),
                                          label: Text(
                                            AppLocalizations.of(context)
                                                    ?.ombudsmanOpenCms ??
                                                'Open cms.rbi.org.in',
                                            style: TextStyle(
                                              fontFamily:
                                                  AppTypography.family,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          style: FilledButton.styleFrom(
                                            backgroundColor:
                                                tc.ctaBackground,
                                            foregroundColor:
                                                tc.ctaForeground,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      AppRadii.md),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  height: 46,
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      Clipboard.setData(
                                        ClipboardData(text: _letter),
                                      );
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            l10n?.escalateCopiedToClipboard ??
                                                'Copied',
                                          ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.share, size: 16),
                                    label: Text(
                                      AppLocalizations.of(context)
                                              ?.ombudsmanShareCopy ??
                                          'Share (copy to clipboard)',
                                      style: TextStyle(
                                        fontFamily: AppTypography.family,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(color: tc.divider),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                            AppRadii.md),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 24),
                              Text(
                                'Refund Radar is an independent informational tool. '
                                'It is not affiliated with RBI, NPCI, NHAI, IHMCL, or any bank.',
                                style: TextStyle(
                                  fontFamily: AppTypography.family,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color:
                                      AppThemeColors.of(context).textTertiary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          );
                        },
                      );
                    },
                    loading: () => const SkeletonList(itemCount: 3),
                    error: (e, _) => BrandedErrorBanner(
                      message: friendlyError(e),
                      detail: errorDetail(e),
                      onRetry: () => ref.invalidate(rulesEngineProvider),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PremiumHero extends StatelessWidget {
  final AppThemeColors tc;
  final AppLocalizations? l10n;
  const _PremiumHero({required this.tc, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tc.premiumGoldSoft,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border:
            Border.all(color: AppColors.premiumGold.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.premiumGold.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: const Text('📝', style: TextStyle(fontSize: 16)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n?.ombudsmanPremiumFeature ?? 'Premium feature',
                  style: TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: tc.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  l10n?.ombudsmanPremiumBlurb ??
                      'Generate a pre-filled Template C complaint summary that you can paste into cms.rbi.org.in.',
                  style: TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                    color: tc.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LetterCard extends StatelessWidget {
  final String letter;
  final AppThemeColors tc;
  const _LetterCard({required this.letter, required this.tc});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tc.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: tc.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LETTER',
            style: TextStyle(
              fontFamily: AppTypography.family,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: tc.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          SelectableText(
            letter,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              height: 1.6,
              color: tc.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
