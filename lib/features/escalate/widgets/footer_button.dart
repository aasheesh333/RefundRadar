import 'package:flutter/material.dart';
import 'package:refund_radar/core/theme/app_tokens.dart';

/// A footer button used in the escalate page for copy / send actions.
class FooterButton extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;
  final bool elevation;
  final VoidCallback onTap;
  const FooterButton({
    super.key,
    required this.label,
    required this.color,
    required this.textColor,
    this.elevation = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(AppRadii.md),
      elevation: elevation ? 4 : 0,
      shadowColor: elevation ? const Color(0x1F0B3D2E) : Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.md),
        onTap: onTap,
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppTypography.family,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}
