import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:refund_radar/core/providers/user_profile_provider.dart';
import 'package:refund_radar/core/router/app_routes.dart';
import 'package:refund_radar/core/theme/app_theme_colors.dart';
import 'package:refund_radar/core/theme/app_tokens.dart';
import 'package:refund_radar/features/profile/profile_form.dart';
import 'package:refund_radar/l10n/app_localizations.dart';
import 'package:refund_radar/shared/widgets/app_back_button.dart';

/// One-time profile capture during onboarding (SMS → Profile → Banks).
/// Everything typed here is persisted locally and later pre-fills every
/// grievance email, so the user never edits an email by hand. Optional —
/// skippable and editable from Settings or inside dispute-create.
class OnboardProfilePage extends ConsumerStatefulWidget {
  const OnboardProfilePage({super.key});
  @override
  ConsumerState<OnboardProfilePage> createState() =>
      _OnboardProfilePageState();
}

class _OnboardProfilePageState extends ConsumerState<OnboardProfilePage> {
  final _formKey = GlobalKey<ProfileFormState>();

  Future<void> _save() async {
    final profile = _formKey.currentState?.current;
    if (profile == null) {
      context.go(AppRoutes.onboardBanks);
      return;
    }
    await saveUserProfile(ref, profile);
    if (mounted) context.go(AppRoutes.onboardBanks);
  }

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    final l10n = AppLocalizations.of(context);
    final initial = ref.watch(userProfileProvider);
    return Scaffold(
      backgroundColor: tc.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
              child: Row(
                children: [
                  AppBackButton(onTap: () => context.go(AppRoutes.onboardSms)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n?.profileOnboardKicker ?? 'ONE-TIME SETUP',
                          style: TextStyle(
                            fontFamily: AppTypography.family,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: tc.textTertiary,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          l10n?.profileOnboardTitle ?? 'Your details',
                          style: TextStyle(
                            fontFamily: AppTypography.family,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: tc.textPrimary,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: tc.accentSoft,
                      borderRadius: BorderRadius.circular(AppRadii.md),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('✉️', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            l10n?.profileOnboardBody ??
                                'Fill once — every complaint email auto-fills your name, mobile, email and account so you just press Send. Stored on this device only.',
                            style: TextStyle(
                              fontFamily: AppTypography.family,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: tc.textPrimary,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: tc.surface,
                      border: Border.all(color: tc.divider),
                      borderRadius: BorderRadius.circular(AppRadii.lg),
                    ),
                    child: ProfileForm(key: _formKey, initial: initial),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              decoration: BoxDecoration(
                color: tc.surface,
                border: Border(top: BorderSide(color: tc.divider)),
              ),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: tc.ctaBackground,
                        foregroundColor: tc.ctaForeground,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadii.md),
                        ),
                      ),
                      child: Text(
                        l10n?.profileSaveContinue ?? 'Save & continue',
                        style: TextStyle(
                          fontFamily: AppTypography.family,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: TextButton(
                      onPressed: () => context.go(AppRoutes.onboardBanks),
                      style: TextButton.styleFrom(
                        foregroundColor: tc.textSecondary,
                      ),
                      child: Text(
                        l10n?.profileSkipLater ?? 'Skip — I’ll add it later',
                        style: TextStyle(
                          fontFamily: AppTypography.family,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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
