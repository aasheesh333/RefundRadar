import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:refund_radar/core/router/app_routes.dart';
import 'package:refund_radar/core/providers/app_state_provider.dart';
import 'package:refund_radar/core/providers/auth_provider.dart';
import 'package:refund_radar/core/providers/dispute_provider.dart';
import 'package:refund_radar/core/theme/app_tokens.dart';
import 'package:refund_radar/core/theme/app_theme_colors.dart';
import 'package:refund_radar/data/models/activity_log_entry.dart';
import 'package:refund_radar/data/models/dispute.dart';
import 'package:refund_radar/data/repositories/reminder_repository.dart';
import 'package:refund_radar/data/repositories/rules_engine_repository.dart';
import 'package:refund_radar/l10n/app_localizations.dart';
import 'package:refund_radar/services/analytics_service.dart';
import 'package:refund_radar/services/compensation_calculator.dart';
import 'package:refund_radar/services/sms_inbox_service.dart';
import 'package:refund_radar/services/sms_parser.dart';
import 'package:refund_radar/data/constants/bank_catalog.dart';
import 'package:refund_radar/features/add_banks/add_banks_page.dart';
import 'package:refund_radar/features/dispute_create/create_dispute_auth_guard.dart';
import 'package:refund_radar/features/dispute_create/fallback_banks.dart';
import 'package:refund_radar/shared/widgets/app_back_button.dart';
import 'package:refund_radar/shared/widgets/form_field_box.dart';
import 'package:refund_radar/shared/widgets/bank_picker_tile.dart';

List<({String name, String id})> mergeOnboardBanksWithFallback({
  required List<String> selectedIds,
  required List<BankEntry> catalog,
  required List<({String name, String id})> fallback,
}) {
  final byId = {for (final b in catalog) b.id: b};
  final out = <({String name, String id})>[];
  final seen = <String>{};
  for (final id in selectedIds) {
    final entry = byId[id];
    if (entry == null) continue;
    if (seen.add(id)) {
      out.add((name: entry.name, id: entry.id));
    }
  }
  for (final b in fallback) {
    if (seen.add(b.id)) out.add(b);
  }
  return out;
}

class DisputeFormPage extends ConsumerStatefulWidget {
  final String type;
  final String? prefilledUtr;
  final double? prefilledAmount;
  final String? prefilledSender;
  const DisputeFormPage({
    super.key,
    required this.type,
    this.prefilledUtr,
    this.prefilledAmount,
    this.prefilledSender,
  });
  @override
  ConsumerState<DisputeFormPage> createState() => _DisputeFormPageState();
}

class _DisputeFormPageState extends ConsumerState<DisputeFormPage> {
  final _amountCtrl = TextEditingController();
  final _utrCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _vpaCtrl = TextEditingController();
  final _vpaPayeeCtrl = TextEditingController();
  final _vehicleNoCtrl = TextEditingController();
  final _plazaCtrl = TextEditingController();
  final _atmIdCtrl = TextEditingController();
  final _cardLast4Ctrl = TextEditingController();
  final _beneficiaryAcctCtrl = TextEditingController();
  final _beneficiaryIfscCtrl = TextEditingController();
  DateTime? _date;
  String _bankName = '';
  String _selectedEntityId = '';
  bool _utrFound = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.prefilledUtr != null && widget.prefilledUtr!.isNotEmpty) {
      _utrCtrl.text = widget.prefilledUtr!;
      _utrFound = true;
    }
    if (widget.prefilledAmount != null) {
      _amountCtrl.text = widget.prefilledAmount!.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _utrCtrl.dispose();
    _descCtrl.dispose();
    _vpaCtrl.dispose();
    _vpaPayeeCtrl.dispose();
    _vehicleNoCtrl.dispose();
    _plazaCtrl.dispose();
    _atmIdCtrl.dispose();
    _cardLast4Ctrl.dispose();
    _beneficiaryAcctCtrl.dispose();
    _beneficiaryIfscCtrl.dispose();
    super.dispose();
  }

  void _applyParsed(SmsParseResult parsed) {
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

  Future<void> _pasteFromSms() async {
    final data = await Clipboard.getData('text/plain');
    if (data?.text == null || data!.text!.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)?.formClipboardEmpty ??
                'Clipboard empty — copy an SMS first.',
          ),
        ),
      );
      return;
    }
    _applyParsed(SmsParser.parse(data.text!));
  }

  Future<void> _pickFromSmsInbox() async {
    final l10n = AppLocalizations.of(context);
    final inbox = ref.read(smsInboxServiceProvider);
    final granted = await inbox.requestPermission();
    if (!granted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n?.formSmsPermissionDeniedAction ??
                'SMS permission denied. Tap Paste to use a copied SMS, or enter details manually.',
          ),
        ),
      );
      return;
    }
    late final List<InboxSms> messages;
    try {
      messages = await inbox.queryBankLikeMessages();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n?.formSmsInboxFailed ??
                'Could not read SMS inbox. Paste a copied SMS or enter details manually.',
          ),
        ),
      );
      return;
    }
    if (!mounted) return;
    if (messages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n?.formNoBankSmsAction ??
                'No likely refund SMS found. Paste a copied SMS or enter details manually.',
          ),
        ),
      );
      return;
    }
    final picked = await showModalBottomSheet<InboxSms>(
      context: context,
      isScrollControlled: true,
      builder: (c) {
        final tc = AppThemeColors.of(c);
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(c).size.height * 0.55,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Text(
                    AppLocalizations.of(c)?.formPickBankSms ??
                        'Pick a bank SMS',
                    style: TextStyle(
                      fontFamily: AppTypography.family,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: tc.textPrimary,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    itemCount: messages.length,
separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (itemCtx, i) {
                      final m = messages[i];
                      return ListTile(
                        title: Text(
                          m.address.isEmpty
                              ? (AppLocalizations.of(c)?.formSms ?? 'SMS')
                              : m.address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          m.body,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => Navigator.pop(c, m),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (picked == null || !mounted) return;
    _applyParsed(SmsParser.parse(picked.body));
  }

  void _save() async {
    if (_saving) return;
    setState(() => _saving = true);

    final l10n = AppLocalizations.of(context);

    try {
      final amount = double.tryParse(_amountCtrl.text) ?? 0;
      if (amount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)?.formEnterAmount ??
                  'Enter the debited amount',
            ),
          ),
        );
        return;
      }
      if (amount > 500000) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)?.formAmountCap ??
                  'Amount must be ≤ ₹5,00,000',
            ),
          ),
        );
        return;
      }
      if (_bankName.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)?.formSelectBank ?? 'Select a bank',
            ),
          ),
        );
        return;
      }
      if (_utrCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)?.formUtrRequired ??
                  'Enter the UTR / transaction ID',
            ),
          ),
        );
        return;
      }
      if (_date == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)?.formSelectDate ?? 'Select date',
            ),
          ),
        );
        return;
      }
      String? resolvedUid = ref.read(userIdProvider).asData?.value;
      if (!isValidAuthUid(resolvedUid)) {
        try {
          resolvedUid = await ref
              .read(userIdProvider.future)
              .timeout(const Duration(seconds: 10));
        } catch (_) {
          resolvedUid = null;
        }
      }
      if (!isValidAuthUid(resolvedUid)) {
        if (!mounted) return;
        final authErr = ref.read(lastAuthErrorProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              (authErr != null &&
                      authErr.toLowerCase().contains('operation-not-allowed'))
                  ? 'Anonymous sign-in is disabled in Firebase Console. Enable it, then reopen the app.'
                  : AppLocalizations.of(context)?.formAuthRequired ??
                        'Could not sign in. Please restart the app and try again.',
            ),
            duration: const Duration(seconds: 6),
          ),
        );
        return;
      }
      final uid = resolvedUid!;

      final isPremium = ref.read(isPremiumProvider);
      if (!isPremium) {
        List<Dispute> existing;
        try {
          existing = await ref
              .read(disputesProvider(uid).future)
              .timeout(const Duration(seconds: 12));
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                e.toString().toLowerCase().contains('permission')
                    ? 'Could not verify free plan limit. Tap Retry on Home, then try again.'
                    : 'Could not check existing disputes. Check connection and try again.',
              ),
            ),
          );
          return;
        }
        const terminal = {DisputeStatus.resolved, DisputeStatus.expired};
        final activeCount = existing
            .where((d) => !terminal.contains(d.status))
            .length;
        if (activeCount >= 1) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)?.formFreeLimitReached ??
                    'Free plan allows 1 active dispute. Upgrade for unlimited.',
              ),
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: AppLocalizations.of(context)?.formFreeLimitUpgrade ??
                    'Upgrade',
                onPressed: () => context.push(
                  AppRoutes.paywallWithParams(
                    trigger: 'free_second_dispute',
                    returnPath: AppRoutes.home,
                  ),
                ),
              ),
            ),
          );
          return;
        }
      }

      final desc = _descCtrl.text.trim();
      final now = DateTime.now();
      String? nullifyEmpty(String s) {
        final t = s.trim();
        return t.isEmpty ? null : t;
      }

      final dispute = Dispute(
        id: '',
        uid: uid,
        type: DisputeType.fromId(widget.type),
        amount: amount,
        txnDate: _date ?? now,
        txnId: _utrCtrl.text.trim(),
        entityName: _bankName.isEmpty ? null : _bankName,
        entityId: _selectedEntityId.isEmpty ? null : _selectedEntityId,
        createdAt: now,
        description: desc.isEmpty ? null : desc,
        activityLog: [
          ActivityLogEntry(
            type: ActivityLogEntry.disputeCreated,
            label: l10n?.activityDisputeCreated ?? 'Dispute created',
            meta: _fmtDate(now),
            timestamp: now,
            highlighted: true,
          ),
        ],
        vpa: nullifyEmpty(_vpaCtrl.text),
        vpaPayee: nullifyEmpty(_vpaPayeeCtrl.text),
        vehicleNo: nullifyEmpty(_vehicleNoCtrl.text),
        plazaName: nullifyEmpty(_plazaCtrl.text),
        atmId: nullifyEmpty(_atmIdCtrl.text),
        cardLast4: nullifyEmpty(_cardLast4Ctrl.text),
        beneficiaryAccountNo: nullifyEmpty(_beneficiaryAcctCtrl.text),
        beneficiaryIfsc: nullifyEmpty(_beneficiaryIfscCtrl.text),
      );
      final repo = ref.read(disputeRepositoryProvider);
      Dispute saved;
      try {
        saved = await repo.saveDispute(uid, dispute);
      } catch (e, st) {
        final s = e.toString().toLowerCase();
        final msg =
            s.contains('permission-denied') ||
                s.contains('permission_denied') ||
                s.contains('unauthenticated')
            ? 'Could not save — sign-in expired. Go Home and tap Retry.'
            : s.contains('unavailable') ||
                  s.contains('network') ||
                  s.contains('socket')
            ? 'You appear to be offline. Reconnect and try again.'
            : 'Could not save dispute. Check connection and try again.';
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
        try {
          await FirebaseCrashlytics.instance.recordError(
            e,
            st,
            reason: 'DisputeFormPage._save',
            fatal: false,
          );
        } catch (_) {}
        return;
      }

      if (!isPremium) {
        try {
          await ref.read(freeDisputesUsedProvider.notifier).increment();
        } catch (e) {
          debugPrint('best-effort step failed: $e');
        }
      }
      try {
        ref
            .read(analyticsServiceProvider)
            .logDisputeCreated(
              disputeType: dispute.type.id,
              isPremium: isPremium,
            );
      } catch (e) {
        debugPrint('best-effort step failed: $e');
      }
      try {
        await syncRemindersForDispute(ref, uid, saved);
      } catch (e) {
        debugPrint('best-effort step failed: $e');
      }
      try {
        ref.invalidate(disputesProvider(uid));
        ref.invalidate(remindersProvider(uid));
      } catch (e) {
        debugPrint('best-effort step failed: $e');
      }
      if (mounted) context.go(AppRoutes.home);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tc = AppThemeColors.of(context);
    final type = DisputeType.fromId(widget.type);
    final rulesAsync = ref.watch(rulesEngineProvider);
    return Scaffold(
      backgroundColor: tc.bg,
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: SafeArea(
          child: Column(
            children: [
              _PageHeader(type: type, tc: tc, l10n: l10n),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: tc.surface,
                        border: Border.all(color: tc.divider),
                        borderRadius: BorderRadius.circular(AppRadii.lg),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FormFieldBox(
                            label: l10n?.formLabelBank ?? 'Bank',
                            child: rulesAsync.when(
                              data: (rules) => BankPickerTile(
                                bankName: _bankName,
                                onTap: () => _pickBank(context, rules),
                              ),
                              loading: () => const SizedBox(
                                height: 26,
                                child: LinearProgressIndicator(),
                              ),
                              error: (_, _) => BankPickerTile(
                                bankName: _bankName,
                                onTap: () async {
                                  final selected =
                                      await AddBanksPage.loadSelectedBanks();
                                  if (!context.mounted) return;
                                  await _showBankPicker(
                                    context,
                                    mergeOnboardBanksWithFallback(
                                      selectedIds: selected,
                                      catalog: BankCatalog.banks,
                                      fallback: kFallbackBanks,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          FormFieldBox(
                            label: l10n?.formLabelUtr ?? 'UTR / RRN NUMBER',
                            helper: _utrFound
                                ? (l10n?.formUtrFound ?? '✓ found')
                                : (type == DisputeType.upiP2p ||
                                          type == DisputeType.upiP2m ||
                                          type == DisputeType.imps
                                      ? (l10n?.formUtrHint12 ?? '12 digits')
                                      : null),
                            focused: _utrFound,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _utrCtrl,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      color: tc.textPrimary,
                                      fontFamily: AppTypography.family,
                                      letterSpacing: 0.5,
                                    ),
                                    cursorColor: tc.ctaBackground,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    maxLength: 22,
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
                                const SizedBox(width: 8),
                                _InlineChipButton(
                                  label: l10n?.formInbox ?? 'Inbox',
                                  onTap: _pickFromSmsInbox,
                                ),
                                const SizedBox(width: 8),
                                _InlineChipButton(
                                  label: l10n?.formPaste ?? 'Paste',
                                  onTap: _pasteFromSms,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          FormFieldBox(
                            label: l10n?.formLabelAmountDebited ??
                                'AMOUNT DEBITED',
                            helper: l10n?.formAmountCap ?? 'Max ₹5,00,000',
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  '₹',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: tc.textSecondary,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: TextField(
                                    controller: _amountCtrl,
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: tc.textPrimary,
                                      fontFamily: AppTypography.family,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                    cursorColor: tc.ctaBackground,
                                    keyboardType: TextInputType.number,
                                    maxLength: 6,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    decoration: const InputDecoration(
                                      isCollapsed: true,
                                      isDense: true,
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.zero,
                                      counterText: '',
                                    ),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          FormFieldBox(
                            label: l10n?.formLabelTxnDate ?? 'TXN DATE',
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
                                          ? (l10n?.formSelectDate ??
                                              'Select date')
                                          : _fmtDate(_date!),
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: _date == null
                                            ? tc.textTertiary
                                            : tc.textPrimary,
                                      ),
                                    ),
                                  ),
                                  Icon(Icons.calendar_today_outlined,
                                      size: 16, color: tc.textSecondary),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          FormFieldBox(
                            label: l10n?.formLabelDescription ??
                                'DESCRIPTION (OPTIONAL)',
                            child: TextField(
                              controller: _descCtrl,
                              minLines: 3,
                              maxLines: 6,
                              maxLength: 500,
                              maxLengthEnforcement:
                                  MaxLengthEnforcement.enforced,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: tc.textPrimary,
                                fontFamily: AppTypography.family,
                                height: 1.4,
                              ),
                              cursorColor: tc.ctaBackground,
                              decoration: const InputDecoration(
                                isCollapsed: true,
                                isDense: true,
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                          ..._buildCategorySpecificFields(type, tc, l10n),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildInfoBanner(type),
                  ],
                ),
              ),
              _StickyFooter(
                estimate: _estimate(type),
                saving: _saving,
                onSave: _saving ? null : _save,
                tc: tc,
                l10n: l10n,
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildCategorySpecificFields(
    DisputeType type,
    AppThemeColors tc,
    AppLocalizations? l10n,
  ) {
    Widget field(
      String label,
      TextEditingController c, {
      String? helper,
      TextInputType? keyboard,
      int? maxLen,
      List<TextInputFormatter>? formatters,
    }) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: FormFieldBox(
          label: label,
          helper: helper,
          child: TextField(
            controller: c,
            keyboardType: keyboard,
            maxLength: maxLen,
            inputFormatters: formatters,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: tc.textPrimary,
              fontFamily: AppTypography.family,
            ),
            cursorColor: tc.ctaBackground,
            decoration: const InputDecoration(
              isCollapsed: true,
              isDense: true,
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              counterText: '',
            ),
          ),
        ),
      );
    }

    switch (type) {
      case DisputeType.upiP2p:
      case DisputeType.upiP2m:
        return [
          field(
            l10n?.formLabelVpa ?? 'YOUR VPA',
            _vpaCtrl,
            helper: l10n?.formLabelVpaHint ?? 'e.g. name@upi',
          ),
        ];
      case DisputeType.imps:
        return [
          field(
            l10n?.formLabelVpa ?? 'YOUR VPA / ACCOUNT',
            _vpaCtrl,
            helper: l10n?.formLabelVpaHint ?? 'e.g. name@upi or A/C no.',
          ),
        ];
      case DisputeType.atm:
        return [
          field(
            l10n?.formLabelAtmId ?? 'ATM ID / LOCATION',
            _atmIdCtrl,
            helper: l10n?.formLabelAtmIdHint ?? 'e.g. SBI ATM, MG Road',
          ),
          field(
            l10n?.formLabelCardLast4 ?? 'CARD LAST 4 DIGITS',
            _cardLast4Ctrl,
            keyboard: TextInputType.number,
            maxLen: 4,
            formatters: [FilteringTextInputFormatter.digitsOnly],
          ),
        ];
      case DisputeType.fastag:
        return [
          field(
            l10n?.formLabelVehicleNo ?? 'VEHICLE NUMBER',
            _vehicleNoCtrl,
            helper: l10n?.formLabelVehicleNoHint ?? 'e.g. MH12AB1234',
            maxLen: 12,
          ),
          field(
            l10n?.formLabelPlazaName ?? 'TOLL PLAZA',
            _plazaCtrl,
            helper: l10n?.formLabelPlazaNameHint ??
                'e.g. Khopoli Plaza, Mumbai-Pune',
          ),
        ];
      case DisputeType.wrongTransfer:
        return [
          field(
            l10n?.formLabelVpaPayee ?? 'PAYEE VPA / ACCOUNT',
            _vpaPayeeCtrl,
            helper: l10n?.formLabelVpaPayeeHint ??
                'VPA or account credited by mistake',
          ),
          field(
            l10n?.formLabelBeneficiaryAcct ?? 'BENEFICIARY ACCOUNT',
            _beneficiaryAcctCtrl,
            keyboard: TextInputType.number,
            maxLen: 18,
            formatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          field(
            l10n?.formLabelBeneficiaryIfsc ?? 'BENEFICIARY IFSC',
            _beneficiaryIfscCtrl,
            helper: l10n?.formLabelBeneficiaryIfscHint ?? '11 chars',
            maxLen: 11,
          ),
        ];
      case DisputeType.bankCharge:
        return [];
    }
  }

  Widget _buildInfoBanner(DisputeType type) {
    final tc = AppThemeColors.of(context);
    final l10n = AppLocalizations.of(context);
    if (type == DisputeType.wrongTransfer) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: tc.alertSoft,
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.alert.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              child: const Text('⚠',
                  style: TextStyle(fontSize: 12, color: AppColors.alert)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n?.formWrongUpiNote ??
                    'Wrong UPI transfers are not covered by RBI compensation. Recovery depends on beneficiary consent via bank/NPCI.',
                style: TextStyle(
                  fontFamily: AppTypography.family,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: tc.textPrimary,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      );
    }
    if (type.tatDays == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tc.accentSoft,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child:
                const Text('✓', style: TextStyle(fontSize: 12, color: AppColors.success)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontFamily: AppTypography.family,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: tc.textPrimary,
                  height: 1.45,
                ),
                children: [
                  TextSpan(
                    text: l10n?.formRbiCircularPrefix('${type.tatDays}') ??
                        'RBI Circular DPSS/2018 — T+${type.tatDays} refund rule applies. ',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(
                    text: l10n?.formEligiblePerDayComp('${type.tatDays}') ??
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

  String _fmtDate(DateTime d) =>
      '${d.day} ${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][d.month - 1]} ${d.year}, ${((d.hour % 12) == 0 ? 12 : d.hour % 12)}:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'AM' : 'PM'}';

  String _estimate(DisputeType type) {
    final l10n = AppLocalizations.of(context);
    final raw = double.tryParse(_amountCtrl.text);
    if (raw == null || raw <= 0) {
      return l10n?.formAddAmountToEstimate ?? 'Add amount to estimate';
    }
    final amount = raw > 500000 ? 500000.0 : raw;
    final amtStr = CompensationCalculator.formatIndian(amount);
    if (type.tatDays == null || type.compensationPerDay == null) {
      return l10n?.formClaimAmount(amtStr) ?? 'Claim $amtStr';
    }
    if (_date == null) {
      return l10n?.formClaimAmountCompo(amtStr) ?? 'Claim $amtStr + compo';
    }
    final comp = CompensationCalculator.compute(
      Dispute(
        id: 'preview',
        type: type,
        amount: amount,
        txnDate: _date!,
        txnId: '',
        createdAt: DateTime.now(),
      ),
    );
    return comp.compensationDue > 0
        ? (l10n?.formClaimAmountCompoDue(
                amtStr,
                CompensationCalculator.formatIndian(comp.compensationDue),
              ) ??
            'Claim $amtStr + ${CompensationCalculator.formatIndian(comp.compensationDue).toString()} compo')
        : (l10n?.formClaimAmountCompo(amtStr) ?? 'Claim $amtStr + compo');
  }

  Future<void> _pickBank(BuildContext context, RulesEngine rules) async {
    final isFastag = widget.type == 'fastag';
    if (isFastag) {
      final list = <({String name, String id})>[];
      for (final i in rules.fastagIssuers) {
        if (i['id'] == 'paytm') continue;
        list.add((name: i['name'] as String, id: i['id'] as String));
      }
      if (!context.mounted) return;
      await _showBankPicker(context, list);
      return;
    }

    final selectedIds = await AddBanksPage.loadSelectedBanks();
    if (!context.mounted) return;
    await _showBankPickerWithSearch(context, selectedIds);
  }

  Future<void> _showBankPicker(
    BuildContext context,
    List<({String name, String id})> list,
  ) async {
    final tc = AppThemeColors.of(context);
    ({String name, String id})? picked;
    await showModalBottomSheet(
      context: context,
      backgroundColor: tc.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (c) => SafeArea(
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: list.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final b = list[i];
            final isSelected = _bankName == b.name;
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: tc.surfaceAlt,
                child: Text(
                  b.name.isEmpty ? '?' : b.name.substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    color: isSelected ? tc.ctaBackground : tc.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              title: Text(b.name,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: tc.textPrimary,
                  )),
              trailing: isSelected
                  ? Icon(Icons.check_circle, size: 20, color: tc.ctaBackground)
                  : null,
              onTap: () {
                picked = b;
                Navigator.pop(c);
              },
            );
          },
        ),
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _bankName = picked!.name;
        _selectedEntityId = picked!.id;
      });
    }
  }

  Future<void> _showBankPickerWithSearch(
    BuildContext context,
    List<String> selectedIds,
  ) async {
    final tc = AppThemeColors.of(context);
    final l10n = AppLocalizations.of(context);
    String searchQuery = '';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: tc.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final yourBanks = BankCatalog.banks
                .where((b) => selectedIds.contains(b.id))
                .toList();

            final allBanks = BankCatalog.banks.where((b) {
              if (b.id == 'other') return true;
              if (searchQuery.isEmpty) return true;
              final q = searchQuery.toLowerCase();
              return b.name.toLowerCase().contains(q) ||
                  b.short.toLowerCase().contains(q) ||
                  b.id.toLowerCase().contains(q);
            }).toList();

            BankEntry? otherEntry;
            final remaining = <BankEntry>[];
            for (final b in allBanks) {
              if (b.id == 'other') {
                otherEntry = b;
              } else {
                remaining.add(b);
              }
            }
            final other = otherEntry;

            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.7,
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    decoration: BoxDecoration(
                      color: tc.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        l10n?.formLabelBank ?? 'Select Bank',
                        style: TextStyle(
                          fontFamily: AppTypography.family,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: tc.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                    child: TextField(
                      autofocus: false,
                      decoration: InputDecoration(
                        hintText: l10n?.formBankSearchHint ?? 'Search bank...',
                        hintStyle:
                            TextStyle(color: tc.textTertiary, fontSize: 14),
                        prefixIcon: Icon(Icons.search,
                            size: 20, color: tc.textTertiary),
                        filled: true,
                        fillColor: tc.surfaceAlt,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 8),
                      ),
                      onChanged: (value) =>
                          setSheetState(() => searchQuery = value),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: 20),
                      children: [
                        if (searchQuery.isEmpty && yourBanks.isNotEmpty) ...[
                          _bankSectionHeader(
                            sheetContext,
                            l10n?.formBankYourBanks ?? 'Your banks',
                            tc,
                          ),
                          for (final b in yourBanks)
                            _bankTile(sheetContext, b, tc, () {
                              setState(() {
                                _bankName = b.name;
                                _selectedEntityId = b.id;
                              });
                              Navigator.pop(context);
                            }),
                          const SizedBox(height: 8),
                        ],
                        _bankSectionHeader(
                          sheetContext,
                          searchQuery.isEmpty
                              ? (l10n?.formBankAllBanks ?? 'All banks')
                              : (l10n?.formBankSearchResults ??
                                  'Search results'),
                          tc,
                        ),
                        for (final b in remaining)
                          _bankTile(sheetContext, b, tc, () {
                            setState(() {
                              _bankName = b.name;
                              _selectedEntityId = b.id;
                            });
                            Navigator.pop(context);
                          }),
                        if (other != null)
                          _bankTile(sheetContext, other, tc, () {
                            setState(() {
                              _bankName = other.name;
                              _selectedEntityId = other.id;
                            });
                            Navigator.pop(context);
                          }),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _bankSectionHeader(
    BuildContext context,
    String label,
    AppThemeColors tc,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: AppTypography.family,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
          color: tc.textTertiary,
        ),
      ),
    );
  }

  Widget _bankTile(
    BuildContext context,
    BankEntry bank,
    AppThemeColors tc,
    VoidCallback onTap,
  ) {
    final isSelected = _bankName == bank.name;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                bank.name,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight:
                      isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? tc.ctaBackground : tc.textPrimary,
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, size: 20, color: tc.ctaBackground),
          ],
        ),
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  final DisputeType type;
  final AppThemeColors tc;
  final AppLocalizations? l10n;
  const _PageHeader({
    required this.type,
    required this.tc,
    required this.l10n,
  });

  String _typeShort(DisputeType t) => switch (t) {
        DisputeType.upiP2p => 'UPI',
        DisputeType.upiP2m => 'UPI',
        DisputeType.atm => 'ATM',
        DisputeType.imps => 'IMPS',
        DisputeType.fastag => 'FASTag',
        DisputeType.bankCharge => 'Bank',
        DisputeType.wrongTransfer => 'Wrong',
      };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
      child: Row(
        children: [
          AppBackButton(onTap: () => context.pop()),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n?.formStep2Of4 ?? 'STEP 2 OF 2',
                  style: TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: tc.textTertiary,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  l10n?.formDisputeDetails ?? 'Dispute details',
                  style: TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: tc.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: tc.accentSoft,
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
            child: Text(
              _typeShort(type),
              style: TextStyle(
                fontFamily: AppTypography.family,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: tc.ctaBackground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StickyFooter extends StatelessWidget {
  final String estimate;
  final bool saving;
  final VoidCallback? onSave;
  final AppThemeColors tc;
  final AppLocalizations? l10n;
  const _StickyFooter({
    required this.estimate,
    required this.saving,
    required this.onSave,
    required this.tc,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: tc.surface,
        border: Border(top: BorderSide(color: tc.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n?.formEstimated ?? 'ESTIMATED',
                  style: TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: tc.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  estimate,
                  style: TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: tc.ctaBackground,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            height: 46,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: tc.ctaBackground,
                foregroundColor: tc.ctaForeground,
                disabledBackgroundColor: tc.ctaBackground.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
              ),
              onPressed: onSave,
              child: saving
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor:
                            AlwaysStoppedAnimation(tc.ctaForeground),
                      ),
                    )
                  : Text(
                      AppLocalizations.of(context)?.formCreateDispute ??
                          'Create dispute',
                      style: TextStyle(
                        fontFamily: AppTypography.family,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineChipButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _InlineChipButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    return Material(
      color: tc.accentSoft,
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.sm),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppTypography.family,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: tc.ctaBackground,
            ),
          ),
        ),
      ),
    );
  }
}
