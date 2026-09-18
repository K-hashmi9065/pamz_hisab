import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_text_styles.dart';
import 'route_paths.dart';

/// iPad adaptive shell: 3-pane (sidebar + master + detail) on wide screens,
/// collapsed NavigationRail drawer on narrow screens (< breakpoint).
class AdaptiveShell extends StatefulWidget {
  const AdaptiveShell({super.key, required this.child});
  final Widget child;

  @override
  State<AdaptiveShell> createState() => _AdaptiveShellState();
}

class _AdaptiveShellState extends State<AdaptiveShell> {
  int _selectedIndex = 0;

  static const _navItems = [
    _NavItem(
      icon: Icons.dashboard_rounded,
      label: 'Dashboard',
      path: RoutePaths.dashboard,
    ),
    _NavItem(
      icon: Icons.handshake_rounded,
      label: 'Udhar Khata',
      path: RoutePaths.udharList,
    ),
    _NavItem(
      icon: Icons.people_rounded,
      label: 'Family',
      path: RoutePaths.familyFinance,
    ),
    _NavItem(
      icon: Icons.bar_chart_rounded,
      label: 'Reports',
      path: RoutePaths.reports,
    ),
    _NavItem(
      icon: Icons.menu_book_rounded,
      label: 'User Guide',
      path: RoutePaths.userGuide,
    ),
    _NavItem(
      icon: Icons.settings_rounded,
      label: 'Settings',
      path: RoutePaths.settings,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= AppConstants.tabletBreakpoint;

    // Synchronize selected navigation rail index with active route path
    final location = GoRouterState.of(context).matchedLocation;
    for (int i = 0; i < _navItems.length; i++) {
      if (location.startsWith(_navItems[i].path)) {
        _selectedIndex = i;
        break;
      }
    }

    return Scaffold(
      body: Row(
        children: [
          _buildNavRail(isWide),
          VerticalDivider(
            width: 1,
            thickness: 1,
            color: Theme.of(context).dividerColor,
          ),
          Expanded(child: widget.child),
        ],
      ),
    );
  }

  Widget _buildNavRail(bool isWide) {
    return NavigationRail(
      extended: isWide,
      minWidth: AppSpacing.sidebarWidth,
      minExtendedWidth: AppSpacing.sidebarExpandedWidth,
      selectedIndex: _selectedIndex,
      onDestinationSelected: (i) {
        setState(() => _selectedIndex = i);
        context.go(_navItems[i].path);
      },
      backgroundColor: AppColors.sidebarBackground,
      leading: Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.lg.h),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: const Icon(
                Icons.account_balance_wallet_rounded,
                color: AppColors.onPrimary,
              ),
            ),
            if (isWide) ...[
              SizedBox(height: AppSpacing.sm.h),
              Text(
                'PAMZ Hisab',
                style: AppTextStyles.navLabel.copyWith(
                  color: AppColors.onPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
      destinations: _navItems
          .map(
            (item) => NavigationRailDestination(
              icon: Icon(item.icon),
              selectedIcon: Icon(item.icon),
              label: Text(item.label),
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xs.h),
            ),
          )
          .toList(),
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.path,
  });
  final IconData icon;
  final String label;
  final String path;
}
