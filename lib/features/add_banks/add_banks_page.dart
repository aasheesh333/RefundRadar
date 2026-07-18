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

class AddBanksPage extends ConsumerStatefulWidget {
  const AddBanksPage({super.key});

  static const _kPrefKey = 'onboard.banks';

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
    await _persist();
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
            _PageHeader(
              tc: tc,
              l10n: l10n,
              onBack: () => context.go(AppRoutes.onboardSms),
              onSkip: _finish,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: _SearchBar(
                isSearching: _isSearching,
                query: _query,
                tc: tc,
                l10n: l10n,
                onChanged: (v) => setState(() => _query = v),
                onStartSearch: () => setState(() => _isSearching = true),
                onClear: () => setState(() {
                  _isSearching = false;
                  _query = '';
                }),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: banks.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _BankRow(
                  bank: banks[i],
                  selected: _selected.contains(banks[i].id),
                  onTap: () => _toggle(banks[i].id),
                ),
              ),
            ),
            _Footer(
              selected: _selected.length,
              tc: tc,
              l10n: l10n,
              onFinish: _finish,
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
  final VoidCallback onBack;
  final VoidCallback onSkip;
  const _PageHeader({
    required this.tc,
    required this.l10n,
    required this.onBack,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: tc.textPrimary),
            onPressed: onBack,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n?.addBanksTitle ?? 'Add your banks',
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
                  l10n?.addBanksSubtitle ??
                      'Pick accounts where Refund Radar should auto-fill the nodal officer details.',
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
          TextButton(
            onPressed: onSkip,
            child: Text(
              l10n?.addBanksSkip ?? 'Skip',
              style: TextStyle(
                fontFamily: AppTypography.family,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: tc.ctaBackground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final bool isSearching;
  final String query;
  final AppThemeColors tc;
  final AppLocalizations? l10n;
  final ValueChanged<String> onChanged;
  final VoidCallback onStartSearch;
  final VoidCallback onClear;
  const _SearchBar({
    required this.isSearching,
    required this.query,
    required this.tc,
    required this.l10n,
    required this.onChanged,
    required this.onStartSearch,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    if (isSearching) {
      return TextField(
        autofocus: true,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: l10n?.addBanksSearchHint ?? 'Search your bank',
          hintStyle: TextStyle(
            fontFamily: AppTypography.family,
            fontSize: 13,
            color: tc.textSecondary,
          ),
          prefixIcon: Icon(Icons.search, size: 18, color: tc.textSecondary),
          filled: true,
          fillColor: tc.surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
            borderSide: BorderSide(color: tc.divider),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
            borderSide: BorderSide(color: tc.divider),
          ),
          suffixIcon: IconButton(
            icon: Icon(Icons.close, size: 16, color: tc.textSecondary),
            onPressed: onClear,
          ),
        ),
      );
    }
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton.icon(
        onPressed: onStartSearch,
        icon: Icon(Icons.search, size: 16, color: tc.ctaBackground),
        label: Text(
          l10n?.addBanksSearchLabel ?? 'Search',
          style: TextStyle(
            fontFamily: AppTypography.family,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: tc.ctaBackground,
          ),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  final int selected;
  final AppThemeColors tc;
  final AppLocalizations? l10n;
  final VoidCallback onFinish;
  const _Footer({
    required this.selected,
    required this.tc,
    required this.l10n,
    required this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
                selected == 0
                    ? (l10n?.addBanksSelectAtLeast ??
                        'Select at least one bank')
                    : (l10n?.addBanksContinueN(selected) ??
                        '$selected selected'),
                style: TextStyle(
                  fontFamily: AppTypography.family,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color:
                      selected == 0 ? tc.textTertiary : tc.ctaBackground,
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              height: 46,
              child: FilledButton(
                onPressed: selected == 0 ? null : onFinish,
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
                  l10n?.disputeTypeContinue ?? 'Continue',
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
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(
              color: selected ? tc.ctaBackground : tc.divider,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: tc.surfaceAlt,
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                child: Center(
                  child: Text(
                    _initials,
                    style: TextStyle(
                      fontFamily: AppTypography.family,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: tc.ctaBackground,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bank.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTypography.family,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: tc.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      nodalEmail ?? 'Dispute handling per RBI rules',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                            size: 12, color: tc.ctaForeground),
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
