import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:refund_radar/data/repositories/rules_engine_repository.dart';
import 'package:refund_radar/core/utils/url_launcher_helper.dart';
import 'package:refund_radar/services/compensation_calculator.dart';
import 'package:refund_radar/data/models/dispute.dart';

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
    return Scaffold(
      appBar: AppBar(title: const Text('Ombudsman letter')),
      body: rulesAsync.when(
        data: (rules) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B3D2E).withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF0B3D2E)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Premium feature',
                        style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0B3D2E))),
                    SizedBox(height: 4),
                    Text('Generate a pre-filled Template C complaint summary that you can paste into cms.rbi.org.in.'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (_letter.isEmpty)
                Center(
                  child: FilledButton.icon(
                    onPressed: () {
                      _generateLetter(Dispute(
                        id: widget.disputeId,
                        type: DisputeType.upiP2p,
                        amount: 500,
                        txnDate: DateTime.now().subtract(const Duration(days: 35)),
                        txnId: 'UTR_PREVIEW',
                        entityName: 'Your Bank',
                        createdAt: DateTime.now().subtract(const Duration(days: 34)),
                        filedDates: {'l1': DateTime.now().subtract(const Duration(days: 33))},
                        ticketNumbers: {'l1': 'TKT-12345'},
                      ));
                    },
                    icon: const Icon(Icons.auto_fix_high),
                    label: const Text('Generate letter'),
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
                        label: const Text('Copy'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => launchExternalUrl(rules.officialLinks['rbi_cms'] ?? 'https://cms.rbi.org.in'),
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('Open cms.rbi.org.in'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => Clipboard.setData(ClipboardData(text: _letter)),
                  icon: const Icon(Icons.share),
                  label: const Text('Share (copy to clipboard)'),
                ),
              ],
              const SizedBox(height: 24),
              const Text(
                'Refund Radar is an independent informational tool. '
                'It is not affiliated with RBI, NPCI, NHAI, IHMCL, or any bank.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
