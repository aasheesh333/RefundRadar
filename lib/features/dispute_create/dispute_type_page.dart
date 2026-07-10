import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_theme_colors.dart';
import '../../data/extensions/dispute_type_display.dart';
import '../../data/models/dispute.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/app_back_button.dart';
import '../../shared/widgets/onboarding_step_header.dart';

/// Dispute Type Selector — vertical list of selectable cards with sticky
/// "Continue" footer.
class DisputeTypePage extends StatefulWidget {
  const DisputeTypePage({super.key});
  @override
  State<DisputeTypePage> createState() => _DisputeTypePageState();
}

class _DisputeTypePageState extends State<DisputeTypePage> {
  DisputeType? _selected;

  /// User-facing dispute types (UPI P2P + P2M, ATM, FASTag, IMPS, bank charge, wrong transfer).
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
    return Scaffold(
      backgroundColor: tc.bg,
      body: SafeArea(
        child: Column(
          children: [
            // top bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
              child: Row(
                children: [
                  const AppBackButton(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OnboardingStepHeader(
                      step: 'Step 1 of 4',
                      title: 'What happened?',
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Choose dispute category',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: tc.textSecondary,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                itemCount: _order.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) => _Row(
                  type: _order[i],
                  selected: _selected == _order[i],
                  onTap: () => setState(() => _selected = _order[i]),
                ),
              ),
            ),
            // sticky footer — Column (not Row+infinite min button) so the
            // selected label never collapses to one-char-wide vertical text.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
              decoration: BoxDecoration(
                color: tc.surface,
                border: Border(
                  top: BorderSide(color: tc.divider, width: 1),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _selected == null
                        ? 'Selected: —'
                        : 'Selected: ${_selected!.localizedName(AppLocalizations.of(context))}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _selected == null
                          ? tc.textTertiary
                          : AppColors.accent,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 52,
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _selected == null
                          ? null
                          : () => context.push(
                                '/disputes/form?type=${_selected!.id}'),
                      style: FilledButton.styleFrom(
                        backgroundColor: tc.ctaBackground,
                        foregroundColor: tc.ctaForeground,
                        disabledBackgroundColor: tc.surfaceAlt,
                        disabledForegroundColor: tc.textTertiary,
                        minimumSize: const Size(0, 52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadii.md),
                        ),
                      ),
                      child: Text(AppLocalizations.of(context)?.disputeTypeContinue ??
                          'Continue →'),
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
}

class _Row extends StatelessWidget {
  const _Row({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final DisputeType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    final l10n = AppLocalizations.of(context);
    final comp = type.localizedCompensation(l10n);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: tc.surface,
          border: Border.all(
            color: selected ? AppColors.primary : tc.divider,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: type.softColorFor(tc),
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              child: Center(child: Text(type.emoji, style: const TextStyle(fontSize: 22))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    type.localizedName(l10n),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: tc.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    type.localizedSubtitle(l10n),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: tc.textSecondary,
                    ),
                  ),
                  if (comp != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      comp,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            selected
                ? Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 14,
                      color: Colors.white,
                    ),
                  )
                : Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: tc.divider,
                        width: 2,
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
