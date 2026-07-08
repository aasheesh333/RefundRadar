import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:refund_radar/data/repositories/rules_engine_repository.dart';
import 'package:refund_radar/shared/widgets/stepper_timeline.dart';
import 'package:refund_radar/core/utils/url_launcher_helper.dart';

class WizardPage extends ConsumerStatefulWidget {
  final String disputeId;
  const WizardPage({super.key, required this.disputeId});
  @override
  ConsumerState<WizardPage> createState() => _WizardPageState();
}

class _WizardPageState extends ConsumerState<WizardPage> {
  final _ticketController = TextEditingController();
  int _currentLevel = 0;

  @override
  void dispose() {
    _ticketController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rulesAsync = ref.watch(rulesEngineProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Escalation steps')),
      body: rulesAsync.when(
        data: (rules) {
          final steps = _buildSteps(rules);
          return StepperTimeline(
            items: List.generate(steps.length, (i) {
              final active = i == _currentLevel;
              return StepperItem(
                title: steps[i].title,
                isDone: i < _currentLevel,
                isCurrent: active,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(steps[i].title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(steps[i].body),
                    if (steps[i].complaintText != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SelectableText(steps[i].complaintText!),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => Clipboard.setData(
                            ClipboardData(text: steps[i].complaintText!)),
                        icon: const Icon(Icons.copy),
                        label: const Text('Copy complaint text'),
                      ),
                    ],
                    if (steps[i].url != null) ...[
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: () => launchExternalUrl(steps[i].url!),
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('Open portal'),
                      ),
                    ],
                    if (steps[i].phone != null) ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => launchPhone(steps[i].phone!),
                        icon: const Icon(Icons.phone),
                        label: Text('Call ${steps[i].phone}'),
                      ),
                    ],
                    if (steps[i].documents.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text('Documents needed:', style: Theme.of(context).textTheme.titleSmall),
                      ...steps[i].documents.map((d) => Row(
                            children: [
                              const Icon(Icons.check_circle_outline, size: 16),
                              const SizedBox(width: 8),
                              Expanded(child: Text(d)),
                            ],
                          )),
                    ],
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _ticketController,
                      decoration: const InputDecoration(
                        labelText: 'Ticket / complaint number',
                        filled: true,
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => setState(() {
                              if (_currentLevel < steps.length - 1) _currentLevel++;
                            }),
                            child: const Text('Mark as filed'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => context.go('/reminders'),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF0B3D2E),
                            ),
                            child: const Text('Done - set reminder'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  List<_Step> _buildSteps(rules) {
    return [
      _Step(
        title: 'Level 1 - UPI app / bank',
        body: 'File complaint in your UPI app (GPay/PhonePe/Paytm) or your bank. '
            'Note the ticket number. Bank has up to 30 days to respond.',
        url: rules.officialLinks['upi_complaints'],
        phone: '14448',
        complaintText: null,
        documents: ['UTR / Transaction ID', 'Amount', 'Date', 'VPA', 'Bank statement screenshot'],
      ),
      _Step(
        title: 'Level 2 - NPCI portal',
        body: 'Visit NPCI Dispute Redressal portal. Needs UTR, amount, date, VPA, bank statement.',
        url: rules.officialLinks['upi_complaints'],
        phone: null,
        complaintText: 'Dear NPCI Team,\n\nUTR: {UTR}\nAmount: Rs. {AMOUNT}\nDate: {TXN_DATE}\nVPA: {VPA}\n\n'
            'I have not received credit / refund and the bank has not resolved within 30 days.\n'
            'Please escalate this dispute.',
        documents: ['UTR', 'Amount', 'Date', 'VPA', 'Bank statement'],
      ),
      _Step(
        title: 'Level 3 - RBI Ombudsman',
        body: 'File at cms.rbi.org.in within 90 days of bank response window. '
            'Category: Deficiency in Service. Free.',
        url: rules.officialLinks['rbi_cms'],
        phone: '14448',
        complaintText: 'Complaint against: {ENTITY_NAME} (Bank)\n'
            'Category: Deficiency in Service - failed transaction not reversed\n\n'
            'Facts:\n1. On {TXN_DATE}, Rs. {AMOUNT} debited, beneficiary not credited.\n'
            '2. Complained on {COMPLAINT_DATE} (ticket {TICKET_NO}).\n'
            '3. No reply for 30 days.\n'
            '4. Under RBI TAT Harmonisation circular, entitled to reversal + Rs.100/day.\n\n'
            'Relief: Refund Rs. {AMOUNT} + compensation Rs. {COMPENSATION_DUE}.',
        documents: ['Transaction proof', 'Complaint acknowledgement', 'Bank reply (if any)'],
      ),
    ];
  }
}

class _Step {
  final String title;
  final String body;
  final String? url;
  final String? phone;
  final String? complaintText;
  final List<String> documents;
  _Step({
    required this.title,
    required this.body,
    this.url,
    this.phone,
    this.complaintText,
    this.documents = const [],
  });
}
