import 'package:flutter/material.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_theme_colors.dart';

/// HeroEmojiCircle — circular emoji avatar with radial gradient
/// `surface -> softColor`, used by onboarding slides and permission screens.
/// Default size 140, soft color = accentSoft; override per slide.
class HeroEmojiCircle extends StatelessWidget {
  const HeroEmojiCircle({
    super.key,
    required this.emoji,
    this.size = 140,
    this.softColor,
    this.shadows = AppShadows.card,
  });

  final String emoji;
  final double size;
  final Color? softColor;
  final List<BoxShadow> shadows;

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    final soft = softColor ?? tc.accentSoft;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.4, -0.4),
          colors: [tc.surface, soft],
        ),
        boxShadow: shadows,
      ),
      child: Center(
        child: Text(
          emoji,
          style: TextStyle(
            fontSize: size * 0.46,
            height: 1,
          ),
        ),
      ),
    );
  }
}
