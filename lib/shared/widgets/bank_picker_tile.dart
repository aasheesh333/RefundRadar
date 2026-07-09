import 'package:flutter/material.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_theme_colors.dart';

/// Bank/issuer picker row matching mockup Screen 6 BANK field.
/// 26×26 initial-letter tile + bank name + ▾ chevron.
class BankPickerTile extends StatelessWidget {
  final String bankName;
  final VoidCallback onTap;
  const BankPickerTile({
    super.key,
    required this.bankName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.xs),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: tc.surfaceAlt,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Center(
              child: Text(
                bankName.isEmpty ? '?' : bankName.substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              bankName.isEmpty ? 'Select bank' : bankName,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: bankName.isEmpty
                    ? tc.textTertiary
                    : tc.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Icon(Icons.expand_more, color: tc.textTertiary, size: 20),
        ],
      ),
    );
  }
}
