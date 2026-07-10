import 'package:flutter/material.dart';
import 'package:refund_radar/core/theme/app_tokens.dart';
import 'package:refund_radar/core/theme/app_theme_colors.dart';
import 'package:refund_radar/l10n/app_localizations.dart';

/// Branded error banner (B8). Shown when an async fetch fails — replaces
/// the generic `Center(child: Text(error))` pattern with a calm, on-brand
/// "couldn't load X / Retry" card. Use:
///
/// ```dart
/// async.when(
///   loading: () => const SkeletonList(),
///   error: (e, _) => BrandedErrorBanner(message: e.toString(), onRetry: ref.invalidate(provider)),
///   data: (data) => Content(...),
/// );
/// ```
///
/// Localized: the title (`Something went wrong`) and the `Retry` button
/// label flow through [AppLocalizations]. Falls back to English if a
/// context-localized instance is unavailable (e.g. inside a non-Widget
/// harness).
class BrandedErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final IconData icon;
  // Optional technical detail (Firebase error code / short stack) shown in a
  // collapsible row under the friendly message. Sanity-check the exact failure
  // layer without exposing a raw stack to end users.
  final String? detail;

  const BrandedErrorBanner({
    super.key,
    required this.message,
    this.onRetry,
    this.icon = Icons.cloud_off_rounded,
    this.detail,
  });

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    final l = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: tc.errorSoft,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 36, color: AppColors.error),
              const SizedBox(height: 12),
              Text(
                l?.commonError ?? 'Something went wrong',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: tc.textPrimary,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: tc.textSecondary,
                      height: 1.35,
                    ),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
              if (detail != null && detail!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: tc.surfaceAlt,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    detail!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: tc.textTertiary,
                          height: 1.3,
                        ),
                  ),
                ),
              ],
              if (onRetry != null) ...[
                const SizedBox(height: 16),
                FilledButton.tonalIcon(
                  onPressed: onRetry,
                  style: FilledButton.styleFrom(
                    backgroundColor: tc.ctaBackground,
                    foregroundColor: tc.ctaForeground,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(l?.commonRetry ?? 'Retry'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
