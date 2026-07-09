import 'package:flutter/material.dart';
import '../../core/theme/app_theme_colors.dart';

/// Circular back arrow button — used by Screens 5, 6, 7, 8, 12, 13.
/// Default size is 48×48 to meet Material minimum touch-target size.
class AppBackButton extends StatelessWidget {
  const AppBackButton({
    super.key,
    this.size = 48,
    this.onTap,
  });

  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    return Tooltip(
      message: 'Back',
      child: Semantics(
        button: true,
        label: 'Back',
        child: InkWell(
          onTap: onTap ?? () => Navigator.of(context).maybePop(),
          borderRadius: BorderRadius.circular(size),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: tc.surface,
              border: Border.all(color: tc.divider, width: 1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.arrow_back,
              size: size * 0.45,
              color: tc.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
