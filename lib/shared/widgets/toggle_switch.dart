import 'package:flutter/material.dart';
import '../../core/theme/app_tokens.dart';

/// ToggleSwitch — 34×20 r10 (accent ON / hr OFF) + 16×16 white knob.
/// Replacement for Material `Switch` on settings cards.
class ToggleSwitch extends StatelessWidget {
  const ToggleSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final on = value;
    return InkWell(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 34,
        height: 20,
        decoration: BoxDecoration(
          color: on ? AppColors.accent : AppColors.dividerLight,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 120),
              left: on ? 18 : 2,
              top: 2,
              child: Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
