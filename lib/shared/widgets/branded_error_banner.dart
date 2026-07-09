import 'package:flutter/material.dart';
import 'package:refund_radar/core/theme/app_tokens.dart';
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

  const BrandedErrorBanner({
    super.key,
    required this.message,
    this.onRetry,
    this.icon = Icons.cloud_off_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.errorSoft,
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
                      color: AppColors.textPrimaryLight,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondaryLight,
                      height: 1.35,
                    ),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 16),
                FilledButton.tonalIcon(
                  onPressed: onRetry,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
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
