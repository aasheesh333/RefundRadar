import 'package:flutter/material.dart';
import '../../core/theme/app_tokens.dart';

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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.xs),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: AppColors.surfaceAltLight,
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
                    ? AppColors.textTertiaryLight
                    : AppColors.textPrimaryLight,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Icon(Icons.expand_more, color: AppColors.textTertiaryLight, size: 20),
        ],
      ),
    );
  }
}
