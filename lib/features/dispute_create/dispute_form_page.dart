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

/// Merges onboarding-selected bank IDs (catalog names first) with [fallback].
/// Pure helper for the form picker and unit tests.
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
  /// Pre-filled from a UTR-auto-detect notification tap (Task C7).
  /// When non-null, the form opens with these values already applied so
  /// the user can tap "Create dispute" without re-keying anything.
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
  DateTime? _date;
  String _bankName = '';
  String _selectedEntityId = '';
  bool _utrFound = false;
  // Re-entrancy guard: double-tap on the submit button must not fire two
  // saveDispute calls (the `id == ''` branch in FirestoreDisputeRepository
  // does `_col.add`, so two concurrent saves would create duplicate
  // disputes). Set true on entry, cleared on success/failure.
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Apply pre-filled UTR data from an auto-detect notification tap
    // (Task C7). The router passes these as query params on /disputes/form.
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
    // B-D8 re-entrancy guard. Double-tap on the submit button would fire
    // two concurrent saveDispute calls → two duplicate disputes (add()
    // branch in FirestoreDisputeRepository does NOT dedupe). Set the guard
    // up front before any await so a fast second tap returns immediately.
    if (_saving) return;
    setState(() => _saving = true);

    // Capture l10n synchronously before any await — using BuildContext
    // across an async gap triggers use_build_context_synchronously.
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
      // Prefer already-resolved uid; only await if still loading. Always
      // bound with a timeout so _saving never sticks forever.
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

      // B3 free-tier gate: free users limited to 1 active dispute (spec §4.3).
      // Active = status in {draft, filed_l1, filed_l2, ombudsman}.
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
              duration: Duration(seconds: 3),
            ),
          );
          context.push(AppRoutes.paywallWithReturn('/home', 'free_second_dispute'));
          return;
        }
      }

      final desc = _descCtrl.text.trim();
      final now = DateTime.now();
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
      );
      final repo = ref.read(disputeRepositoryProvider);
      Dispute saved;
      try {
        saved = await repo.saveDispute(uid, dispute);
      } catch (e, st) {
        // saveDispute itself failed — this is the only real create failure.
        // Friendly copy per error class. `unavailable` = offline (Firestore
        // queues writes but our `_ensureUserDoc` get() throws first);
        // `permission-denied` = auth race; everything else = transient.
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
        // Surface the underlying failure to Crashlytics so we see the
        // distribution of failure causes in release builds (vs. today
        // where everything is a silent SnackBar).
        try {
          await FirebaseCrashlytics.instance.recordError(
            e,
            st,
            reason: 'DisputeFormPage._save',
            fatal: false,
          );
        } catch (_) {
          /* Crashlytics not initialised */
        }
        return;
      }

      // Side effects below are best-effort: a failure here must NOT un-save
      // the dispute (the old rollback-via-deleteDispute path silently
      // destroyed disputes the user thought were saved). Each step is
      // isolated in its own try/catch so one failing step can't skip the
      // rest, and none of them can delete the saved dispute.

      // B3: increment free-tier counter (no-op for premium, but cheap).
      if (!isPremium) {
        try {
          await ref.read(freeDisputesUsedProvider.notifier).increment();
        } catch (e) {
          debugPrint('best-effort step failed: $e');
        }
      }
      // B4 analytics: dispute_created event (spec §10).
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
      // B6: generate / sync reminders + schedule local notifications.
      //    Per-reminder try/catch inside the sync helper makes this
      //    non-fatal: a notification scheduling failure doesn't un-save
      //    the dispute. Firestore reminder write has its own auth retry.
      try {
        await syncRemindersForDispute(ref, uid, saved);
      } catch (e) {
        debugPrint('best-effort step failed: $e');
      }
      // Home uses a FutureProvider AND reminders has its own provider;
      // invalidate BOTH or the new dispute's reminders won't show on the
      // reminders page (only Home invalidated historically — see M-D10).
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
              // header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
                child: Row(
                  children: [
                    AppBackButton(onTap: () => context.pop()),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n?.formStep2Of4 ?? 'STEP 2 OF 4',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                              color: tc.textSecondary,
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
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: tc.accentSoft,
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
                        color: tc.surface,
                        border: Border.all(color: tc.divider, width: 1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // BANK
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
                          const SizedBox(height: 10),
                          // UTR
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
                                    cursorColor: AppColors.primary,
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
                          const SizedBox(height: 10),
                          // AMOUNT
                          FormFieldBox(
                            label:
                                l10n?.formLabelAmountDebited ??
                                'AMOUNT DEBITED',
                            helper:
                                l10n?.formAmountCap ?? 'Max ₹5,00,000',
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
                                    ),
                                    cursorColor: AppColors.primary,
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
                          const SizedBox(height: 10),
                          // DATE
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
                                  const Text(
                                    '📅',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          // DESCRIPTION
                          FormFieldBox(
                            label:
                                l10n?.formLabelDescription ??
                                'DESCRIPTION (optional)',
                            child: TextField(
                              controller: _descCtrl,
                              minLines: 3,
                              maxLines: 6,
                              maxLength: 500,
                              maxLengthEnforcement: MaxLengthEnforcement.enforced,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: tc.textPrimary,
                                fontFamily: AppTypography.family,
                                height: 1.4,
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
                decoration: BoxDecoration(
                  color: tc.surface,
                  border: Border(top: BorderSide(color: tc.divider, width: 1)),
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
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: tc.textSecondary,
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
                    AnimatedOpacity(
                      opacity: _saving ? 0.6 : 1.0,
                      duration: const Duration(milliseconds: 150),
                      child: Container(
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
                            // onTap is null while _saving — disables the tap
                            // affordance AND the InkWell ripple (Material rule:
                            // a null onTap is treated as a disabled ink well).
                            onTap: _saving ? null : _save,
                            child: Center(
                              child: _saving
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.4,
                                        valueColor: AlwaysStoppedAnimation(
                                          Colors.white,
                                        ),
                                      ),
                                    )
                                  : Text(
                                      AppLocalizations.of(
                                            context,
                                          )?.formCreateDispute ??
                                          'Create dispute',
                                      style: const TextStyle(
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
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBanner(DisputeType type) {
    final tc = AppThemeColors.of(context);
    final l10n = AppLocalizations.of(context);
    if (type == DisputeType.wrongTransfer) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: tc.alertSoft,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '⚠',
              style: TextStyle(fontSize: 12, color: AppColors.alert),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n?.formWrongUpiNote ??
                    'Wrong UPI transfers are not covered by RBI compensation. Recovery depends on beneficiary consent via bank/NPCI.',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: tc.textPrimary,
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
        color: tc.accentSoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '✓',
            style: TextStyle(fontSize: 12, color: AppColors.success),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: tc.textPrimary,
                  height: 1.4,
                ),
                children: [
                  TextSpan(
                    text:
                        l10n?.formRbiCircularPrefix('${type.tatDays}') ??
                        'RBI Circular DPSS/2018 — T+${type.tatDays} refund rule applies. ',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(
                    text:
                        l10n?.formEligiblePerDayComp('${type.tatDays}') ??
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

  String _typeShort(DisputeType t) {
    final l10n = AppLocalizations.of(context);
    return switch (t) {
      DisputeType.upiP2p => 'UPI',
      DisputeType.upiP2m => 'UPI',
      DisputeType.atm => 'ATM',
      DisputeType.imps => 'IMPS',
      DisputeType.fastag => 'FASTag',
      DisputeType.bankCharge => l10n?.typeShortBank ?? 'Bank',
      DisputeType.wrongTransfer => l10n?.typeShortWrong ?? 'Wrong',
    };
  }

  String _fmtDate(DateTime d) =>
      '${d.day} ${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][d.month - 1]} ${d.year}, ${((d.hour % 12) == 0 ? 12 : d.hour % 12)}:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'AM' : 'PM'}';

  String _estimate(DisputeType type) {
    final l10n = AppLocalizations.of(context);
    final raw = double.tryParse(_amountCtrl.text);
    if (raw == null || raw <= 0) {
      return l10n?.formAddAmountToEstimate ?? 'Add amount to estimate';
    }
    // HI-1 / ME-3: cap the live preview at the ₹5,00,000 maximum the
    // form accepts, so the estimate never shows a value the user can't
    // actually submit.
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

    // Non-FASTag: show ALL banks with onboarding picks first.
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
      builder: (c) => SafeArea(
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: list.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final b = list[i];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: tc.surfaceAlt,
                child: Text(
                  b.name.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
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

  /// Non-FASTag picker: shows ALL `BankCatalog.banks` with a search bar.
  /// Onboarding-picked banks (that exist in the catalog) are shown first
  /// under a 'Your banks' header, then 'All banks' follows. 'other' is
  /// always pinned at the bottom.
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
            // Your banks (onboarding-picked, that exist in the catalog).
            final yourBanks = BankCatalog.banks
                .where((b) => selectedIds.contains(b.id))
                .toList();

            // All banks (filtered by search). 'other' always included.
            final allBanks = BankCatalog.banks.where((b) {
              if (b.id == 'other') return true;
              if (searchQuery.isEmpty) return true;
              final q = searchQuery.toLowerCase();
              return b.name.toLowerCase().contains(q) ||
                  b.short.toLowerCase().contains(q) ||
                  b.id.toLowerCase().contains(q);
            }).toList();

            // Pull 'other' out so it can be pinned at the bottom.
            BankEntry? otherEntry;
            final remaining = <BankEntry>[];
            for (final b in allBanks) {
              if (b.id == 'other') {
                otherEntry = b;
              } else {
                remaining.add(b);
              }
            }
            // HI-3: never fall back to an arbitrary bank (the old `.last`
            // could surface a random bank when the 'other' entry is renamed
            // or removed). If 'other' is missing, simply hide the pinned
            // tile — the user still has every real bank above.
            final other = otherEntry;

            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.7,
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    decoration: BoxDecoration(
                      color: tc.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Title
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        l10n?.formLabelBank ?? 'Select Bank',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: tc.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  // Search bar
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
                  // List
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: 20),
                      children: [
                        // Your banks section (only when not searching and the
                        // user has onboarding picks in the catalog)
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
                        // All banks / search results
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
                        // Other bank pinned at bottom (only if present in the catalog)
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
                  color: isSelected ? AppColors.accent : tc.textPrimary,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, size: 20, color: AppColors.accent),
          ],
        ),
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
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.accent,
            ),
          ),
        ),
      ),
    );
  }
}
