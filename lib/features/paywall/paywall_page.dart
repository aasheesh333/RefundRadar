import 'package:flutter/foundation.dart';
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

/// Premium upsell page (Backlog B3).
///
/// Connects to RevenueCat to:
///   - fetch the current offering's packages(),
///   - drive `purchasePackage()` on plan buttons,
///   - `restorePurchases()` on the Restore button,
///   - log `paywall_view` once per visit and `purchase` on success.
///
/// If the SDK isn't configured (debug builds without `--dart-define`), we
/// still show the page but display a "unavailable in this build" banner
/// and let the user dismiss. The Test Store key fallback in
/// `RevenueCatService.envSdkKey` means this branch should rarely hit on a
/// real device — but keep it for safety.
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
      setState(() {
        _offerings = offerings;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Could not load plans. Tap retry.';
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
              AppLocalizations.of(context)?.paywallTitle ?? 'Premium unlocked',
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
                ? (l10n?.paywallRestored ?? 'Premium restored 🎉')
                // Task 8.1 — restorePurchases() swallows all exceptions
                // and returns `false`, so a `false` here could mean either
                // "no prior purchases" OR "network/play-services error".
                // The generic localized message covers both cases without
                // leaking raw exception text.
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(AppLocalizations.of(context)?.paywallTitle ?? 'Go Premium')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Icon(Icons.workspace_premium,
              size: 72, color: AppColors.alert),
          const SizedBox(height: 16),
          Text(
            // Contextual paywall (Task 7.4): when triggered from a specific
            // template, name it in the headline so the upsell feels directly
            // tied to what the user tried to access. Fall back to the generic
            // headline for non-template triggers (settings, free-limit hit).
            () {
              final l10n = AppLocalizations.of(context);
              final title = widget.templateTitle;
              if (title != null && title.isNotEmpty) {
                return l10n?.paywallHeadlineTemplate(title) ??
                    'Unlock “$title” and 50+ premium templates.';
              }
              return l10n?.paywallHeadline ??
                  'Recover more. Unlimited disputes + 50+ templates.';
            }(),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          _buildPlansArea(),
          const SizedBox(height: 24),
          const _ComparisonTable(),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _purchasingPackageId == null ? _restore : null,
            child: Text(AppLocalizations.of(context)?.paywallRestore ?? 'Restore purchases'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => context.go(widget.returnPath),
            child: Text(AppLocalizations.of(context)?.paywallMaybeLater ?? 'Maybe later'),
          ),
        ],
      ),
    );
  }

  /// Live store price for a package — uses Play Billing's localized
  /// `storeProduct.priceString` (e.g. "₹99.00", "US$0.99") instead of
  /// the previous hardcoded ₹99/₹499/₹1,999 override. The underlying
  /// purchase still charges whatever the linked Play Store product costs,
  /// so this is now display-only of the *real* price.
  ///
  /// Crashlytics log: when the device locale resolves to `en-IN` or any
  /// Indian locale but the priceString doesn't contain "₹", that usually
  /// means the Play Store account region doesn't match the device (e.g.
  /// an Indian user logged into a US account) — useful telemetry for
  /// explaining "wrong currency" support tickets.
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
    } catch (_) {
      // Localizations not ready yet — skip the soft check.
    }
    return priceString;
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
      // SDK not configured OR no offering attached in dashboard. Show the
      // Notion-plan INR prices (spec §6.2: monthly ₹99 / yearly ₹499) so
      // the page is informative even before the live products are wired in
      // RevenueCat/Play Console. Taps surface a "setup pending" SnackBar —
      // we never silently swallow the tap.
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _PlanCard(
                  title: 'Monthly',
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
                  title: 'Yearly',
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
            title: 'Lifetime',
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
                fontSize: 11,
                color: tc.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      );
    }
    // Order: Monthly, Yearly first (Yearly highlighted), Lifetime last.
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
                child: Builder(builder: (innerCtx) {
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
          Builder(builder: (innerCtx) {
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
    return InkWell(
      onTap: loading ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: fullWidth ? double.infinity : null,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: highlighted ? AppColors.accent : tc.divider,
            width: highlighted ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            if (badge != null) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                    AppLocalizations.of(context)?.paywallSave ?? 'Save 58%',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.accent)),
              ),
              const SizedBox(height: 8),
            ],
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (loading)
              const SizedBox(
                height: 28,
                width: 28,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Text(price,
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w800)),
          ],
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
    return Table(
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      border: TableBorder.symmetric(
        inside: BorderSide(color: tc.divider),
      ),
      children: [
        TableRow(children: [
          const Padding(padding: EdgeInsets.all(12), child: Text('')),
          Padding(
              padding: const EdgeInsets.all(12),
              child: Text(l10n?.paywallFreeRow ?? 'Free',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w600))),
          Padding(
              padding: const EdgeInsets.all(12),
              child: Text(l10n?.paywallPremiumRow ?? 'Premium',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
        TableRow(children: [
          Padding(
              padding: const EdgeInsets.all(12),
              child: Text(l10n?.paywallActiveDisputes ?? 'Active disputes')),
          const Padding(
              padding: EdgeInsets.all(12),
              child: Text('1', textAlign: TextAlign.center)),
          Padding(
              padding: const EdgeInsets.all(12),
              child: Text(l10n?.paywallUnlimited ?? 'Unlimited',
                  textAlign: TextAlign.center)),
        ]),
        TableRow(children: [
          Padding(
              padding: const EdgeInsets.all(12),
              child: Text(l10n?.paywallTemplates ?? 'Templates')),
          const Padding(
              padding: EdgeInsets.all(12),
              child: Text('5', textAlign: TextAlign.center)),
          const Padding(
              padding: EdgeInsets.all(12),
              child: Text('50+', textAlign: TextAlign.center)),
        ]),
        TableRow(children: [
          Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                  l10n?.paywallOmbudsmanLetter ?? 'Ombudsman letter generator')),
          Padding(
              padding: const EdgeInsets.all(12),
              child: Icon(Icons.close, color: tc.textTertiary)),
          const Padding(
              padding: EdgeInsets.all(12),
              child: Icon(Icons.check, color: AppColors.accent)),
        ]),
        TableRow(children: [
          Padding(
              padding: const EdgeInsets.all(12),
              child: Text(l10n?.paywallHindiTemplates ??
                  'Hindi premium templates')),
          Padding(
              padding: const EdgeInsets.all(12),
              child: Icon(Icons.close, color: tc.textTertiary)),
          const Padding(
              padding: EdgeInsets.all(12),
              child: Icon(Icons.check, color: AppColors.accent)),
        ]),
      ],
    );
  }
}
