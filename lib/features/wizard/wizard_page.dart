import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:refund_radar/core/router/app_routes.dart';
import 'package:refund_radar/core/providers/auth_provider.dart';
import 'package:refund_radar/core/providers/dispute_provider.dart';
import 'package:refund_radar/core/theme/app_theme_colors.dart';
import 'package:refund_radar/data/models/dispute.dart';
import 'package:refund_radar/data/models/template_fill.dart';
import 'package:refund_radar/data/repositories/reminder_repository.dart';
import 'package:refund_radar/data/repositories/rules_engine_repository.dart';
import 'package:refund_radar/features/dispute_create/create_dispute_auth_guard.dart';
import 'package:refund_radar/l10n/app_localizations.dart';
import 'package:refund_radar/services/analytics_service.dart';
import 'package:refund_radar/core/theme/app_tokens.dart';
import 'package:refund_radar/shared/widgets/branded_error_banner.dart';
import 'package:refund_radar/shared/widgets/skeleton.dart';
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
  bool _saving = false;
  bool _levelHydrated = false;

  @override
  void dispose() {
    _ticketController.dispose();
    super.dispose();
  }

  DisputeStatus _statusForLevel(int level) {
    if (level >= 2) return DisputeStatus.ombudsman;
    if (level == 1) return DisputeStatus.filedL2;
    return DisputeStatus.filedL1;
  }

  String _ticketKeyForLevel(int level) {
    if (level >= 2) return 'ombudsman';
    if (level == 1) return 'l2';
    return 'l1';
  }

  Future<void> _persistMarkFiled() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)?.formAuthRequired ??
                  'Could not sign in. Please restart the app and try again.',
            ),
          ),
        );
        return;
      }
      final uid = resolvedUid!;
      List<Dispute> disputes;
      try {
        disputes = await ref
            .read(disputesProvider(uid).future)
            .timeout(const Duration(seconds: 12));
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)?.wizardCouldNotLoadDispute ??
                  'Could not load dispute. Check connection and try again.',
            ),
          ),
        );
        return;
      }
      final existing = disputes
          .where((e) => e.id == widget.disputeId)
          .firstOrNull;
      if (existing == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)?.wizardDisputeNotFound ??
                  'Dispute not found.',
            ),
          ),
        );
        return;
      }

      final key = _ticketKeyForLevel(_currentLevel);
      final ticket = _ticketController.text.trim();
      final nextTickets = Map<String, String?>.from(existing.ticketNumbers);
      final nextFiled = Map<String, DateTime?>.from(existing.filedDates);
      if (ticket.isNotEmpty) nextTickets[key] = ticket;
      nextFiled[key] = DateTime.now();

      final updated = existing.copyWith(
        status: _statusForLevel(_currentLevel),
        ticketNumbers: nextTickets,
        filedDates: nextFiled,
      );
      await ref.read(disputeRepositoryProvider).saveDispute(uid, updated);
      try {
        await syncRemindersForDispute(ref, uid, updated);
      } catch (e) {
        debugPrint('wizard mark-filed reminder sync failed: $e');
      }
      ref.invalidate(disputesProvider(uid));
      ref.invalidate(remindersProvider(uid));
      if (mounted) {
        setState(() {
          if (_currentLevel < 2) _currentLevel++;
          _ticketController.clear();
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)?.wizardSaveFailed ??
                  'Could not save ticket. Try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rulesAsync = ref.watch(rulesEngineProvider);
    final tc = AppThemeColors.of(context);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: tc.bg,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PageHeader(tc: tc, l10n: l10n),
            Expanded(
              child: GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                behavior: HitTestBehavior.opaque,
                child: rulesAsync.when(
                  data: (rules) {
                    final uid = ref.watch(userIdProvider).asData?.value;
                    Dispute? liveDispute;
                    if (uid != null) {
                      final list =
                          ref.watch(disputesProvider(uid)).asData?.value;
                      if (list != null) {
                        for (final d in list) {
                          if (d.id == widget.disputeId) {
                            liveDispute = d;
                            break;
                          }
                        }
                      }
                    }
                    if (liveDispute != null && !_levelHydrated) {
                      final next = wizardLevelFromDispute(liveDispute);
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted || _levelHydrated) return;
                        setState(() {
                          _levelHydrated = true;
                          _currentLevel = next;
                        });
                      });
                    }
                    final steps = _buildSteps(rules, liveDispute);
                    return _StepperBody(
                      steps: steps,
                      currentLevel: _currentLevel,
                      saving: _saving,
                      ticketController: _ticketController,
                      onMarkFiled: _persistMarkFiled,
                      onFinish: () async {
                        final outcome = _currentLevel >= 2
                            ? 'ombudsman'
                            : 'escalate';
                        ref
                            .read(analyticsServiceProvider)
                            .logWizardCompleted(
                              outcome: outcome,
                              daysOpen: 0,
                              wasWon: false,
                            );
                        try {
                          final uid = await ref.read(
                            userIdProvider.future,
                          );
                          if (uid != null) {
                            final disputes = await ref.read(
                              disputesProvider(uid).future,
                            );
                            final d = disputes
                                .where((e) => e.id == widget.disputeId)
                                .firstOrNull;
                            if (d != null) {
                              await syncRemindersForDispute(ref, uid, d);
                            }
                          }
                        } catch (e) {
                          // Don't block navigation on reminder sync.
                        }
                        if (context.mounted) context.go(AppRoutes.reminders);
                      },
                    );
                  },
                  loading: () => const SkeletonList(itemCount: 4),
                  error: (e, _) => BrandedErrorBanner(
                    message: e.toString(),
                    onRetry: () => ref.invalidate(rulesEngineProvider),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_Step> _buildSteps(RulesEngine rules, Dispute? dispute) {
    final l10n = AppLocalizations.of(context);
    final l2Raw =
        'Dear NPCI Team,\n\nUTR: {UTR}\nAmount: Rs. {AMOUNT}\nDate: {TXN_DATE}\nVPA: {VPA}\n\n'
        'I have not received credit / refund and the bank has not resolved within 30 days.\n'
        'Please escalate this dispute.';
    final l3Raw =
        'Complaint against: {ENTITY_NAME} (Bank)\n'
        'Category: Deficiency in Service - failed transaction not reversed\n\n'
        'Facts:\n1. On {TXN_DATE}, Rs. {AMOUNT} debited, beneficiary not credited.\n'
        '2. Complained on {COMPLAINT_DATE} (ticket {TICKET_NO}).\n'
        '3. No reply for 30 days.\n'
        '4. Under RBI TAT Harmonisation circular, entitled to reversal + Rs.100/day.\n\n'
        'Relief: Refund Rs. {AMOUNT} + compensation Rs. {COMPENSATION_DUE}.';
    return [
      _Step(
        title: l10n?.wizardLevel1Title ?? 'Level 1 - UPI app / bank',
        body: l10n?.wizardLevel1Body ??
            'File complaint in your UPI app (GPay/PhonePe/Paytm) or your bank. '
                'Note the ticket number. Bank has up to 30 days to respond.',
        url: rules.officialLinks['upi_complaints'],
        phone: '14448',
        complaintText: null,
        documents: [
          l10n?.wizardDocUtrTxnId ?? 'UTR / Transaction ID',
          l10n?.wizardDocAmount ?? 'Amount',
          l10n?.wizardDocDate ?? 'Date',
          l10n?.wizardDocVpa ?? 'VPA',
          l10n?.wizardDocBankStatement ?? 'Bank statement screenshot',
        ],
      ),
      _Step(
        title: l10n?.wizardLevel2Title ?? 'Level 2 - NPCI portal',
        body: l10n?.wizardLevel2Body ??
            'Visit NPCI Dispute Redressal portal. Needs UTR, amount, date, VPA, bank statement.',
        url: rules.officialLinks['upi_complaints'],
        phone: null,
        complaintText: filledBody(l2Raw, dispute),
        documents: [
          'UTR',
          l10n?.wizardDocAmount ?? 'Amount',
          l10n?.wizardDocDate ?? 'Date',
          l10n?.wizardDocVpa ?? 'VPA',
          l10n?.wizardDocBankStatementShort ?? 'Bank statement',
        ],
      ),
      _Step(
        title: l10n?.wizardLevel3Title ?? 'Level 3 - RBI Ombudsman',
        body: l10n?.wizardLevel3Body ??
            'File at cms.rbi.org.in within 90 days of bank response window. '
                'Category: Deficiency in Service. Free.',
        url: rules.officialLinks['rbi_cms'],
        phone: '14448',
        complaintText: filledBody(l3Raw, dispute),
        documents: [
          l10n?.wizardDocTransactionProof ?? 'Transaction proof',
          l10n?.wizardDocComplaintAck ?? 'Complaint acknowledgement',
          l10n?.wizardDocBankReply ?? 'Bank reply (if any)',
        ],
      ),
    ];
  }
}

class _PageHeader extends StatelessWidget {
  final AppThemeColors tc;
  final AppLocalizations? l10n;
  const _PageHeader({required this.tc, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: tc.textPrimary),
            onPressed: () => context.pop(),
          ),
          Expanded(
            child: Text(
              l10n?.wizardTitle ?? 'Escalation steps',
              style: TextStyle(
                fontFamily: AppTypography.family,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: tc.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepperBody extends StatelessWidget {
  final List<_Step> steps;
  final int currentLevel;
  final bool saving;
  final TextEditingController ticketController;
  final VoidCallback onMarkFiled;
  final VoidCallback onFinish;

  const _StepperBody({
    required this.steps,
    required this.currentLevel,
    required this.saving,
    required this.ticketController,
    required this.onMarkFiled,
    required this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        _StepIndicator(
          count: steps.length,
          current: currentLevel,
          tc: tc,
        ),
        const SizedBox(height: 16),
        for (int i = 0; i < steps.length; i++) ...[
          if (i == currentLevel)
            _ActiveStepCard(
              step: steps[i],
              index: i,
              saving: saving,
              ticketController: ticketController,
              onMarkFiled: onMarkFiled,
              onFinish: onFinish,
              l10n: l10n,
            )
          else if (i < currentLevel)
            _CompletedStepTile(
              title: steps[i].title,
              index: i,
              tc: tc,
            )
          else
            _FutureStepTile(
              title: steps[i].title,
              index: i,
              tc: tc,
            ),
          if (i < steps.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final int count;
  final int current;
  final AppThemeColors tc;
  const _StepIndicator({
    required this.count,
    required this.current,
    required this.tc,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < count; i++) ...[
          Expanded(
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: i <= current ? tc.ctaBackground : tc.surfaceAlt,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          if (i < count - 1) const SizedBox(width: 4),
        ],
      ],
    );
  }
}

class _CompletedStepTile extends StatelessWidget {
  final String title;
  final int index;
  final AppThemeColors tc;
  const _CompletedStepTile({
    required this.title,
    required this.index,
    required this.tc,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: tc.surface,
        border: Border.all(color: tc.divider),
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tc.accentSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, size: 14, color: AppColors.success),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontFamily: AppTypography.family,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: tc.textSecondary,
                decoration: TextDecoration.lineThrough,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FutureStepTile extends StatelessWidget {
  final String title;
  final int index;
  final AppThemeColors tc;
  const _FutureStepTile({
    required this.title,
    required this.index,
    required this.tc,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: tc.surface,
        border: Border.all(color: tc.divider),
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tc.surfaceAlt,
              shape: BoxShape.circle,
            ),
            child: Text(
              '${index + 1}',
              style: TextStyle(
                fontFamily: AppTypography.family,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: tc.textTertiary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontFamily: AppTypography.family,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: tc.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveStepCard extends StatelessWidget {
  final _Step step;
  final int index;
  final bool saving;
  final TextEditingController ticketController;
  final VoidCallback onMarkFiled;
  final VoidCallback onFinish;
  final AppLocalizations? l10n;
  const _ActiveStepCard({
    required this.step,
    required this.index,
    required this.saving,
    required this.ticketController,
    required this.onMarkFiled,
    required this.onFinish,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tc.surface,
        border: Border.all(color: tc.divider),
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tc.ctaBackground,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: tc.ctaForeground,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  step.title,
                  style: TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: tc.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            step.body,
            style: TextStyle(
              fontSize: 13,
              color: tc.textSecondary,
              height: 1.5,
            ),
          ),
          if (step.complaintText != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: tc.surfaceAlt,
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              child: Text(
                step.complaintText!,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  height: 1.5,
                  color: tc.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Clipboard.setData(
                  ClipboardData(text: step.complaintText!),
                ),
                icon: const Icon(Icons.copy, size: 14),
                label: Text(
                  l10n?.wizardCopyComplaint ?? 'Copy complaint text',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],
          if (step.url != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => launchExternalUrl(step.url!),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: Text(
                  l10n?.wizardOpenPortal ?? 'Open portal',
                  style: TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
          if (step.phone != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => launchPhone(step.phone!),
                icon: const Icon(Icons.phone, size: 14),
                label: Text(
                  '${l10n?.wizardCallPrefix ?? 'Call'} ${step.phone}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],
          if (step.documents.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              l10n?.wizardDocuments ?? 'Documents needed',
              style: TextStyle(
                fontFamily: AppTypography.family,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
                color: tc.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            ...step.documents.map(
              (d) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline,
                        size: 14, color: tc.ctaBackground),
                    const SizedBox(width: 8),
                    Text(d,
                        style: TextStyle(
                            fontSize: 12, color: tc.textPrimary)),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          TextFormField(
            controller: ticketController,
            decoration: InputDecoration(
              labelText:
                  l10n?.wizardTicketNumber ?? 'Ticket / complaint number',
              filled: true,
              fillColor: tc.surfaceAlt,
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.sm),
                borderSide: BorderSide(color: tc.divider),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.sm),
                borderSide: BorderSide(color: tc.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.sm),
                borderSide: BorderSide(color: tc.ctaBackground, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: OutlinedButton(
                    onPressed: saving ? null : onMarkFiled,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: tc.ctaBackground,
                      side: BorderSide(color: tc.divider),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.md),
                      ),
                    ),
                    child: Text(
                      l10n?.wizardMarkFiled ?? 'Mark as filed',
                      style: TextStyle(
                        fontFamily: AppTypography.family,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: FilledButton(
                    onPressed: onFinish,
                    style: FilledButton.styleFrom(
                      backgroundColor: tc.ctaBackground,
                      foregroundColor: tc.ctaForeground,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.md),
                      ),
                    ),
                    child: Text(
                      l10n?.wizardDoneSetReminder ?? 'Done — set reminder',
                      style: TextStyle(
                        fontFamily: AppTypography.family,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
