import 'package:flutter/material.dart';

class DangerBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onAction;
  final String? actionLabel;
  const DangerBanner({
    super.key,
    required this.message,
    this.onAction,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE5484D).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5484D), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFE5484D)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message,
                style: const TextStyle(color: Color(0xFFE5484D), fontWeight: FontWeight.w600)),
          ),
          if (onAction != null && actionLabel != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}
