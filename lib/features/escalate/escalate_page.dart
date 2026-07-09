import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:refund_radar/core/providers/auth_provider.dart';
import 'package:refund_radar/core/providers/dispute_provider.dart';
import 'package:refund_radar/core/theme/app_theme_colors.dart';
import 'package:refund_radar/core/theme/app_tokens.dart';
import 'package:refund_radar/core/utils/url_launcher_helper.dart';
import 'package:refund_radar/data/models/dispute.dart';
import 'package:refund_radar/l10n/app_localizations.dart';
import 'package:refund_radar/services/compensation_calculator.dart';
import 'package:refund_radar/shared/widgets/app_back_button.dart';
import 'package:refund_radar/shared/widgets/branded_error_banner.dart';
import 'package:refund_radar/shared/widgets/toggle_switch.dart';

/// Escalate page — mockup Screen 8. Dark green hero with "Maximum penalty
/// you can claim" → ₹{refund+comp}, send-to list with selected Nodal Officer
/// + toggleable "CC RBI Ombudsman", auto-drafted email preview, sticky
/// footer with Edit + "Send escalation →".
class EscalatePage extends ConsumerStatefulWidget {
  final String disputeId;
  const EscalatePage({super.key, required this.disputeId});

  @override
  ConsumerState<EscalatePage> createState() => _EscalatePageState();
}

class _EscalatePageState extends ConsumerState<EscalatePage> {
  bool _ccOmbudsman = true;

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    final uid = ref.watch(userIdProvider).asData?.value;
    if (uid == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final disputesAsync = ref.watch(disputesProvider(uid));
    return Scaffold(
      backgroundColor: tc.bg,
      body: SafeArea(
        child: disputesAsync.when(
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
            return _Body(
              dispute: dispute,
              ccOmbudsman: _ccOmbudsman,
              onToggleCc: (v) => setState(() => _ccOmbudsman = v),
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
          error: (e, _) => BrandedErrorBanner(
            message: e.toString(),
            onRetry: () => ref.invalidate(disputesProvider(uid)),
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final Dispute dispute;
  final bool ccOmbudsman;
  final ValueChanged<bool> onToggleCc;
  const _Body({
    required this.dispute,
    required this.ccOmbudsman,
    required this.onToggleCc,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tc = AppThemeColors.of(context);
    final comp = CompensationCalculator.compute(dispute);
    final refund = dispute.amount;
    final maxClaim = refund + comp.compensationDue;
    final deadlineMissed = comp.isExpired;

    return Column(
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
                      l10n?.escalateAppBarTitle ?? 'Escalate',
                      style: TextStyle(
                        fontFamily: AppTypography.family,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: tc.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '${l10n?.escalateNodalOfficer ?? 'Nodal Officer'} · ${dispute.entityName ?? "your bank"}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: tc.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (deadlineMissed)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: tc.alertSoft,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: const Text(
                    '⚠ T+5 missed',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.alert,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
            children: [
              // max-claim hero
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.all(Radius.circular(14)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'MAXIMUM PENALTY YOU CAN CLAIM',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                        color: Color(0x99FFFFFF),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      CompensationCalculator.formatIndian(maxClaim),
                      style: const TextStyle(
                        fontFamily: AppTypography.family,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        height: 1,
                        color: Colors.white,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      refund == 0
                          ? 'No transaction amount on this dispute'
                          : (l10n?.escalateRefundPlusComp(
                                  CompensationCalculator.formatIndian(refund),
                                  CompensationCalculator.formatIndian(
                                      comp.compensationDue),
                                  comp.daysElapsed) ??
                              '${CompensationCalculator.formatIndian(refund)} refund + ${CompensationCalculator.formatIndian(comp.compensationDue)} comp (${comp.daysElapsed} days × ₹100/day)'),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xB3FFFFFF),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // send-to card
              _card(
                context,
                label: l10n?.escalateSendTo ?? 'SEND TO',
                children: [
                  _RecipientRow(
                    emojiTile: '🎯',
                    bgTileColor: tc.alertSoft,
                    title: l10n?.escalateNodalOfficer ?? 'Nodal Officer',
                    detail: l10n?.escalateSlaDays(_nodalEmail(dispute)) ??
                        '${_nodalEmail(dispute)} · SLA 10d',
                    selected: true,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: tc.surfaceAlt,
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: const Center(
                            child: Text('✉',
                                style: TextStyle(fontSize: 13))),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          l10n?.escalateCcOmbudsman ?? 'CC RBI Ombudsman',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: ccOmbudsman
                                ? tc.textPrimary
                                : tc.textSecondary,
                          ),
                        ),
                      ),
                      ToggleSwitch(
                        value: ccOmbudsman,
                        onChanged: onToggleCc,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // email preview card
              _card(
                context,
                label: l10n?.escalateEmailPreview ?? 'EMAIL PREVIEW',
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: tc.surfaceAlt,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      l10n?.escalateEmailSubject(dispute.txnId) ??
                          'Subject: Escalation — UTR ${dispute.txnId}',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: tc.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'TO: ${_nodalEmail(dispute)}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: tc.textPrimary,
                    ),
                  ),
                  if (ccOmbudsman)
                    Text(
                      'CC: crpc@rbi.org.in',
                      style: TextStyle(
                        fontSize: 11,
                        color: tc.textSecondary,
                      ),
                    ),
                  const SizedBox(height: 10),
                  Text(
                    l10n?.escalateEmailGreeting ?? 'Dear Nodal Officer,',
                    style: TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        color: tc.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _emailBody(),
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: tc.textSecondary,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n?.escalateEmailAutoDrafted ?? '[auto-drafted, tap to edit]',
                    style: TextStyle(
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                      color: tc.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('✓',
                          style: TextStyle(
                              fontSize: 10, color: AppColors.accent)),
                      const SizedBox(width: 6),
                      Text(
                        l10n?.escalateStandardsCompliant ??
                            'Standards-compliant · view source',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accent,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // amber callout
              if (deadlineMissed)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: tc.alertSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('⚠',
                          style:
                              TextStyle(fontSize: 13, color: AppColors.alert)),
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
                              TextSpan(text: l10n?.escalateSendWithinPrefix ?? 'Send within '),
                              TextSpan(
                                text: l10n?.escalateSendWithin24h ?? '24 hours',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700),
                              ),
                              TextSpan(
                                text: l10n?.escalateSendWithinSuffix(
                                    CompensationCalculator.formatIndian(comp.compensationDue)) ??
                                    ' to claim full ${CompensationCalculator.formatIndian(comp.compensationDue)} comp retroactively.',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        // sticky footer
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          decoration: BoxDecoration(
            color: tc.surface,
            border: Border(
              top: BorderSide(color: tc.divider, width: 1),
            ),
          ),
          child: Row(
            children: [
              _FooterButton(
                label: l10n?.escalateEdit ?? 'Edit',
                color: tc.surfaceAlt,
                textColor:
                    tc.isDark ? AppColors.accent : AppColors.primary,
                onTap: () => _copyEmail(context),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _FooterButton(
                  label: l10n?.escalateSend ?? 'Send escalation →',
                  color: AppColors.primary,
                  textColor: Colors.white,
                  elevation: true,
                  onTap: () => _sendEmail(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _card(BuildContext context, {required String label, required List<Widget> children}) {
    final tc = AppThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tc.surface,
        border: Border.all(color: tc.divider, width: 1),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: tc.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  String _nodalEmail(Dispute d) {
    final bank = (d.entityName ?? 'bank').toLowerCase();
    if (bank.contains('hdfc')) return 'nodal.officer@hdfcbank.net';
    if (bank.contains('icici')) return 'nodal.officer@icicibank.com';
    if (bank.contains('axis')) return 'nodal.officer@axisbank.com';
    if (bank.contains('sbi')) return 'nodal.officer@sbi.co.in';
    return 'nodal.officer@yourbank.in';
  }

  String _emailBody() {
    return 'I am writing to escalate a refund dispute under RBI Master Direction '
        'DPSS.CO.PD.No.629 — failed transaction UTR ${dispute.txnId} for '
        '${CompensationCalculator.formatIndian(dispute.amount)} on '
        '${dispute.txnDate.day} ${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][dispute.txnDate.month - 1]} '
        'remains unresolved past T+${dispute.type.tatDays ?? 5}. I request '
        'immediate reversal plus ₹100/day compensation…';
  }

  void _copyEmail(BuildContext context) {
    final body =
        'Subject: Escalation — UTR ${dispute.txnId}\n\n${_emailBody()}';
    Clipboard.setData(ClipboardData(text: body));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)?.escalateCopiedToClipboard ?? 'Email copied to clipboard')),
    );
  }

  Future<void> _sendEmail(BuildContext context) async {
    final subject = 'Escalation — UTR ${dispute.txnId}';
    final body = _emailBody();
    final to = _nodalEmail(dispute);
    final cc = ccOmbudsman ? 'crpc@rbi.org.in' : null;
    final ok = await launchEmail(to, subject: subject, body: body, cc: cc);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? (AppLocalizations.of(context)?.escalateDrafted(to) ??
                  'Opening mail app…')
              : (AppLocalizations.of(context)?.escalateCopiedToClipboard ??
                  'Could not open mail app — email copied instead.'),
        ),
      ),
    );
    if (!ok) {
      await Clipboard.setData(ClipboardData(
        text: 'To: $to\n${cc != null ? 'CC: $cc\n' : ''}Subject: $subject\n\n$body',
      ));
    }
  }
}

class _RecipientRow extends StatelessWidget {
  final String emojiTile;
  final Color bgTileColor;
  final String title;
  final String detail;
  final bool selected;
  const _RecipientRow({
    required this.emojiTile,
    required this.bgTileColor,
    required this.title,
    required this.detail,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: bgTileColor,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Center(
              child: Text(emojiTile, style: const TextStyle(fontSize: 13))),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: tc.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                detail,
                style: TextStyle(
                  fontSize: 10,
                  color: tc.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (selected)
          const Text('✓',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent)),
      ],
    );
  }
}

class _FooterButton extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;
  final bool elevation;
  final VoidCallback onTap;
  const _FooterButton({
    required this.label,
    required this.color,
    required this.textColor,
    this.elevation = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(AppRadii.md),
      elevation: elevation ? 4 : 0,
      shadowColor: elevation ? const Color(0x1F0B3D2E) : Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.md),
        onTap: onTap,
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppTypography.family,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}

/// Re-export so the analyzer keeps the import used (used by router).
class EscalatePageRouteArg {
  final String disputeId;
  const EscalatePageRouteArg(this.disputeId);
}
