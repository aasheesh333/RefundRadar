import 'package:flutter/material.dart';

/// PressableScale — subtle "alive" press feedback for tappable cards.
///
/// Scales the child down to [pressedScale] while the pointer is held, with a
/// springy ease-out on release. Wraps [child] (which should contain its own
/// InkWell/GestureDetector handling [onTap]) so this is purely presentational
/// and composes with any existing tap target without stealing the gesture.
///
/// Keep [pressedScale] gentle (0.97–0.98) — large scale reads as janky on
/// text-heavy fintech cards. Duration is intentionally short (~90ms) so the
/// interaction feels snappy, not floaty.
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.pressedScale = 0.98,
    this.duration = const Duration(milliseconds: 90),
  });

  final Widget child;
  final double pressedScale;
  final Duration duration;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _scale = Tween<double>(begin: 1.0, end: widget.pressedScale)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _down(TapDownDetails _) => _ctrl.forward();
  void _up([_]) => _ctrl.reverse();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: _down,
      onTapUp: _up,
      onTapCancel: _up,
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}
