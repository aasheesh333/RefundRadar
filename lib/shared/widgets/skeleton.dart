import 'package:flutter/material.dart';
import 'package:refund_radar/core/theme/app_theme_colors.dart';

/// Skeleton placeholder box used in loading states (B8). Renders a soft
/// rounded grey tile that pulses, mimicking the eventual content shape.
/// Use [SkeletonBox.card] / [SkeletonBox.line] convenience constructors
/// for the most common shapes.
class SkeletonBox extends StatefulWidget {
  final double width;
  final double height;
  final double radius;

  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.radius = 8,
  });

  /// A 16-px tall line spanning the parent width by default.
  const SkeletonBox.line({super.key, this.width = double.infinity, this.height = 14, this.radius = 6})
      : assert(height > 0);

  /// A 16:9-ish card tile used for list placeholders.
  const SkeletonBox.card({super.key, this.width = double.infinity, this.height = 96, this.radius = 16})
      : assert(height > 0);

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _a;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _a = Tween<double>(begin: 0.45, end: 1.0).animate(
      CurvedAnimation(parent: _c, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    return AnimatedBuilder(
      animation: _a,
      builder: (_, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: tc.divider.withValues(alpha: 0.55 * _a.value),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        );
      },
    );
  }
}

/// Standard loading list: animated shimmer cards stacked vertically.
/// Drop straight into an `AsyncValue.when(loading: ...)`.
class SkeletonList extends StatelessWidget {
  final int itemCount;
  final double itemHeight;
  const SkeletonList({
    super.key,
    this.itemCount = 4,
    this.itemHeight = 96,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, _) => const SkeletonBox.card(),
    );
  }
}
