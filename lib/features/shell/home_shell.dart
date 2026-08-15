import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:refund_radar/core/theme/app_theme_colors.dart';
import 'package:refund_radar/core/theme/app_tokens.dart';
import 'package:refund_radar/l10n/app_localizations.dart';

/// Persistent bottom-navigation shell that hosts the four primary
/// destinations (Home / History / Templates / Settings). Wraps the
/// `StatefulShellRoute` branches from [goRouterProvider] so each tab keeps
/// its own navigation stack and scroll position across tab switches.
class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.navigationShell});

  /// The go_router shell that owns the per-branch navigator stacks.
  final StatefulNavigationShell navigationShell;

  void _goBranch(int index) {
    // `initialLocation: index == current` re-pops the branch to its root on a
    // repeat tap (standard bottom-nav behaviour), otherwise switches branch.
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: tc.bg,
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: tc.surface,
          border: Border(top: BorderSide(color: tc.divider, width: 1)),
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            backgroundColor: tc.surface,
            indicatorColor: tc.accentSoft,
            elevation: 0,
            height: 64,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              final selected = states.contains(WidgetState.selected);
              return AppTypography.caption(
                color: selected ? tc.ctaBackground : tc.textSecondary,
              ).copyWith(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              );
            }),
            iconTheme: WidgetStateProperty.resolveWith((states) {
              final selected = states.contains(WidgetState.selected);
              return IconThemeData(
                size: 24,
                color: selected ? tc.ctaBackground : tc.textSecondary,
              );
            }),
          ),
          child: NavigationBar(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: _goBranch,
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.home_outlined),
                selectedIcon: const Icon(Icons.home_rounded),
                label: l10n?.navHome ?? 'Home',
              ),
              NavigationDestination(
                icon: const Icon(Icons.receipt_long_outlined),
                selectedIcon: const Icon(Icons.receipt_long_rounded),
                label: l10n?.navHistory ?? 'History',
              ),
              NavigationDestination(
                icon: const Icon(Icons.description_outlined),
                selectedIcon: const Icon(Icons.description_rounded),
                label: l10n?.navTemplates ?? 'Templates',
              ),
              NavigationDestination(
                icon: const Icon(Icons.settings_outlined),
                selectedIcon: const Icon(Icons.settings_rounded),
                label: l10n?.navSettings ?? 'Settings',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
