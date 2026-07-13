import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:refund_radar/core/router/app_routes.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:refund_radar/core/providers/app_state_provider.dart';
import 'package:refund_radar/core/theme/app_tokens.dart';
import 'package:refund_radar/core/theme/app_theme_colors.dart';
import 'package:refund_radar/data/constants/bank_catalog.dart';
import 'package:refund_radar/l10n/app_localizations.dart';
import 'package:refund_radar/shared/widgets/onboarding_step_header.dart';

/// Onboarding Add-banks page (mockup Screen 13).
/// Lets the user pick their banks: we remember the selection in
/// SharedPreferences (`onboard.banks`) so the dispute-form bank picker can
/// show those banks first. Nodal-officer email routing still falls back to
/// RulesEngine.escalationTargets at dispute time.
class AddBanksPage extends ConsumerStatefulWidget {
  const AddBanksPage({super.key});

  static const _kPrefKey = 'onboard.banks';

  /// Read the saved bank IDs back as a `List<String>`; empty list if none.
  static Future<List<String>> loadSelectedBanks() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getStringList(_kPrefKey) ?? const [];
  }

  @override
  ConsumerState<AddBanksPage> createState() => _AddBanksPageState();
}

class _AddBanksPageState extends ConsumerState<AddBanksPage> {
  final Set<String> _selected = {};
  bool _isSearching = false;
  String _query = '';
  Timer? _persistDebounce;

  @override
  void dispose() {
    _persistDebounce?.cancel();
    super.dispose();
  }

  void _toggle(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
    _persistDebounce?.cancel();
    _persistDebounce = Timer(const Duration(milliseconds: 250), _persist);
  }

  Future<void> _persist() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setStringList(AddBanksPage._kPrefKey, _selected.toList());
  }

  List<BankEntry> get _filteredBanks {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return BankCatalog.banks;
    return BankCatalog.banks
        .where((b) =>
            b.name.toLowerCase().contains(q) ||
            b.short.toLowerCase().contains(q))
        .toList();
  }

  void _finish() async {
    _persist();
    // Mark onboarding complete so the router redirect skips the slides on
    // every subsequent cold boot. Pass the live ref so the in-memory
    // provider flips immediately (router redirect reads it).
    await markOnboardingComplete(ref);
    if (mounted) context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final banks = _filteredBanks;
    final tc = AppThemeColors.of(context);
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: tc.bg,
      body: SafeArea(
        child: Column(
          children: [
            // header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(
                children: [
                  Material(
                    color: tc.surface,
                    shape: CircleBorder(
                      side: BorderSide(
                          color: tc.divider, width: 1),
                    ),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => context.go(AppRoutes.onboardSms),
                      child: SizedBox(
                        width: 36,
                        height: 36,
                        child: Center(
                          child: Icon(Icons.arrow_back,
                              size: 18, color: tc.textPrimary),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OnboardingStepHeader(
                      step: 'Setup',
                      title: l10n?.addBanksTitle ?? 'Add your banks',
                    ),
                  ),
                  GestureDetector(
                    onTap: _finish,
                    child: const Text(
                      'Skip',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                tc.surface,
                                tc.premiumGoldSoft,
                              ],
                              stops: const [0.0, 1.0],
                            ),
                            border: Border.all(
                                color: tc.divider, width: 1),
                          ),
                          child: const Center(
                            child: Text('🏦', style: TextStyle(fontSize: 30)),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tell us your banks',
                                style: TextStyle(
                                  fontFamily: AppTypography.family,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  height: 1.2,
                                  color: tc.textPrimary,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Pick accounts where Refund Radar should auto-fill the nodal officer details.',
                                style: TextStyle(
                                  fontSize: 11,
                                  height: 1.45,
                                  color: tc.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // search toggle
                    if (_isSearching)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TextField(
                          autofocus: true,
                          onChanged: (v) => setState(() => _query = v),
                          decoration: InputDecoration(
                            hintText: 'Search your bank',
                            hintStyle: TextStyle(
                                fontSize: 13,
                                color: tc.textSecondary),
                            prefixIcon: Icon(Icons.search,
                                size: 18,
                                color: tc.textSecondary),
                            filled: true,
                            fillColor: tc.surface,
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 12),
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadii.md),
                              borderSide: BorderSide(
                                  color: tc.divider, width: 1),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadii.md),
                              borderSide: BorderSide(
                                  color: tc.divider, width: 1),
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(Icons.close,
                                  size: 16,
                                  color: tc.textSecondary),
                              onPressed: () => setState(() {
                                _isSearching = false;
                                _query = '';
                              }),
                            ),
                          ),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () =>
                                setState(() => _isSearching = true),
                            icon: Icon(Icons.search,
                                size: 16,
                                color: tc.textSecondary),
                            label: Text(
                                l10n?.addBanksSearchLabel ?? 'Search',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: tc.textSecondary)),
                          ),
                        ),
                      ),
                    // bank list
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: banks.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: 8),
                      itemBuilder: (_, i) => _BankRow(
                        bank: banks[i],
                        selected: _selected.contains(banks[i].id),
                        onTap: () => _toggle(banks[i].id),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // sticky footer
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
              decoration: BoxDecoration(
                color: tc.surface,
                border: Border(
                  top: BorderSide(color: tc.divider, width: 1),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        onPressed: _selected.isEmpty ? null : _finish,
                        style: FilledButton.styleFrom(
                          backgroundColor: tc.ctaBackground,
                          foregroundColor: tc.ctaForeground,
                          disabledBackgroundColor:
                              tc.divider,
                          disabledForegroundColor: tc.textSecondary,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadii.sm),
                          ),
                        ),
                        child: Text(
                          _selected.isEmpty
                              ? 'Select at least one bank'
                              : 'Continue (${_selected.length} selected)',
                          style: const TextStyle(
                            fontFamily: AppTypography.family,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // 3-dot progress (3rd = filled/accent)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 8,
                          height: 8,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: tc.divider,
                              borderRadius:
                                  BorderRadius.all(Radius.circular(4)),
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        SizedBox(
                          width: 8,
                          height: 8,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: tc.divider,
                              borderRadius:
                                  BorderRadius.all(Radius.circular(4)),
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        const SizedBox(
                          width: 24,
                          height: 8,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              borderRadius:
                                  BorderRadius.all(Radius.circular(4)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BankRow extends StatelessWidget {
  final BankEntry bank;
  final bool selected;
  final VoidCallback onTap;
  const _BankRow({
    required this.bank,
    required this.selected,
    required this.onTap,
  });

  String get _initials {
    if (bank.short.length <= 2) return bank.short.toUpperCase();
    return bank.short.substring(0, 2).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final nodalEmail = BankCatalog.nodalEmailFor(bank.id);
    final tc = AppThemeColors.of(context);
    return Material(
      color: tc.surface,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(
              color: selected ? AppColors.primary : tc.divider,
              width: selected ? 2 : 1,
            ),
            boxShadow: AppShadows.card,
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: tc.surfaceAlt,
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                child: Center(
                  child: Text(
                    _initials,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bank.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: tc.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      nodalEmail ?? 'Dispute handling per RBI rules',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: tc.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary
                      : tc.surface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected
                        ? AppColors.primary
                        : tc.divider,
                    width: 2,
                  ),
                ),
                child: selected
                    ? const Center(
                        child: Icon(Icons.check,
                            size: 12, color: Colors.white),
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
