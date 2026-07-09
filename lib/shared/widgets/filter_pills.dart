import 'package:flutter/material.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_theme_colors.dart';

/// FilterPills — horizontal pill row used by History and Templates screens.
/// Selected = primary fill + white text. Inactive = surface bg + 1px hr border.
typedef FilterPill = ({String label, bool selected, void Function()? onTap});

class FilterPills extends StatelessWidget {
  const FilterPills({super.key, required this.pills});
  final List<FilterPill> pills;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < pills.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            _Pill(pill: pills[i]),
          ],
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.pill});
  final FilterPill pill;

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    final selected = pill.selected;
    return InkWell(
      onTap: pill.onTap,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : tc.surface,
          border: Border.all(
            color: selected ? AppColors.primary : tc.divider,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: Text(
          pill.label,
          style: TextStyle(
            fontFamily: AppTypography.family,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: selected ? Colors.white : tc.textSecondary,
          ),
        ),
      ),
    );
  }
}
