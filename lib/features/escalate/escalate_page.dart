import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:refund_radar/core/providers/auth_provider.dart';
import 'package:refund_radar/core/providers/dispute_provider.dart';
import 'package:refund_radar/core/theme/app_tokens.dart';
import 'package:refund_radar/data/models/dispute.dart';
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
    final uid = ref.watch(userIdProvider).asData?.value;
    if (uid == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final disputesAsync = ref.watch(disputesProvider(uid));
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: SafeArea(
        child: disputesAsync.when(
          data: (disputes) {
            final dispute = disputes.firstWhere(
              (d) => d.id == widget.disputeId,
              orElse: () => Dispute(
                id: widget.disputeId,
                type: DisputeType.upiP2p,
                amount: 0,
                txnDate: DateTime.now(),
                txnId: '',
                createdAt: DateTime.now(),
              ),
            );
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
              AppBackButton(size: 36, onTap: () => context.pop()),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Escalate',
                      style: TextStyle(
                        fontFamily: AppTypography.family,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Nodal Officer · ${dispute.entityName ?? "your bank"}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondaryLight,
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
                    color: AppColors.alertSoft,
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
                      '${CompensationCalculator.formatIndian(refund)} refund + ${CompensationCalculator.formatIndian(comp.compensationDue)} comp (${comp.daysElapsed} days × ₹100/day)',
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
                label: 'SEND TO',
                children: [
                  _RecipientRow(
                    emojiTile: '🎯',
                    bgTileColor: AppColors.alertSoft,
                    title: 'Nodal Officer',
                    detail:
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
                          color: AppColors.surfaceAltLight,
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: const Center(
                            child: Text('✉',
                                style: TextStyle(fontSize: 13))),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'CC RBI Ombudsman',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: ccOmbudsman
                                ? AppColors.textPrimaryLight
                                : AppColors.textSecondaryLight,
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
                label: 'EMAIL PREVIEW',
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAltLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Subject: Escalation — UTR ${dispute.txnId}',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimaryLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Dear Nodal Officer,',
                    style: const TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        color: AppColors.textSecondaryLight),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _emailBody(),
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: AppColors.textSecondaryLight,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '[auto-drafted, tap to edit]',
                    style: TextStyle(
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                      color: AppColors.textTertiaryLight,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Row(
                    children: [
                      Text('✓',
                          style: TextStyle(
                              fontSize: 10, color: AppColors.accent)),
                      SizedBox(width: 6),
                      Text(
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
                    color: AppColors.alertSoft,
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
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimaryLight,
                              height: 1.4,
                            ),
                            children: [
                              const TextSpan(text: 'Send within '),
                              const TextSpan(
                                text: '24 hours',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700),
                              ),
                              TextSpan(
                                text:
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
          decoration: const BoxDecoration(
            color: AppColors.surfaceLight,
            border: Border(
              top: BorderSide(color: AppColors.dividerLight, width: 1),
            ),
          ),
          child: Row(
            children: [
              _FooterButton(
                label: 'Edit',
                color: AppColors.surfaceAltLight,
                textColor: AppColors.primary,
                onTap: () => _copyEmail(context),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _FooterButton(
                  label: 'Send escalation →',
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

  Widget _card({required String label, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        border: Border.all(color: AppColors.dividerLight, width: 1),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: AppColors.textSecondaryLight,
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
      const SnackBar(content: Text('Email copied to clipboard')),
    );
  }

  void _sendEmail(BuildContext context) {
    final body = Uri.encodeComponent(_emailBody());
    final subject =
        Uri.encodeComponent('Escalation — UTR ${dispute.txnId}');
    final url =
        'mailto:${_nodalEmail(dispute)}?subject=$subject&body=$body';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Drafted — open your mail app: $url')),
    );
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
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimaryLight,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                detail,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondaryLight,
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
