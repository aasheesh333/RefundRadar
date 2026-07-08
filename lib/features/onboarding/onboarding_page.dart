import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_tokens.dart';
import '../../shared/widgets/hero_emoji_circle.dart';
import '../../shared/widgets/page_dots.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});
  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pc = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < _slides.length - 1) {
      _pc.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.ease,
      );
    } else {
      context.go('/onboard/sms');
    }
  }

  static const _slides = <_SlideData>[
    _SlideData(
      emoji: '💸',
      title: '₹100/day — banks owe YOU\nfor failed UPI',
      desc:
          'RBI rules make banks pay compensation for delayed refunds on failed UPI, IMPS, ATM, and FASTag transactions.',
      softColor: AppColors.accentSoft,
      ctaLabel: 'Start free',
    ),
    _SlideData(
      emoji: '🚗',
      title: "FASTag double-cut?\nYou're owed ₹100/day",
      desc:
          'NPCI rules say banks must refund FASTag double-debits within 5 days. We track the deadline and escalate.',
      softColor: AppColors.alertSoft,
      ctaLabel: 'Continue',
    ),
    _SlideData(
      emoji: '⚖️',
      title: 'Banks ignoring you?\nTake them to the Ombudsman',
      desc:
          "If a bank doesn't refund within 10 days, we auto-draft a Banking Ombudsman complaint citing the exact RBI circular.",
      softColor: AppColors.premiumGoldSoft,
      ctaLabel: 'Get started',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: SafeArea(
        child: Column(
          children: [
            // top bar with skip
            Padding(
              padding: const EdgeInsets.only(top: 16, right: 16),
              child: Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: () => context.go('/home'),
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    foregroundColor: AppColors.textSecondaryLight,
                  ),
                  child: const Text(
                    'Skip',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            // slides
            Expanded(
              child: PageView.builder(
                controller: _pc,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) => _SlideView(
              slide: _slides[i],
              totalSlides: _slides.length,
            ),
              ),
            ),
            // bottom stack: dots + CTA + disclaimer
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              child: Column(
                children: [
                  PageDots(count: _slides.length, current: _page),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton(
                      onPressed: _next,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadii.md),
                        ),
                      ),
                      child: Text(
                        _slides[_page].ctaLabel,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Independent tool · Not affiliated with RBI/NPCI/banks',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textTertiaryLight,
                      height: 1.4,
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          HeroEmojiCircle(emoji: slide.emoji, softColor: slide.softColor),
          const SizedBox(height: 28),
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: AppTypography.family,
              fontSize: 28,
              fontWeight: FontWeight.w700,
              height: 1.2,
              color: AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 310),
            child: Text(
              slide.desc,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: AppTypography.family,
                fontSize: 15,
                fontWeight: FontWeight.w400,
                height: 1.5,
                color: AppColors.textSecondaryLight,
              ),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
