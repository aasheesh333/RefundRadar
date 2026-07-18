import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:refund_radar/core/router/app_routes.dart';
import 'package:refund_radar/core/theme/app_tokens.dart';
import 'package:refund_radar/core/theme/app_theme_colors.dart';
import 'package:refund_radar/data/extensions/dispute_type_display.dart';
import 'package:refund_radar/data/models/dispute.dart';
import 'package:refund_radar/l10n/app_localizations.dart';

class DisputeTypePage extends StatefulWidget {
  const DisputeTypePage({super.key});
  @override
  State<DisputeTypePage> createState() => _DisputeTypePageState();
}

class _DisputeTypePageState extends State<DisputeTypePage> {
  DisputeType? _selected;

  static const _order = [
    DisputeType.upiP2p,
    DisputeType.upiP2m,
    DisputeType.atm,
    DisputeType.fastag,
    DisputeType.imps,
    DisputeType.bankCharge,
    DisputeType.wrongTransfer,
  ];

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: tc.bg,
      body: SafeArea(
        child: Column(
          children: [
            _PageHeader(tc: tc, l10n: l10n),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l10n?.disputeTypeChooseCategory ??
                      'Choose dispute category',
                  style: TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: tc.textSecondary,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: _order.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) => _Row(
                  type: _order[i],
                  selected: _selected == _order[i],
                  onTap: () => setState(() => _selected = _order[i]),
                ),
              ),
            ),
            _Footer(
              selected: _selected,
              tc: tc,
              l10n: l10n,
              onContinue: () => context.push(
                AppRoutes.disputesFormWithParams(
                  type: _selected!.id,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  final AppThemeColors tc;
  final AppLocalizations? l10n;
  const _PageHeader({required this.tc, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: tc.textPrimary),
            onPressed: () => context.pop(),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n?.disputeTypeWhatHappened ?? 'What happened?',
                  style: TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: tc.textPrimary,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  l10n?.disputeTypeStep1Of4 ?? 'Step 1 of 2',
                  style: TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: tc.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  final DisputeType? selected;
  final AppThemeColors tc;
  final AppLocalizations? l10n;
  final VoidCallback onContinue;
  const _Footer({
    required this.selected,
    required this.tc,
    required this.l10n,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: tc.surface,
        border: Border(top: BorderSide(color: tc.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Text(
                selected == null
                    ? (l10n?.disputeTypeSelectedDash ?? 'Selected: —')
                    : (l10n?.disputeTypeSelectedName(
                            selected!.localizedName(
                                AppLocalizations.of(context)),
                          ) ??
                        'Selected: ${selected!.localizedName(AppLocalizations.of(context))}'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppTypography.family,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color:
                      selected == null ? tc.textTertiary : tc.ctaBackground,
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              height: 46,
              child: FilledButton(
                onPressed: selected == null ? null : onContinue,
                style: FilledButton.styleFrom(
                  backgroundColor: tc.ctaBackground,
                  foregroundColor: tc.ctaForeground,
                  disabledBackgroundColor: tc.divider,
                  disabledForegroundColor: tc.textSecondary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                ),
                child: Text(
                  AppLocalizations.of(context)?.disputeTypeContinue ??
                      'Continue →',
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
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.type, required this.selected, required this.onTap});

  final DisputeType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    final l10n = AppLocalizations.of(context);
    final comp = type.localizedCompensation(l10n);
    return Material(
      color: tc.surface,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: tc.surface,
            border: Border.all(
              color: selected ? tc.ctaBackground : tc.divider,
              width: selected ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(AppRadii.lg),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: type.softColorFor(tc),
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                child: Center(
                  child:
                      Text(type.emoji, style: const TextStyle(fontSize: 20)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type.localizedName(l10n),
                      style: TextStyle(
                        fontFamily: AppTypography.family,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: tc.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      type.localizedSubtitle(l10n),
                      style: TextStyle(
                        fontFamily: AppTypography.family,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: tc.textSecondary,
                      ),
                    ),
                    if (comp != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: tc.accentSoft,
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                        ),
                        child: Text(
                          comp,
                          style: TextStyle(
                            fontFamily: AppTypography.family,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accent,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: selected ? tc.ctaBackground : tc.surface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? tc.ctaBackground : tc.divider,
                    width: 1.5,
                  ),
                ),
                child: selected
                    ? Center(
                        child: Icon(Icons.check,
                            size: 13, color: tc.ctaForeground),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
