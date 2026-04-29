import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_state.dart';
import 'package:communal_mobile/core/widgets/space.dart';

/// App-wide bottom navigation. Indices are stable across the app:
///
/// - 0 = Home
/// - 1 = Obligations *(cooperative members only)*
/// - 2 = Community
/// - 3 = Loans *(cooperative members only)*
/// - 4 = Account
///
/// The two cooperative-only items are filtered out when the signed-in
/// user has no `cooperativeId`. Indices are NOT renumbered — every
/// caller still passes its own stable index — so a non-coop user who
/// happens to be on a screen that reports `currentIndex: 1` (e.g. an
/// obligation detail reached via deep link before the router gate
/// kicked in) simply won't see any tab as active, and the tap handler
/// can ignore the missing indices.
class BottomNavBar extends StatelessWidget {
  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Read the auth state once. We use `watch` so the bar rebuilds when
    // the user joins / leaves a cooperative without a manual refresh.
    final authState = context.watch<AuthBloc>().state;
    final hasCooperative = authState is AuthAuthenticated
        ? authState.user.hasCooperativeMembership
        : false;

    final items = <_NavItem>[
      const _NavItem(
        index: 0,
        icon: Icons.home_outlined,
        activeIcon: Icons.home,
        label: 'Home',
      ),
      if (hasCooperative)
        const _NavItem(
          index: 1,
          icon: Icons.wallet_outlined,
          activeIcon: Icons.wallet,
          label: 'Obligations',
        ),
      const _NavItem(
        index: 2,
        icon: Icons.people_outline,
        activeIcon: Icons.people,
        label: 'Community',
      ),
      if (hasCooperative)
        const _NavItem(
          index: 3,
          icon: Icons.trending_up_outlined,
          activeIcon: Icons.trending_up,
          label: 'Loans',
        ),
      const _NavItem(
        index: 4,
        icon: Icons.settings_outlined,
        activeIcon: Icons.settings,
        label: 'Account',
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20.r),
          topRight: Radius.circular(20.r),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 12.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: items
                .map((item) => _buildNavItem(item: item, theme: theme))
                .toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required _NavItem item,
    required ThemeData theme,
  }) {
    final isActive = currentIndex == item.index;
    final inactiveColor = theme.colorScheme.onSurface.withValues(alpha: 0.6);

    return InkWell(
      onTap: () => onTap(item.index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isActive ? item.activeIcon : item.icon,
            color: isActive ? theme.primaryColor : inactiveColor,
            size: 24.sp,
          ),
          vSpace(4),
          Text(
            item.label,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              color: isActive ? theme.primaryColor : inactiveColor,
            ),
          ),
          if (isActive) ...[
            vSpace(4),
            Container(
              width: 20.w,
              height: 3.h,
              decoration: BoxDecoration(
                color: theme.primaryColor,
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.index,
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final int index;
  final IconData icon;
  final IconData activeIcon;
  final String label;
}
