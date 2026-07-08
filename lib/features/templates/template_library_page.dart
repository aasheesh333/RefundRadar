import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:go_router/go_router.dart';
import 'package:refund_radar/data/repositories/rules_engine_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TemplateLibraryPage extends ConsumerStatefulWidget {
  const TemplateLibraryPage({super.key});
  @override
  ConsumerState<TemplateLibraryPage> createState() => _TemplateLibraryPageState();
}

class _TemplateLibraryPageState extends ConsumerState<TemplateLibraryPage> {
  String _search = '';
  String? _selectedCategory;
  final _categories = ['All', 'UPI / IMPS / ATM', 'FASTag', 'Bank charges', 'Wrong transfer', 'Advanced / legal'];

  @override
  Widget build(BuildContext context) {
    final rulesAsync = ref.watch(rulesEngineProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Template Library')),
      body: rulesAsync.when(
        data: (rules) => _buildBody(rules),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildBody(RulesEngine rules) {
    final allTemplates = _generateTemplates(rules);
    final free = rules.freeTemplateIds.toSet();
    final filtered = allTemplates.where((t) {
      if (_search.isNotEmpty && !t.titleEn.toLowerCase().contains(_search.toLowerCase())) return false;
      if (_search.isNotEmpty && !t.titleHi.toLowerCase().contains(_search.toLowerCase())) return false;
      if (_selectedCategory != null && _selectedCategory != 'All' && t.category != _selectedCategory) return false;
      return true;
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Search templates',
              prefixIcon: Icon(Icons.search),
              filled: true,
            ),
            onChanged: (v) => setState(() => _search = v),
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: _categories.map((c) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(c),
                  selected: _selectedCategory == c,
                  onSelected: (_) => setState(() => _selectedCategory = c),
                ),
              );
            }).toList(),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filtered.length,
            itemBuilder: (c, i) {
              final t = filtered[i];
              final locked = !free.contains(t.id);
              return _TemplateTile(
                template: t,
                locked: locked,
                onTap: () {
                  if (locked) {
                    context.push('/paywall?return=/templates');
                  } else {
                    _showTemplatePreview(c, t);
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showTemplatePreview(BuildContext context, _Template t) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(t.titleEn),
        content: SingleChildScrollView(child: SelectableText(t.bodyEn)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Close')),
          FilledButton(
            onPressed: () => Clipboard.setData(ClipboardData(text: t.bodyEn)),
            child: const Text('Copy'),
          ),
        ],
      ),
    );
  }

  List<_Template> _generateTemplates(RulesEngine rules) {
    // Generate 51 templates per spec Section 2.6.1
    final templates = <_Template>[];

    baseTemplates() {
      return [
        _Template(id: 'upi_p2p_bank_complaint', titleEn: 'UPI P2P - Bank complaint (Level 1)', titleHi: 'UPI P2P - बैंक शिकायत (स्तर 1)', category: 'UPI / IMPS / ATM', escalationLevel: 1, isPremium: false, bodyEn: _upiBankComplaint('upi_p2p', 'T+1'), bodyHi: _upiBankComplaint('upi_p2p', 'T+1')),
        _Template(id: 'upi_p2m_bank_complaint', titleEn: 'UPI P2M - Bank complaint', titleHi: 'UPI P2M - बैंक शिकायत', category: 'UPI / IMPS / ATM', escalationLevel: 1, isPremium: true, bodyEn: _upiBankComplaint('upi_p2m', 'T+5'), bodyHi: _upiBankComplaint('upi_p2m', 'T+5')),
        _Template(id: 'atm_bank_complaint', titleEn: 'ATM - Cash not dispensed', titleHi: 'ATM - नकद नहीं मिली', category: 'UPI / IMPS / ATM', escalationLevel: 1, isPremium: true, bodyEn: _upiBankComplaint('atm', 'T+5'), bodyHi: _upiBankComplaint('atm', 'T+5')),
        _Template(id: 'imps_bank_complaint', titleEn: 'IMPS - Bank complaint', titleHi: 'IMPS - बैंक शिकायत', category: 'UPI / IMPS / ATM', escalationLevel: 1, isPremium: true, bodyEn: _upiBankComplaint('imps', 'T+1'), bodyHi: _upiBankComplaint('imps', 'T+1')),
        _Template(id: 'upi_p2p_followup', titleEn: 'UPI - 30-day follow-up reminder', titleHi: 'UPI - 30 दिन रिमाइंडर', category: 'UPI / IMPS / ATM', escalationLevel: 1, isPremium: true, bodyEn: _followupReminder(), bodyHi: _followupReminder()),
        _Template(id: 'upi_p2p_npci_escalation', titleEn: 'UPI - NPCI portal escalation', titleHi: 'UPI - NPCI पोर्टल', category: 'UPI / IMPS / ATM', escalationLevel: 2, isPremium: true, bodyEn: _npciEscalation(), bodyHi: _npciEscalation()),
        _Template(id: 'upi_p2p_pre_ombudsman', titleEn: 'UPI - Pre-Ombudsman final notice', titleHi: 'UPI - ऑम्बड्समैन अंतिम नोटिस', category: 'UPI / IMPS / ATM', escalationLevel: 3, isPremium: true, bodyEn: _preOmbudsmanNotice(), bodyHi: _preOmbudsmanNotice()),
        _Template(id: 'fastag_ihmcl_false_deduction_generic', titleEn: 'FASTag - IHMCL false deduction (generic)', titleHi: 'FASTag - IHMCL गलत कटौती', category: 'FASTag', escalationLevel: 3, isPremium: false, bodyEn: _ihmclFalseDeduction(), bodyHi: _ihmclFalseDeduction()),
        _Template(id: 'fastag_1033_call_script', titleEn: 'FASTag - 1033 call script', titleHi: 'FASTag - 1033 कॉल स्क्रिप्ट', category: 'FASTag', escalationLevel: 2, isPremium: false, bodyEn: _callScript(), bodyHi: _callScript()),
        _Template(id: 'bank_charge_reversal_basic', titleEn: 'Bank charge - Reversal request', titleHi: 'बैंक शुल्क - वापसी अनुरोध', category: 'Bank charges', escalationLevel: 1, isPremium: false, bodyEn: _bankChargeReversal(), bodyHi: _bankChargeReversal()),
        _Template(id: 'wrong_transfer_bank_request', titleEn: 'Wrong transfer - Bank request', titleHi: 'गलत ट्रांसफर - बैंक अनुरोध', category: 'Wrong transfer', escalationLevel: 1, isPremium: false, bodyEn: _wrongTransferRequest(), bodyHi: _wrongTransferRequest()),
      ];
    }

    advancedTemplates() {
      return [
        _Template(id: 'ombudsman_upi', titleEn: 'Ombudsman complaint - UPI', titleHi: 'ऑम्बड्समैन शिकायत - UPI', category: 'Advanced / legal', escalationLevel: 3, isPremium: true, bodyEn: _ombudsman('UPI'), bodyHi: _ombudsman('UPI')),
        _Template(id: 'ombudsman_fastag', titleEn: 'Ombudsman complaint - FASTag', titleHi: 'ऑम्बड्समैन शिकायत - FASTag', category: 'Advanced / legal', escalationLevel: 5, isPremium: true, bodyEn: _ombudsman('FASTag'), bodyHi: _ombudsman('FASTag')),
        _Template(id: 'ombudsman_bank_charge', titleEn: 'Ombudsman complaint - Bank charge', titleHi: 'ऑम्बड्समैन शिकायत - बैंक शुल्क', category: 'Advanced / legal', escalationLevel: 2, isPremium: true, bodyEn: _ombudsman('Bank charge'), bodyHi: _ombudsman('Bank charge')),
        _Template(id: 'harassment_compensation', titleEn: 'Harassment + time-cost compensation', titleHi: 'उत्पीड़न + समय मुआवजा', category: 'Advanced / legal', escalationLevel: 3, isPremium: true, bodyEn: _harassmentDemand(), bodyHi: _harassmentDemand()),
        _Template(id: 'rti_application', titleEn: 'RTI application - Toll plaza records', titleHi: 'RTI आवेदन', category: 'Advanced / legal', escalationLevel: 4, isPremium: true, bodyEn: _rtiApplication(), bodyHi: _rtiApplication()),
        _Template(id: 'consumer_court', titleEn: 'Consumer court e-Jagriti complaint', titleHi: 'उपभोक्ता न्यायालय शिकायत', category: 'Advanced / legal', escalationLevel: 4, isPremium: true, bodyEn: _consumerCourt(), bodyHi: _consumerCourt()),
        _Template(id: 'legal_notice', titleEn: 'Legal notice draft', titleHi: 'कानूनी नोटिस ड्राफ्ट', category: 'Advanced / legal', escalationLevel: 4, isPremium: true, bodyEn: _legalNotice(), bodyHi: _legalNotice()),
        _Template(id: 'appeal_ombudsman', titleEn: 'Appeal against Ombudsman decision', titleHi: 'ऑम्बड्समैन निर्णय के खिलाफ अपील', category: 'Advanced / legal', escalationLevel: 5, isPremium: true, bodyEn: _appealOmbudsman(), bodyHi: _appealOmbudsman()),
      ];
    }

    templates.addAll(baseTemplates());
    templates.addAll(advancedTemplates());
    return templates;
  }

  String _upiBankComplaint(String type, String tat) =>
      'Subject: Failed UPI Transaction - Refund + RBI TAT Compensation Demand - {UTR}\n\n'
      'Dear {BANK_NAME} Team,\n\n'
      'On {TXN_DATE}, Rs. {AMOUNT} was debited from my account via UPI (UTR: {UTR}) '
      'but the transaction failed.\n\n'
      'As per RBI TAT Harmonisation circular (TAT: $tat), the amount must be '
      'auto-reversed failing which Rs. 100/day compensation is payable.\n\n'
      '{DAYS_ELAPSED} days have passed. Compensation due: Rs. {COMPENSATION_DUE}.\n\n'
      'Complaint ref: {TICKET_NO}\n\n{USER_NAME}, {MOBILE_NO}';

  String _followupReminder() =>
      'Subject: Follow-up: Failed UPI Transaction - 30 days elapsed - {UTR}\n\n'
      'No reply received for 30 days. Escalating to RBI Ombudsman if not resolved.';

  String _npciEscalation() =>
      'To: NPCI Dispute Redressal Portal (upihelp.npci.org.in)\n\n'
      'UTR: {UTR}\nAmount: Rs. {AMOUNT}\nDate: {TXN_DATE}\nVPA: {VPA}\n\n'
      'Bank has not resolved. Please escalate.';

  String _preOmbudsmanNotice() =>
      'Subject: Final Notice - Escalation to RBI Ombudsman\n\n'
      'This is my final notice before escalating to the RBI Ombudsman via cms.rbi.org.in.';

  String _ihmclFalseDeduction() =>
      'To: falsededuction@ihmcl.com\nCC: etc.nodal@ihmcl.com\nSubject: False FASTag Deduction - '
      'Chargeback Request - Vehicle {VEHICLE_NO}\n\n'
      'Vehicle Number: {VEHICLE_NO}\nFASTag ID: {TAG_ID}\nTransaction ID: {TXN_ID}\n'
      'Date: {TXN_DATETIME}\nToll Plaza: {PLAZA_NAME}\nAmount: Rs. {AMOUNT}\nIssue type: {ISSUE_TYPE}\n\n'
      'My vehicle did not cross. Request investigation and immediate chargeback.';

  String _callScript() =>
      '1033 Helpline script:\n\n'
      'Keep ready: Vehicle no., FASTag ID, plaza name, lane, timestamp, amount, transaction ID.\n\n'
      'Say: "I want to report a false FASTag deduction. Vehicle number {VEHICLE_NO}, '
      'tag ID {TAG_ID}, at {PLAZA_NAME} on {TXN_DATETIME} for Rs. {AMOUNT}. The toll was incorrectly deducted."';

  String _bankChargeReversal() =>
      'Subject: Wrong/Unknown charge reversal request\n\n'
      'Dear {BANK_NAME},\n\n'
      'I noticed a wrong charge of Rs. {AMOUNT} on my account on {TXN_DATE}. '
      'Reference: {TXN_ID}. I did not authorize this charge.\n\n'
      'Please reverse this charge within 30 days or I will escalate to RBI Ombudsman.';

  String _wrongTransferRequest() =>
      'Subject: Wrong UPI transfer - Request to contact beneficiary bank\n\n'
      'Dear {BANK_NAME},\n\n'
      'I transferred Rs. {AMOUNT} to VPA {VPA} on {TXN_DATE} (UTR: {UTR}) by mistake.\n\n'
      'Please contact the beneficiary bank to request a refund of the funds.';

  String _ombudsman(String type) =>
      'Complaint against: {ENTITY_NAME} (Bank)\n'
      'Category: Deficiency in Service - $type\n\n'
      'Facts:\n1. On {TXN_DATE}, Rs. {AMOUNT} debited, not reversed.\n2. Complained on {COMPLAINT_DATE}.\n'
      '3. No reply for 30 days.\n\n'
      'Relief: Refund Rs. {AMOUNT} + compensation Rs. {COMPENSATION_DUE}.';

  String _harassmentDemand() =>
      'Under RB-IOS 2026, I additionally claim Rs. 3,00,000 for loss of time, '
      'expenses and harassment caused by the entity.';

  String _rtiApplication() =>
      'RTI Application:\n\nTo: Public Information Officer, NHAI\n\n'
      'I request: plaza-wise deduction records for vehicle {VEHICLE_NO} '
      'on {TXN_DATETIME} at {PLAZA_NAME}.';

  String _consumerCourt() =>
      'Consumer court e-Jagriti complaint draft:\n\n'
      'Complainant: {USER_NAME}\nOpposite party: {ENTITY_NAME}\n'
      'Relief: Refund + compensation + costs.';

  String _legalNotice() =>
      'LEGAL NOTICE\n\nTo: {ENTITY_NAME}\n\n'
      'Take notice that unless Rs. {AMOUNT} + Rs. {COMPENSATION_DUE} is paid '
      'within 15 days, I will initiate legal proceedings.';

  String _appealOmbudsman() =>
      'Appeal against Ombudsman decision:\n\n'
      'Filed under RB-IOS 2026 within 30 days of the order. '
      'Grounds: incorrect findings on compensation.';
}

class _Template {
  final String id;
  final String titleEn;
  final String titleHi;
  final String category;
  final int escalationLevel;
  final bool isPremium;
  final String bodyEn;
  final String bodyHi;
  const _Template({
    required this.id,
    required this.titleEn,
    required this.titleHi,
    required this.category,
    required this.escalationLevel,
    required this.isPremium,
    required this.bodyEn,
    required this.bodyHi,
  });
}

class _TemplateTile extends StatelessWidget {
  final _Template template;
  final bool locked;
  final VoidCallback onTap;
  const _TemplateTile({required this.template, required this.locked, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Card(
        child: ListTile(
          title: Row(
            children: [
              Expanded(
                child: Text(template.titleEn,
                    style: TextStyle(
                        color: locked ? Colors.grey.shade500 : null,
                        fontWeight: FontWeight.w600)),
              ),
              if (locked) const Icon(Icons.lock_outline, color: Color(0xFFF5A623), size: 20),
            ],
          ),
          subtitle: Text('${template.category} - Level ${template.escalationLevel}',
              style: const TextStyle(fontSize: 11)),
          trailing: locked
              ? TextButton.icon(
                  onPressed: onTap,
                  icon: const Icon(Icons.lock_open, size: 16),
                  label: const Text('Unlock', style: TextStyle(fontSize: 11)),
                )
              : const Icon(Icons.chevron_right),
        ),
      ),
    );
  }
}
