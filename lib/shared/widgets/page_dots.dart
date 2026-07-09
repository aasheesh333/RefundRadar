import 'package:flutter/material.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_theme_colors.dart';

/// PageDots — 3-dot indicator (mockup `.page-dots`).
/// Active dot = 24×8 pill r4 accent. Inactive = 8×8 circle r4 hr.
class PageDots extends StatelessWidget {
  const PageDots({
    super.key,
    this.count = 3,
    required this.current,
  });

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: i == current ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == current ? AppColors.accent : tc.divider,
              borderRadius:
                  BorderRadius.circular(i == current ? 4 : 4),
            ),
          ),
        ],
      ],
    );
  }
}
