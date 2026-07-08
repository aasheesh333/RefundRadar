import 'package:flutter/material.dart';
import '../../core/theme/app_tokens.dart';

/// OnboardingStepHeader — stacked overline ("Step N of 4") + H1 title,
/// left-aligned. Used by Dispute Type, Dispute Form, SMS permission, Add banks.
class OnboardingStepHeader extends StatelessWidget {
  const OnboardingStepHeader({
    super.key,
    required this.step,
    required this.title,
    this.maxLines = 2,
  });

  final String step;
  final String title;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          step,
          style: AppTypography.overline(color: AppColors.textSecondaryLight),
        ),
        const SizedBox(height: 1),
        Text(
          title,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: AppTypography.family,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            height: 1.2,
            color: AppColors.textPrimaryLight,
          ),
        ),
      ],
    );
  }
}
