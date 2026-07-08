import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:refund_radar/data/models/dispute.dart';
import 'package:refund_radar/data/repositories/rules_engine_repository.dart';
import 'package:refund_radar/services/compensation_calculator.dart';
import 'package:refund_radar/services/sms_parser.dart';
import 'package:refund_radar/core/providers/auth_provider.dart';
import 'package:refund_radar/core/providers/dispute_provider.dart';

class DisputeFormPage extends ConsumerStatefulWidget {
  final String type;
  const DisputeFormPage({super.key, required this.type});
  @override
  ConsumerState<DisputeFormPage> createState() => _DisputeFormPageState();
}

class _DisputeFormPageState extends ConsumerState<DisputeFormPage> {
  final _form = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _utrCtrl = TextEditingController();
  final _entityCtrl = TextEditingController();
  DateTime? _date;
  String _selectedEntityId = '';

  @override
  void dispose() {
    _amountCtrl.dispose();
    _utrCtrl.dispose();
    _entityCtrl.dispose();
    super.dispose();
  }

  void _pasteFromSms() async {
    final data = await Clipboard.getData('text/plain');
    if (data?.text == null) return;
    final parsed = SmsParser.parse(data!.text!);
    setState(() {
      if (parsed.utr != null) _utrCtrl.text = parsed.utr!;
      if (parsed.amount != null) _amountCtrl.text = parsed.amount!.toStringAsFixed(0);
      if (parsed.date != null) _date = parsed.date;
    });
  }

  void _save() async {
    if (!_form.currentState!.validate()) return;
    final amount = double.tryParse(_amountCtrl.text) ?? 0;
    final uid = ref.read(userIdProvider).asData?.value;
    if (uid == null) return;
    final dispute = Dispute(
      id: '',
      uid: uid,
      type: DisputeType.fromId(widget.type),
      amount: amount,
      txnDate: _date ?? DateTime.now(),
      txnId: _utrCtrl.text,
      entityName: _entityCtrl.text,
      entityId: _selectedEntityId.isEmpty ? null : _selectedEntityId,
      createdAt: DateTime.now(),
    );
    final repo = ref.read(disputeRepositoryProvider);
    await repo.saveDispute(uid, dispute);
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final type = DisputeType.fromId(widget.type);
    final rulesAsync = ref.watch(rulesEngineProvider);
    return Scaffold(
      appBar: AppBar(title: Text('${type.id.toUpperCase()} dispute')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _amountCtrl,
              decoration: const InputDecoration(
                labelText: 'Amount (₹)',
                prefix: Text('₹ '),
                filled: true,
              ),
              keyboardType: TextInputType.number,
              validator: (v) => (v == null || double.tryParse(v) == null)
                  ? 'Enter valid amount'
                  : null,
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_date == null
                  ? 'Transaction date'
                  : 'Date: ${_date!.day}/${_date!.month}/${_date!.year}'),
              trailing: const Icon(Icons.calendar_month),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (mounted) setState(() => _date = picked);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _utrCtrl,
              decoration: InputDecoration(
                labelText: 'Transaction ID / UTR',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.content_paste),
                  onPressed: _pasteFromSms,
                ),
                filled: true,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _entityCtrl,
              decoration: const InputDecoration(
                labelText: 'Bank / Issuer',
                filled: true,
              ),
            ),
            const SizedBox(height: 16),
            if (type.tatDays != null && _date != null && _amountCtrl.text.isNotEmpty)
              _LivePreviewChip(
                dispute: Dispute(
                  id: 'preview',
                  type: type,
                  amount: double.tryParse(_amountCtrl.text) ?? 0,
                  txnDate: _date!,
                  txnId: '',
                  createdAt: DateTime.now(),
                ),
              ),
            if (type == DisputeType.wrongTransfer)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber),
                ),
                child: const Text(
                  'Note: Wrong UPI ID transfers are not covered by RBI compensation rules. '
                  'Recovery depends on beneficiary consent via bank/NPCI. We will guide you through the recovery steps.',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            if (type == DisputeType.fastag)
              rulesAsync.when(
                data: (rules) => DropdownButtonFormField<String>(
                  value: _selectedEntityId.isEmpty ? null : _selectedEntityId,
                  decoration: const InputDecoration(
                    labelText: 'FASTag issuer',
                    filled: true,
                  ),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('Select issuer')),
                    ...rules.fastagIssuers.map((issuer) => DropdownMenuItem(
                          value: issuer['id'] as String,
                          child: Text(issuer['name'] as String),
                        )),
                  ],
                  onChanged: (v) => setState(() => _selectedEntityId = v ?? ''),
                ),
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const SizedBox(),
              ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: const Color(0xFF0B3D2E),
                ),
                child: const Text('Create dispute'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LivePreviewChip extends StatelessWidget {
  final Dispute dispute;
  const _LivePreviewChip({required this.dispute});

  @override
  Widget build(BuildContext context) {
    final comp = CompensationCalculator.compute(dispute);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF5A623).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'Deadline was ${comp.deadlineDate.day}/${comp.deadlineDate.month} → Bank already owes you ${CompensationCalculator.formatIndian(comp.compensationDue)}',
        style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFF5A623)),
      ),
    );
  }
}
