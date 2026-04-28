import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:communal_mobile/core/widgets/space.dart';

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

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20.r),
          topRight: Radius.circular(20.r),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
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
            children: [
              _buildNavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home,
                label: 'Home',
                index: 0,
                theme: theme,
              ),
              _buildNavItem(
                icon: Icons.wallet_outlined,
                activeIcon: Icons.wallet,
                label: 'Obligations',
                index: 1,
                theme: theme,
              ),
              _buildNavItem(
                icon: Icons.people_outline,
                activeIcon: Icons.people,
                label: 'Community',
                index: 2,
                theme: theme,
              ),
              _buildNavItem(
                icon: Icons.trending_up_outlined,
                activeIcon: Icons.trending_up,
                label: 'Loans',
                index: 3,
                theme: theme,
              ),
              _buildNavItem(
                icon: Icons.settings_outlined,
                activeIcon: Icons.settings,
                label: 'Account',
                index: 4,
                theme: theme,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
    required ThemeData theme,
  }) {
    final isActive = currentIndex == index;

    return InkWell(
      onTap: () => onTap(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isActive ? activeIcon : icon,
            color: isActive ? theme.primaryColor : Colors.grey.shade600,
            size: 24.sp,
          ),
          vSpace(4),
          Text(
            label,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              color: isActive ? theme.primaryColor : Colors.grey.shade600,
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

