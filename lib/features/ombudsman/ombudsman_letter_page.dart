import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'package:refund_radar/shared/widgets/skeleton.dart';

class OmbudsmanLetterPage extends ConsumerStatefulWidget {
  final String disputeId;
  const OmbudsmanLetterPage({super.key, required this.disputeId});

  @override
  ConsumerState<OmbudsmanLetterPage> createState() => _OmbudsmanLetterPageState();
}

class _OmbudsmanLetterPageState extends ConsumerState<OmbudsmanLetterPage> {
  String _letter = '';

  void _generateLetter(Dispute dispute) {
    final comp = CompensationCalculator.compute(dispute);
    final letter = '''Complaint against: ${dispute.entityName ?? 'Bank'} (Bank / Payment System Participant)
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
    final rulesAsync = ref.watch(rulesEngineProvider);
    final uid = ref.watch(userIdProvider).asData?.value;
    final disputesAsync =
        uid == null ? null : ref.watch(disputesProvider(uid));
    return Scaffold(
      appBar: AppBar(
          title: Text(AppLocalizations.of(context)?.ombudsmanLetterTitle ??
              'Ombudsman letter')),
      body: rulesAsync.when(
        data: (rules) {
          if (uid == null || disputesAsync == null) {
            return const SkeletonList(itemCount: 3);
          }
          return disputesAsync.when(
            loading: () => const SkeletonList(itemCount: 3),
            error: (e, _) => BrandedErrorBanner(
              message: e.toString(),
              onRetry: () => ref.invalidate(disputesProvider(uid)),
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
                  onRetry: () => ref.invalidate(disputesProvider(uid)),
                );
              }
              final liveDispute = dispute;
              return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Premium feature',
                        style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary)),
                    SizedBox(height: 4),
                    Text('Generate a pre-filled Template C complaint summary that you can paste into cms.rbi.org.in.'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (_letter.isEmpty)
                Center(
                  child: FilledButton.icon(
                    onPressed: () => _generateLetter(liveDispute),
                    icon: const Icon(Icons.auto_fix_high),
                    label: Text(AppLocalizations.of(context)?.ombudsmanGenerate ??
                        'Generate letter'),
                  ),
                )
              else ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(_letter),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Clipboard.setData(ClipboardData(text: _letter)),
                        icon: const Icon(Icons.copy),
                        label: Text(
                            AppLocalizations.of(context)?.ombudsmanCopy ?? 'Copy'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => launchExternalUrl(rules.officialLinks['rbi_cms'] ?? 'https://cms.rbi.org.in'),
                        icon: const Icon(Icons.open_in_new),
                        label: Text(AppLocalizations.of(context)?.ombudsmanOpenCms ??
                            'Open cms.rbi.org.in'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => Clipboard.setData(ClipboardData(text: _letter)),
                  icon: const Icon(Icons.share),
                  label: Text(AppLocalizations.of(context)?.ombudsmanShareCopy ??
                      'Share (copy to clipboard)'),
                ),
              ],
              const SizedBox(height: 24),
              Text(
                'Refund Radar is an independent informational tool. '
                'It is not affiliated with RBI, NPCI, NHAI, IHMCL, or any bank.',
                style: TextStyle(
                  fontSize: 11,
                  color: AppThemeColors.of(context).textTertiary,
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
          message: e.toString(),
          onRetry: () => ref.invalidate(rulesEngineProvider),
        ),
      ),
    );
  }
}
