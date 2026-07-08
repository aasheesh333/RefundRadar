import 'package:flutter/material.dart';
import '../../core/theme/app_tokens.dart';

/// A single RBI timeline step — matches mockup Screen 7.
class RbiTimelineStep {
  final String title;
  final String detail;
  final RbiStepState state;
  const RbiTimelineStep({
    required this.title,
    required this.detail,
    this.state = RbiStepState.pending,
  });
}

enum RbiStepState { done, active, pending }

/// 5-step RBI timeline card matching mockup Screen 7.
/// `headerLabel` is the uppercase caption (e.g. "RBI timeline (T-day = 0)").
class RbiTimeline extends StatelessWidget {
  final String headerLabel;
  final List<RbiTimelineStep> steps;
  const RbiTimeline({
    super.key,
    required this.headerLabel,
    required this.steps,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        border: Border.all(color: AppColors.dividerLight, width: 1),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            headerLabel.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 10),
          ...List.generate(steps.length, (i) {
            final s = steps[i];
            final isLast = i == steps.length - 1;
            return Padding(
              padding: EdgeInsets.fromLTRB(0, i == 0 ? 0 : 12, 0, isLast ? 0 : 12),
              child: _StepRow(step: s),
            );
          }),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final RbiTimelineStep step;
  const _StepRow({required this.step});

  @override
  Widget build(BuildContext context) {
    final (bg, fg, content) = switch (step.state) {
      RbiStepState.done => (
          AppColors.accent,
          Colors.white,
          const Text('✓',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.white))
        ),
      RbiStepState.active => (
          AppColors.alert,
          Colors.white,
          const Text('!',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.white))
        ),
      RbiStepState.pending => (
          AppColors.surfaceAltLight,
          AppColors.textTertiaryLight,
          null,
        ),
    };
    final titleColor = step.state == RbiStepState.pending
        ? AppColors.textTertiaryLight
        : AppColors.textPrimaryLight;
    final detailColor = step.state == RbiStepState.active
        ? AppColors.alert
        : (step.state == RbiStepState.pending
            ? AppColors.textTertiaryLight
            : AppColors.textSecondaryLight);
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: content ??
                Text(
                  '',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: fg),
                ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                step.title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                step.detail,
                style: TextStyle(fontSize: 11, color: detailColor),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
