import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:iconsax/iconsax.dart';

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

    // Iconsax has a single linear set, so active vs inactive is
    // differentiated via colour + a tinted pill behind the active icon.
    final items = <_NavItem>[
      const _NavItem(index: 0, icon: Iconsax.home_2, label: 'Home'),
      if (hasCooperative)
        const _NavItem(index: 1, icon: Iconsax.empty_wallet, label: 'Obligations'),
      const _NavItem(index: 2, icon: Iconsax.profile_2user, label: 'Community'),
      if (hasCooperative)
        const _NavItem(index: 3, icon: Iconsax.chart_2, label: 'Loans'),
      const _NavItem(index: 4, icon: Iconsax.user, label: 'Account'),
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
    final isDark = theme.brightness == Brightness.dark;
    final activeColor = isDark ? Colors.white : theme.primaryColor;
    final inactiveColor = theme.colorScheme.onSurface.withValues(alpha: 0.55);

    return InkWell(
      onTap: () => onTap(item.index),
      borderRadius: BorderRadius.circular(16.r),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: isActive
                    ? activeColor.withValues(alpha: isDark ? 0.18 : 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(14.r),
              ),
              child: Icon(
                item.icon,
                color: isActive ? activeColor : inactiveColor,
                size: 28.sp,
              ),
            ),
            vSpace(4),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? activeColor : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.index,
    required this.icon,
    required this.label,
  });

  final int index;
  final IconData icon;
  final String label;
}
