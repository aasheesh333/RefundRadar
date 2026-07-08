import 'package:flutter/material.dart';
import '../../core/theme/app_tokens.dart';

/// Circular back arrow button — used by Screens 5, 6, 7, 8, 12, 13.
/// 36×36 or 40×40 (default 40), surfaceLight bg, 1px hr border, tx color arrow.
class AppBackButton extends StatelessWidget {
  const AppBackButton({
    super.key,
    this.size = 40,
    this.onTap,
  });

  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap ?? () => Navigator.of(context).maybePop(),
      borderRadius: BorderRadius.circular(size),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          border: Border.all(color: AppColors.dividerLight, width: 1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.arrow_back,
          size: size * 0.5,
          color: AppColors.textPrimaryLight,
        ),
      ),
    );
  }
}
