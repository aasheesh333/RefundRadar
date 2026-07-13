import 'package:flutter/material.dart';
import 'package:refund_radar/core/theme/app_theme_colors.dart';
import 'package:refund_radar/core/theme/app_tokens.dart';

/// A row showing a recipient with an emoji tile, title, detail line and an
/// optional trailing widget (e.g. a toggle). When selected and no trailing
/// widget is supplied, a check mark is shown on the trailing Edge.
class RecipientRow extends StatelessWidget {
  final String emojiTile;
  final Color bgTileColor;
  final String title;
  final String detail;
  final bool selected;
  final Widget? trailing;
  const RecipientRow({
    super.key,
    required this.emojiTile,
    required this.bgTileColor,
    required this.title,
    required this.detail,
    required this.selected,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: bgTileColor,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Center(
            child: Text(emojiTile, style: const TextStyle(fontSize: 13)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: tc.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                detail,
                style: TextStyle(fontSize: 10, color: tc.textSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (selected && trailing == null)
          const Text(
            '✓',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.accent,
            ),
          ),
        ?trailing,
      ],
    );
  }
}
