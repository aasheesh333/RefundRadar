import 'package:flutter/material.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_theme_colors.dart';

/// Labeled input box matching mockup Screen 6 form fields.
/// 11pt uppercase label, 8px-rounded bordered input box.
/// Supports an optional focus border highlight and a green "found/✓" badge.
class FormFieldBox extends StatelessWidget {
  final String label;
  final Widget child;
  final String? helper;
  final bool focused;
  const FormFieldBox({
    super.key,
    required this.label,
    required this.child,
    this.helper,
    this.focused = false,
  });

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    final borderColor = focused ? AppColors.primary : tc.divider;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: tc.textSecondary,
              ),
            ),
            if (helper != null) ...[
              const SizedBox(width: 6),
              Text(
                helper!,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accent,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: tc.surface,
            border: Border.all(color: borderColor, width: 1),
            borderRadius: BorderRadius.circular(AppRadii.xs),
          ),
          child: child,
        ),
      ],
    );
  }
}
