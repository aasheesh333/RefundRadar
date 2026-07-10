import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/app_state_provider.dart';
import '../../core/theme/app_theme_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/hero_emoji_circle.dart';
import '../../shared/widgets/page_dots.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});
  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final PageController _pc = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  void _next() {
    final tc = AppThemeColors.of(context);
    final slides = _slidesFor(AppLocalizations.of(context), tc);
    if (_page < slides.length - 1) {
      _pc.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.ease,
      );
    } else {
      context.go('/onboard/sms');
    }
  }

  void _skip() async {
    // Skip marks onboarding complete (so it doesn't replay next launch)
    // and jumps straight to home.
    await markOnboardingComplete(ref);
    if (mounted) context.go('/home');
  }

  List<_SlideData> _slidesFor(AppLocalizations? l10n, AppThemeColors tc) => [
        _SlideData(
          emoji: '💸',
          title: l10n?.onboardSlide1Title ??
              '₹100/day — banks owe YOU\nfor failed UPI',
          desc: l10n?.onboardSlide1Desc ??
              'RBI rules make banks pay compensation for delayed refunds on failed UPI, IMPS, ATM, and FASTag transactions.',
          softColor: tc.accentSoft,
          ctaLabel: l10n?.onboardCta ?? 'Start free',
        ),
        _SlideData(
          emoji: '🚗',
          title: l10n?.onboardSlide2Title ??
              "FASTag double-cut?\nYou're owed ₹100/day",
          desc: l10n?.onboardSlide2Desc ??
              'NPCI rules say banks must refund FASTag double-debits within 5 days. We track the deadline and escalate.',
          softColor: tc.alertSoft,
          ctaLabel: l10n?.disputeTypeContinue ?? 'Continue',
        ),
        _SlideData(
          emoji: '⚖️',
          title: l10n?.onboardSlide3Title ??
              'Banks ignoring you?\nTake them to the Ombudsman',
          desc: l10n?.onboardSlide3Desc ??
              "If a bank doesn't refund within 10 days, we auto-draft a Banking Ombudsman complaint citing the exact RBI circular.",
          softColor: tc.premiumGoldSoft,
          ctaLabel: l10n?.onboardCta ?? 'Get started',
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tc = AppThemeColors.of(context);
    final slides = _slidesFor(l10n, tc);
    return Scaffold(
      backgroundColor: tc.bg,
      body: Column(
        children: [
          // top bar with skip — safe top only
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.only(top: 8, right: 16),
              child: Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: _skip,
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    foregroundColor: tc.textSecondary,
                  ),
                  child: Text(
                    l10n?.onboardSkip ?? 'Skip',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // slides
          Expanded(
            child: PageView.builder(
              controller: _pc,
              itemCount: slides.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (context, i) => _SlideView(
                slide: slides[i],
                totalSlides: slides.length,
              ),
            ),
          ),
          // bottom stack: dots + CTA + disclaimer — safe bottom so CTA
          // never clips under the system nav / gesture bar
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PageDots(count: slides.length, current: _page),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton(
                      onPressed: _next,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadii.md),
                        ),
                      ),
                      child: Text(
                        slides[_page].ctaLabel,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n?.settingsNotAffiliated ??
                        'Independent tool · Not affiliated with RBI/NPCI/banks',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: tc.textTertiary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SlideData {
  final String emoji;
  final String title;
  final String desc;
  final Color softColor;
  final String ctaLabel;

  const _SlideData({
    required this.emoji,
    required this.title,
    required this.desc,
    required this.softColor,
    required this.ctaLabel,
  });
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide, required this.totalSlides});
  final _SlideData slide;
  final int totalSlides;

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 420;
        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 20,
            vertical: compact ? 8 : 16,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              HeroEmojiCircle(
                emoji: slide.emoji,
                softColor: slide.softColor,
              ),
              SizedBox(height: compact ? 16 : 24),
              Text(
                slide.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppTypography.family,
                  fontSize: compact ? 24 : 28,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  color: tc.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 310),
                child: Text(
                  slide.desc,
                  textAlign: TextAlign.center,
                  maxLines: compact ? 4 : 6,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    height: 1.45,
                    color: tc.textSecondary,
                  ),
                ),
              ),
              const Spacer(flex: 3),
            ],
          ),
        );
      },
    );
  }
}
