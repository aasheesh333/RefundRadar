import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

import 'package:refund_radar/core/providers/app_state_provider.dart';
import 'package:refund_radar/core/theme/app_theme_colors.dart';
import 'package:refund_radar/core/theme/app_tokens.dart';
import 'package:refund_radar/l10n/app_localizations.dart';
import 'package:refund_radar/services/analytics_service.dart';
import 'package:refund_radar/services/revenue_cat_service.dart';
import 'package:refund_radar/shared/widgets/branded_error_banner.dart';

class PaywallPage extends ConsumerStatefulWidget {
  final String returnPath;
  final String trigger;
  final String? templateId;
  final String? templateTitle;

  const PaywallPage({
    super.key,
    required this.returnPath,
    required this.trigger,
    this.templateId,
    this.templateTitle,
  });

  @override
  ConsumerState<PaywallPage> createState() => _PaywallPageState();
}

class _PaywallPageState extends ConsumerState<PaywallPage> {
  Offerings? _offerings;
  bool _loading = true;
  String? _error;
  String? _purchasingPackageId;

  @override
  void initState() {
    super.initState();
    _fetchOfferings();
    WidgetsBinding.instance.addPostFrameCallback((_) => _logView());
  }

  Future<void> _fetchOfferings() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final svc = ref.read(revenueCatServiceProvider);
      final offerings = await svc.fetchOfferings();
      if (!mounted) return;
      setState(() {
        _offerings = offerings;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      final msg = AppLocalizations.of(context)?.paywallCouldNotLoadPlans ??
          'Could not load plans. Tap retry.';
      setState(() {
        _error = msg;
        _loading = false;
      });
    }
  }

  void _logView() {
    final isPremium = ref.read(isPremiumProvider);
    ref.read(analyticsServiceProvider).logPaywallView(
          trigger: widget.trigger,
          isPremium: isPremium,
        );
  }

  Future<void> _buy(Package pkg) async {
    if (_purchasingPackageId != null) return;
    setState(() => _purchasingPackageId = pkg.identifier);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      final svc = ref.read(revenueCatServiceProvider);
      final ok = await svc.purchasePackage(pkg, source: 'paywall');
      if (!mounted) return;
      if (ok) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)?.paywallTitle ??
                  'Premium unlocked',
            ),
          ),
        );
        context.go(widget.returnPath);
      } else {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)?.errorGeneric ??
                  'Purchase did not complete.',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)?.errorGeneric ?? 'Purchase failed',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _purchasingPackageId = null);
    }
  }

  Future<void> _restore() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      final svc = ref.read(revenueCatServiceProvider);
      final ok = await svc.restorePurchases();
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? (l10n?.paywallRestored ?? 'Premium restored')
                : (l10n?.paywallRestoreFailedGeneric ??
                    'Could not restore purchases. Check your connection and try again.'),
          ),
        ),
      );
      if (ok) context.go(widget.returnPath);
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            l10n?.paywallRestoreFailedGeneric ??
                'Could not restore purchases. Check your connection and try again.',
          ),
        ),
      );
    }
  }

  String _headline() {
    final l10n = AppLocalizations.of(context);
    final title = widget.templateTitle;
    if (title != null && title.isNotEmpty) {
      return l10n?.paywallHeadlineTemplate(title) ??
          'Unlock "$title" and 50+ premium templates.';
    }
    return l10n?.paywallHeadline ??
        'Recover more. Unlimited disputes + 50+ templates.';
  }

  String _livePriceFor(Package p) {
    final priceString = p.storeProduct.priceString;
    try {
      final locale = Localizations.localeOf(context);
      final isIndianLocale =
          locale.countryCode == 'IN' || locale.languageCode == 'hi';
      if (isIndianLocale && !priceString.contains('₹')) {
        FirebaseCrashlytics.instance.log(
          'paywall: Indian locale but priceString="$priceString" '
          '(pkg=${p.identifier}, type=${p.packageType}) — Play account '
          'region may not match device locale.',
        );
      }
    } catch (_) {}
    return priceString;
  }

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: tc.bg,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(tc: tc, l10n: l10n, returnPath: widget.returnPath),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  const SizedBox(height: 8),
                  _HeroHeader(headline: _headline(), tc: tc),
                  const SizedBox(height: 24),
                  _buildPlansArea(),
                  const SizedBox(height: 24),
                  const _ComparisonTable(),
                  const SizedBox(height: 24),
                  _RestoreRow(
                    onRestore: _purchasingPackageId == null ? _restore : null,
                    onDismiss: () => context.go(widget.returnPath),
                    tc: tc,
                    l10n: l10n,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlansArea() {
    final tc = AppThemeColors.of(context);
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return BrandedErrorBanner(
        message: _error!,
        onRetry: _fetchOfferings,
      );
    }
    final packages = _offerings?.current?.availablePackages;
    if (packages == null || packages.isEmpty) {
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _PlanCard(
                  title:
                      AppLocalizations.of(context)?.paywallMonthlyTitle ??
                          'Monthly',
                  price: '₹99',
                  highlighted: false,
                  onTap: _purchasingPackageId == null
                      ? () => scaffoldMessenger.showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Purchase unavailable in this build. Once Play Store products are configured, tapping here will start the ₹99/month purchase.'),
                              duration: Duration(seconds: 4),
                            ),
                          )
                      : null,
                  loading: false,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PlanCard(
                  title:
                      AppLocalizations.of(context)?.paywallYearlyTitle ??
                          'Yearly',
                  price: '₹499',
                  highlighted: true,
                  badge: 'Save 58%',
                  onTap: _purchasingPackageId == null
                      ? () => scaffoldMessenger.showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Purchase unavailable in this build. Once Play Store products are configured, tapping here will start the ₹499/year purchase.'),
                              duration: Duration(seconds: 4),
                            ),
                          )
                      : null,
                  loading: false,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _PlanCard(
            title: AppLocalizations.of(context)?.paywallLifetimeTitle ??
                'Lifetime',
            price: '₹1,999',
            highlighted: false,
            fullWidth: true,
            onTap: _purchasingPackageId == null
                ? () => scaffoldMessenger.showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Purchase unavailable in this build. Once Play Store products are configured, tapping here will start the ₹1,999 one-time lifetime purchase.'),
                        duration: Duration(seconds: 4),
                      ),
                    )
                : null,
            loading: false,
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'Pricing in INR. Live purchases unlock once Google Play products are linked to RevenueCat.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTypography.family,
                fontSize: 11,
                color: tc.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      );
    }
    final sorted = [...packages]..sort((a, b) {
        int rank(Package p) => switch (p.packageType) {
              PackageType.monthly => 0,
              PackageType.annual => 1,
              PackageType.lifetime => 2,
              _ => 3,
            };
        return rank(a).compareTo(rank(b));
      });
    final monthly = sorted.firstWhere(
      (p) => p.packageType == PackageType.monthly,
      orElse: () => sorted.first,
    );
    Package? yearly;
    Package? lifetime;
    for (final p in sorted) {
      if (p.packageType == PackageType.annual) yearly = p;
      if (p.packageType == PackageType.lifetime) lifetime = p;
    }
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _PlanCard(
                title: monthly.storeProduct.title,
                price: _livePriceFor(monthly),
                highlighted: false,
                onTap: _purchasingPackageId == null
                    ? () => _buy(monthly)
                    : null,
                loading: _purchasingPackageId == monthly.identifier,
              ),
            ),
            if (yearly != null) ...[
              const SizedBox(width: 12),
              Expanded(
                child: Builder(builder: (_) {
                  final y = yearly!;
                  return _PlanCard(
                    title: y.storeProduct.title,
                    price: _livePriceFor(y),
                    highlighted: true,
                    badge: 'Save 58%',
                    onTap: _purchasingPackageId == null
                        ? () => _buy(y)
                        : null,
                    loading: _purchasingPackageId == y.identifier,
                  );
                }),
              ),
            ],
          ],
        ),
        if (lifetime != null) ...[
          const SizedBox(height: 12),
          Builder(builder: (_) {
            final l = lifetime!;
            return _PlanCard(
              title: l.storeProduct.title,
              price: _livePriceFor(l),
              highlighted: false,
              fullWidth: true,
              onTap: _purchasingPackageId == null
                  ? () => _buy(l)
                  : null,
              loading: _purchasingPackageId == l.identifier,
            );
          }),
        ],
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  final AppThemeColors tc;
  final AppLocalizations? l10n;
  final String returnPath;
  const _TopBar({
    required this.tc,
    required this.l10n,
    required this.returnPath,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: tc.textPrimary),
            onPressed: () => context.go(returnPath),
          ),
          Expanded(
            child: Text(
              l10n?.paywallTitle ?? 'Go Premium',
              style: TextStyle(
                fontFamily: AppTypography.family,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: tc.textPrimary,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  final String headline;
  final AppThemeColors tc;
  const _HeroHeader({required this.headline, required this.tc});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: tc.alertSoft,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(
            Icons.workspace_premium,
            size: 32,
            color: AppColors.alert,
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            headline,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTypography.family,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: tc.textPrimary,
              height: 1.3,
              letterSpacing: -0.3,
            ),
          ),
        ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String title;
  final String price;
  final bool highlighted;
  final String? badge;
  final bool fullWidth;
  final VoidCallback? onTap;
  final bool loading;
  const _PlanCard({
    required this.title,
    required this.price,
    required this.highlighted,
    this.badge,
    this.fullWidth = false,
    required this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: Container(
          width: fullWidth ? double.infinity : null,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: tc.surface,
            border: Border.all(
              color: highlighted ? tc.ctaBackground : tc.divider,
              width: highlighted ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          child: Column(
            children: [
              if (badge != null) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: tc.accentSoft,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: Text(
                    AppLocalizations.of(context)?.paywallSave ?? 'Save 58%',
                    style: TextStyle(
                      fontFamily: AppTypography.family,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: tc.ctaBackground,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Text(
                title,
                style: TextStyle(
                  fontFamily: AppTypography.family,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: tc.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              if (loading)
                const SizedBox(
                  height: 28,
                  width: 28,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Text(
                  price,
                  style: TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: tc.textPrimary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComparisonTable extends StatelessWidget {
  const _ComparisonTable();
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tc = AppThemeColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: tc.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: tc.divider),
      ),
      child: Column(
        children: [
          _headerRow(tc, l10n),
          Divider(height: 1, color: tc.divider),
          _row(
            tc,
            l10n?.paywallActiveDisputes ?? 'Active disputes',
            '1',
            l10n?.paywallUnlimited ?? 'Unlimited',
          ),
          Divider(height: 1, color: tc.divider),
          _row(
            tc,
            l10n?.paywallTemplates ?? 'Templates',
            '5',
            '50+',
          ),
          Divider(height: 1, color: tc.divider),
          _iconRow(
            tc,
            l10n?.paywallOmbudsmanLetter ?? 'Ombudsman letter generator',
          ),
          Divider(height: 1, color: tc.divider),
          _iconRow(
            tc,
            l10n?.paywallHindiTemplates ?? 'Hindi premium templates',
          ),
        ],
      ),
    );
  }

  Widget _headerRow(AppThemeColors tc, AppLocalizations? l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: Row(
        children: [
          Expanded(flex: 5, child: const SizedBox.shrink()),
          Expanded(
            flex: 2,
            child: Center(
              child: Text(
                l10n?.paywallFreeRow ?? 'Free',
                style: TextStyle(
                  fontFamily: AppTypography.family,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: tc.textSecondary,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: Text(
                l10n?.paywallPremiumRow ?? 'Premium',
                style: TextStyle(
                  fontFamily: AppTypography.family,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: tc.ctaBackground,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(AppThemeColors tc, String label, String freeVal, String premVal) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text(
              label,
              style: TextStyle(
                fontFamily: AppTypography.family,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: tc.textPrimary,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: Text(
                freeVal,
                style: TextStyle(
                  fontFamily: AppTypography.family,
                  fontSize: 13,
                  color: tc.textSecondary,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: Text(
                premVal,
                style: TextStyle(
                  fontFamily: AppTypography.family,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: tc.ctaBackground,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconRow(AppThemeColors tc, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text(
              label,
              style: TextStyle(
                fontFamily: AppTypography.family,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: tc.textPrimary,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child:
                Center(child: Icon(Icons.close, size: 16, color: tc.textTertiary)),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tc.accentSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check, size: 14, color: tc.ctaBackground),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RestoreRow extends StatelessWidget {
  final VoidCallback? onRestore;
  final VoidCallback onDismiss;
  final AppThemeColors tc;
  final AppLocalizations? l10n;
  const _RestoreRow({
    required this.onRestore,
    required this.onDismiss,
    required this.tc,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextButton(
          onPressed: onRestore,
          child: Text(
            l10n?.paywallRestore ?? 'Restore purchases',
            style: TextStyle(
              fontFamily: AppTypography.family,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: tc.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: onDismiss,
          child: Text(
            l10n?.paywallMaybeLater ?? 'Maybe later',
            style: TextStyle(
              fontFamily: AppTypography.family,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: tc.textTertiary,
            ),
          ),
        ),
      ],
    );
  }
}
