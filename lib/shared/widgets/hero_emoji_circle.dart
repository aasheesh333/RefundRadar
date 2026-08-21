import 'package:flutter/material.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_theme_colors.dart';

/// HeroEmojiCircle — circular avatar with radial gradient
/// `surface -> softColor`, used by onboarding slides and permission screens.
/// Default size 140, soft color = accentSoft; override per slide.
///
/// Prefer [icon] over [emoji] for a consistent brand look — a Material icon
/// rendered in [iconColor] reads as a designed system, whereas emoji glyphs
/// vary by OS and can look like a sticker sheet. [emoji] is kept for
/// backward compatibility / expressive decoration only.
class HeroEmojiCircle extends StatelessWidget {
  const HeroEmojiCircle({
    super.key,
    this.emoji,
    this.icon,
    this.iconColor,
    this.size = 140,
    this.softColor,
    this.shadows = AppShadows.card,
  });

  final String? emoji;
  final IconData? icon;
  final Color? iconColor;
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
        child: icon != null
            ? Icon(
                icon,
                size: size * 0.42,
                color: iconColor ?? tc.ctaBackground,
              )
            : Text(
                emoji ?? '',
                style: TextStyle(
                  fontSize: size * 0.46,
                  height: 1,
                ),
              ),
      ),
    );
  }
}
