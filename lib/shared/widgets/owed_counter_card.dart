import 'package:flutter/material.dart';
import '../../core/theme/app_tokens.dart';

/// Hero "You're owed" gradient card matching mockup Screen 4.
/// Dark green gradient background, amber-heavy counter moved to WHITE per
/// mockup (the accent lives in the daily-growth pill), overline uppercase
/// label + pulsing accent dot, subtitle + green "↑ ₹{perDay}/day" pill.
class OwedCounterCard extends StatefulWidget {
  final double totalOwed;
  final int disputeCount;
  final double perDay;
  final bool compact;
  const OwedCounterCard({
    super.key,
    required this.totalOwed,
    required this.disputeCount,
    required this.perDay,
    this.compact = false,
  });

  @override
  State<OwedCounterCard> createState() => _OwedCounterCardState();
}

class _OwedCounterCardState extends State<OwedCounterCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  late Animation<double> _dot;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        duration: const Duration(milliseconds: 600), vsync: this);
    _anim = Tween<double>(begin: 0, end: widget.totalOwed)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _dot = Tween<double>(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _ctrl.repeat(reverse: true, period: const Duration(milliseconds: 1400));
  }

  @override
  void didUpdateWidget(OwedCounterCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.totalOwed != widget.totalOwed) {
      _anim = Tween<double>(begin: oldWidget.totalOwed, end: widget.totalOwed)
          .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
      _ctrl
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const begin = Alignment.topLeft;
    const end = Alignment.bottomRight;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: begin,
          end: end,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.all(Radius.circular(AppRadii.lg)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                "YOU'RE OWED",
                style: TextStyle(
                  fontFamily: AppTypography.family,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: Color(0xB3FFFFFF),
                ),
              ),
              const SizedBox(width: 6),
              FadeTransition(
                opacity: _dot,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.accent,
                          blurRadius: 6,
                          spreadRadius: 0),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          AnimatedBuilder(
            animation: _anim,
            builder: (c, _) => Text(
              _formatIndian(_anim.value),
              style: const TextStyle(
                fontFamily: AppTypography.family,
                fontSize: 40,
                fontWeight: FontWeight.w800,
                height: 1.0,
                letterSpacing: -0.8,
                fontFeatures: [FontFeature.tabularFigures()],
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  '${widget.disputeCount} ${widget.disputeCount == 1 ? 'dispute' : 'disputes'}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xB3FFFFFF),
                  ),
                ),
              ),
              if (widget.perDay > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0x2616C784),
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: Text(
                    '↑ ₹${widget.perDay.toStringAsFixed(0)}/day',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatIndian(double amount) {
    final str = amount.toStringAsFixed(0);
    final parts = <String>[];
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      if (count == 3) {
        parts.insert(0, ',');
      } else if (count > 3 && count % 2 == 1) {
        parts.insert(0, ',');
      }
      parts.insert(0, str[i]);
      count++;
    }
    return '₹ ${parts.join()}';
  }
}
