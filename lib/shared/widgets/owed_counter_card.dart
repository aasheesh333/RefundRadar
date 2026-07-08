import 'package:flutter/material.dart';

class OwedCounterCard extends StatefulWidget {
  final double totalOwed;
  final int disputeCount;
  final double perDay;
  const OwedCounterCard({
    super.key,
    required this.totalOwed,
    required this.disputeCount,
    required this.perDay,
  });

  @override
  State<OwedCounterCard> createState() => _OwedCounterCardState();
}

class _OwedCounterCardState extends State<OwedCounterCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        duration: const Duration(milliseconds: 600), vsync: this);
    _anim = Tween<double>(begin: 0, end: widget.totalOwed)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF0B3D2E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Total Owed',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(color: const Color(0xFFE8F0EC).withValues(alpha: 0.7))),
          const SizedBox(height: 8),
          AnimatedBuilder(
            animation: _anim,
            builder: (c, _) => Text(
              _formatIndian(_anim.value),
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 40,
                fontWeight: FontWeight.w800,
                color: const Color(0xFFF5A623),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'across ${widget.disputeCount} disputes, growing ₹${widget.perDay.toStringAsFixed(0)}/day',
            style: TextStyle(color: const Color(0xFFE8F0EC).withValues(alpha: 0.7), fontSize: 12),
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
    return '₹${parts.join()}';
  }
}
