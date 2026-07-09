import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:refund_radar/core/providers/app_state_provider.dart';
import 'package:refund_radar/core/providers/auth_provider.dart';
import 'package:refund_radar/core/providers/dispute_provider.dart';
import 'package:refund_radar/core/theme/app_tokens.dart';
import 'package:refund_radar/data/models/dispute.dart';
import 'package:refund_radar/data/repositories/reminder_repository.dart';
import 'package:refund_radar/data/repositories/rules_engine_repository.dart';
import 'package:refund_radar/services/analytics_service.dart';
import 'package:refund_radar/services/compensation_calculator.dart';
import 'package:refund_radar/services/sms_parser.dart';
import 'package:refund_radar/shared/widgets/app_back_button.dart';
import 'package:refund_radar/shared/widgets/form_field_box.dart';
import 'package:refund_radar/shared/widgets/bank_picker_tile.dart';

class DisputeFormPage extends ConsumerStatefulWidget {
  final String type;
  const DisputeFormPage({super.key, required this.type});
  @override
  ConsumerState<DisputeFormPage> createState() => _DisputeFormPageState();
}

class _DisputeFormPageState extends ConsumerState<DisputeFormPage> {
  final _amountCtrl = TextEditingController();
  final _utrCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  DateTime? _date;
  String _bankName = '';
  String _selectedEntityId = '';
  bool _utrFound = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _utrCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _pasteFromSms() async {
    final data = await Clipboard.getData('text/plain');
    if (data?.text == null) return;
    final parsed = SmsParser.parse(data!.text!);
    setState(() {
      if (parsed.utr != null) {
        _utrCtrl.text = parsed.utr!;
        _utrFound = true;
      }
      if (parsed.amount != null) {
        _amountCtrl.text = parsed.amount!.toStringAsFixed(0);
      }
      if (parsed.date != null) _date = parsed.date;
    });
  }

  void _save() async {
    final amount = double.tryParse(_amountCtrl.text) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the debited amount')),
      );
      return;
    }
    final uid = ref.read(userIdProvider).asData?.value;
    if (uid == null) return;

    // B3 free-tier gate: free users limited to 1 active dispute (spec §4.3).
    // Active = status in {draft, filed_l1, filed_l2, ombudsman}.
    final isPremium = ref.read(isPremiumProvider);
    if (!isPremium) {
      final disputesAsync = await ref.read(disputesProvider(uid).future);
      const terminal = {
        DisputeStatus.resolved,
        DisputeStatus.expired,
      };
      final activeCount =
          disputesAsync.where((d) => !terminal.contains(d.status)).length;
      if (activeCount >= 1) {
        // Bump the counter for analytics + send to the paywall.
        await ref.read(freeDisputesUsedProvider.notifier).increment();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Free plan allows 1 active dispute. Upgrade for unlimited.'),
            duration: Duration(seconds: 2),
          ),
        );
        context.push('/paywall?return=/home&trigger=free_second_dispute');
        return;
      }
    }

    final dispute = Dispute(
      id: '',
      uid: uid,
      type: DisputeType.fromId(widget.type),
      amount: amount,
      txnDate: _date ?? DateTime.now(),
      txnId: _utrCtrl.text,
      entityName: _bankName.isEmpty ? null : _bankName,
      entityId: _selectedEntityId.isEmpty ? null : _selectedEntityId,
      createdAt: DateTime.now(),
    );
    final repo = ref.read(disputeRepositoryProvider);
    try {
      final saved = await repo.saveDispute(uid, dispute);
      // B3: increment free-tier counter (no-op for premium, but cheap).
      if (!isPremium) {
        await ref.read(freeDisputesUsedProvider.notifier).increment();
      }
      // B4 analytics: dispute_created event (spec §10).
      ref.read(analyticsServiceProvider).logDisputeCreated(
            disputeType: dispute.type.id,
            isPremium: isPremium,
          );
      // B6: generate / sync reminders + schedule local notifications.
      //    Safe no-op if Firestore isn't reachable; failures are caught by
      //    the outer zone and reported to Crashlytics.
      await syncRemindersForDispute(ref, uid, saved);
      // Home uses a FutureProvider — must invalidate or the new dispute
      // won't appear until process restart.
      ref.invalidate(disputesProvider(uid));
      if (mounted) context.go('/home');
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().toLowerCase().contains('permission')
          ? 'Could not save — sign-in expired. Go Home and tap Retry.'
          : 'Could not save dispute. Check connection and try again.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = DisputeType.fromId(widget.type);
    final rulesAsync = ref.watch(rulesEngineProvider);
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: SafeArea(
        child: Column(
          children: [
            // header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
              child: Row(
                children: [
                  AppBackButton(size: 36, onTap: () => context.pop()),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'STEP 2 OF 4',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: AppColors.textSecondaryLight,
                          ),
                        ),
                        const SizedBox(height: 1),
                        const Text(
                          'Dispute details',
                          style: TextStyle(
                            fontFamily: AppTypography.family,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.accentSoft,
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                    child: Text(
                      _typeShort(type),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
                children: [
                  // grouped form card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      border:
                          Border.all(color: AppColors.dividerLight, width: 1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // BANK
                        FormFieldBox(
                          label: 'Bank',
                          child: rulesAsync.when(
                            data: (rules) => BankPickerTile(
                              bankName: _bankName,
                              onTap: () => _pickBank(context, rules),
                            ),
                            loading: () => const SizedBox(
                                height: 26,
                                child: LinearProgressIndicator()),
                            error: (_, _) => BankPickerTile(
                              bankName: _bankName,
                              onTap: () {},
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        // UTR
                        FormFieldBox(
                          label: 'UTR / RRN NUMBER',
                          helper: _utrFound
                              ? '✓ found'
                              : (type == DisputeType.upiP2p ||
                                      type == DisputeType.upiP2m ||
                                      type == DisputeType.imps
                                  ? '12 digits'
                                  : null),
                          focused: _utrFound,
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _utrCtrl,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textPrimaryLight,
                                    fontFamily: AppTypography.family,
                                    letterSpacing: 0.5,
                                  ),
                                  cursorColor: AppColors.primary,
                                  keyboardType: TextInputType.text,
                                  decoration: const InputDecoration(
                                    isCollapsed: true,
                                    isDense: true,
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  onChanged: (_) =>
                                      setState(() => _utrFound = false),
                                ),
                              ),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: _pasteFromSms,
                                child: const Text(
                                  'SMS',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.accent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        // AMOUNT
                        FormFieldBox(
                          label: 'AMOUNT DEBITED',
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            children: [
                              const Text(
                                '₹',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondaryLight,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: TextField(
                                  controller: _amountCtrl,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimaryLight,
                                    fontFamily: AppTypography.family,
                                  ),
                                  cursorColor: AppColors.primary,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    isCollapsed: true,
                                    isDense: true,
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        // DATE
                        FormFieldBox(
                          label: 'TXN DATE',
                          child: GestureDetector(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now(),
                              );
                              if (mounted) setState(() => _date = picked);
                            },
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _date == null
                                        ? 'Select date'
                                        : _fmtDate(_date!),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: _date == null
                                          ? AppColors.textTertiaryLight
                                          : AppColors.textPrimaryLight,
                                    ),
                                  ),
                                ),
                                const Text('📅',
                                    style: TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        // DESCRIPTION
                        FormFieldBox(
                          label: 'DESCRIPTION (optional)',
                          child: TextField(
                            controller: _descCtrl,
                            maxLines: 2,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimaryLight,
                              fontFamily: AppTypography.family,
                              height: 1.35,
                            ),
                            cursorColor: AppColors.primary,
                            decoration: const InputDecoration(
                              isCollapsed: true,
                              isDense: true,
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // RBI info banner
                  _buildInfoBanner(type),
                ],
              ),
            ),
            // sticky footer
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              decoration: const BoxDecoration(
                color: AppColors.surfaceLight,
                border: Border(
                  top: BorderSide(color: AppColors.dividerLight, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ESTIMATED',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: AppColors.textSecondaryLight,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          _estimate(type),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accent,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    height: 52,
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      boxShadow: AppShadows.button,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(AppRadii.md),
                        onTap: _save,
                        child: const Center(
                          child: Text(
                            'Review →',
                            style: TextStyle(
                              fontFamily: AppTypography.family,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBanner(DisputeType type) {
    if (type == DisputeType.wrongTransfer) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.alertSoft,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('⚠', style: TextStyle(fontSize: 12, color: AppColors.alert)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Wrong UPI transfers are not covered by RBI compensation. Recovery depends on beneficiary consent via bank/NPCI.',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimaryLight,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      );
    }
    if (type.tatDays == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('✓', style: TextStyle(fontSize: 12, color: AppColors.success)),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimaryLight,
                  height: 1.4,
                ),
                children: [
                  TextSpan(
                    text:
                        'RBI Circular DPSS/2018 — T+${type.tatDays} refund rule applies. ',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(
                    text:
                        "You're eligible for ₹100/day comp beyond T+${type.tatDays}.",
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _typeShort(DisputeType t) => switch (t) {
        DisputeType.upiP2p => 'UPI',
        DisputeType.upiP2m => 'UPI',
        DisputeType.atm => 'ATM',
        DisputeType.imps => 'IMPS',
        DisputeType.fastag => 'FASTag',
        DisputeType.bankCharge => 'Bank',
        DisputeType.wrongTransfer => 'Wrong',
      };

  String _fmtDate(DateTime d) =>
      '${d.day} ${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][d.month - 1]} ${d.year}, ${((d.hour % 12) == 0 ? 12 : d.hour % 12)}:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'AM' : 'PM'}';

  String _estimate(DisputeType type) {
    final amount = double.tryParse(_amountCtrl.text);
    if (amount == null || amount <= 0) return 'Add amount to estimate';
    if (type.tatDays == null || type.compensationPerDay == null) {
      return 'Claim ${CompensationCalculator.formatIndian(amount)}';
    }
    if (_date == null) return 'Claim ${CompensationCalculator.formatIndian(amount)} + compo';
    final comp = CompensationCalculator.compute(Dispute(
      id: 'preview',
      type: type,
      amount: amount,
      txnDate: _date!,
      txnId: '',
      createdAt: DateTime.now(),
    ));
    return comp.compensationDue > 0
        ? 'Claim ${CompensationCalculator.formatIndian(amount)} + ${CompensationCalculator.formatIndian(comp.compensationDue)} compo'
        : 'Claim ${CompensationCalculator.formatIndian(amount)} + compo';
  }

  Future<void> _pickBank(BuildContext context, RulesEngine rules) async {
    final isFastag = widget.type == 'fastag';
    final list = <({String name, String id})>[];
    if (isFastag) {
      for (final i in rules.fastagIssuers) {
        if (i['id'] == 'paytm') continue;
        list.add((name: i['name'] as String, id: i['id'] as String));
      }
    } else {
      list
        ..add((name: 'HDFC Bank', id: 'hdfc'))
        ..add((name: 'ICICI Bank', id: 'icici'))
        ..add((name: 'Axis Bank', id: 'axis'))
        ..add((name: 'SBI', id: 'sbi'))
        ..add((name: 'Other bank', id: 'other'));
    }
    ({String name, String id})? picked;
    await showModalBottomSheet(
      context: context,
      builder: (c) => SafeArea(
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: list.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final b = list[i];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.surfaceAltLight,
                child: Text(
                  b.name.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                      color: AppColors.primary, fontWeight: FontWeight.w700),
                ),
              ),
              title: Text(b.name),
              onTap: () {
                picked = b;
                Navigator.pop(c);
              },
            );
          },
        ),
      ),
    );
    if (picked != null) {
      setState(() {
        _bankName = picked!.name;
        _selectedEntityId = picked!.id;
      });
    }
  }
}
