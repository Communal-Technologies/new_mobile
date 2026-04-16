import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:communal_mobile/core/widgets/space.dart';

class CooperativeSidebar extends StatefulWidget {
  const CooperativeSidebar({super.key});

  @override
  State<CooperativeSidebar> createState() => _CooperativeSidebarState();
}

class _CooperativeSidebarState extends State<CooperativeSidebar> {
  int? _expandedIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Drawer(
      width: 360.w,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
      ),
      child: Stack(
            children: [
              // Main content with SafeArea only for top
              SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 12.h),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Current Cooperative Card with Header inside
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color(0xFFE8E3FF), // Light lavender
                                Color(0xFFE0D9FF), // Slightly darker lavender
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12.r),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header with X button
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Current Cooperative',
                                    style: TextStyle(
                                      fontSize: 18.sp,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => Navigator.pop(context),
                                    child: Icon(
                                      Icons.close,
                                      color: Colors.grey.shade700,
                                      size: 22.sp,
                                    ),
                                  ),
                                ],
                              ),

                              vSpace(8),

                              // Cooperative Info
                              Row(
                                children: [
                                  // Logo - White rounded rectangle
                                  Container(
                                    width: 44.w,
                                    height: 44.w,
                                    padding: EdgeInsets.all(5.w),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8.r),
                                      border: Border.all(
                                        color: Colors.grey.shade300,
                                        width: 1,
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'ExxonMobil',
                                          style: TextStyle(
                                            fontSize: 7.5.sp,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.red,
                                            height: 1.0,
                                          ),
                                        ),
                                        SizedBox(height: 1.h),
                                        Text(
                                          'Bullion Crib',
                                          style: TextStyle(
                                            fontSize: 6.sp,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF1976D2),
                                            height: 1.0,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  hSpace(14),
                                  Expanded(
                                    child: Padding(
                                      padding: EdgeInsets.only(right: 20.w),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Exxon Bullion Crib',
                                            style: TextStyle(
                                              fontSize: 15.sp,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.black,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          vSpace(2),
                                          Text(
                                            'Member',
                                            style: TextStyle(
                                              fontSize: 13.sp,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.more_vert,
                                    color: Colors.grey.shade600,
                                    size: 22.sp,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        vSpace(16),

                        // Other Cooperatives Header
                        Text(
                          'Other Cooperatives (4)',
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                        ),

                        vSpace(10),

                        // Cooperatives List
                        Expanded(
                          child: ListView.separated(
                            itemCount: 4,
                            separatorBuilder: (context, index) => vSpace(6),
                            itemBuilder: (context, index) {
                              return _buildCooperativeItem(
                                index: index,
                                theme: theme,
                              );
                            },
                          ),
                        ),

                        vSpace(12),

                        // Bottom Actions
                        _buildBottomAction(
                          icon: Icons.add_circle_outline,
                          label: 'Join with Invite Code',
                          onTap: () {},
                        ),
                        vSpace(8),
                        _buildBottomAction(
                          icon: Icons.person_add_outlined,
                          label: 'Add Another Account',
                          onTap: () {},
                        ),
                        vSpace(8),
                        _buildBottomAction(
                          icon: Icons.settings_outlined,
                          label: 'Settings',
                          onTap: () {},
                        ),

                        vSpace(8),
                      ],
                    ),
                  ),
                ),

              // Floating dropdown menu
              if (_expandedIndex != null)
                Positioned(
                  right: 20.w,
                  top: 240.h + (_expandedIndex! * 60.h),
                  child: _buildFloatingDropdown(theme),
                ),
            ],
          ),
    );
  }

  Widget _buildCooperativeItem({
    required int index,
    required ThemeData theme,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          // Switch to this cooperative
          Navigator.pop(context);
          // TODO: Switch cooperative logic
        },
        borderRadius: BorderRadius.circular(12.r),
        child: Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Logo - White rounded rectangle
              Container(
                width: 38.w,
                height: 38.w,
                padding: EdgeInsets.all(4.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(
                    color: Colors.grey.shade300,
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'ExxonMobil',
                      style: TextStyle(
                        fontSize: 7.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.red,
                        height: 1.0,
                      ),
                    ),
                    SizedBox(height: 0.5.h),
                    Text(
                      'Bullion Crib',
                      style: TextStyle(
                        fontSize: 5.5.sp,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1976D2),
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              hSpace(14),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: 20.w),
                  child: Text(
                    'Market Women Association',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _expandedIndex = _expandedIndex == index ? null : index;
                  });
                },
                child: Icon(
                  Icons.more_vert,
                  color: Colors.grey.shade600,
                  size: 22.sp,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingDropdown(ThemeData theme) {
    return Container(
      width: 200.w,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDropdownItem(
            icon: Icons.person_add_outlined,
            label: 'Invite members',
            onTap: () {
              setState(() => _expandedIndex = null);
            },
          ),
          _buildDropdownItem(
            icon: Icons.link,
            label: 'Copy Link',
            onTap: () {
              setState(() => _expandedIndex = null);
            },
          ),
          _buildDropdownItem(
            icon: Icons.visibility_outlined,
            label: 'View Cooperative',
            onTap: () {
              setState(() => _expandedIndex = null);
            },
          ),
          _buildDropdownItem(
            icon: Icons.logout,
            label: 'Logout',
            onTap: () {
              setState(() => _expandedIndex = null);
            },
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isLast = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
          decoration: BoxDecoration(
            border: !isLast
                ? Border(
                    bottom: BorderSide(
                      color: Colors.grey.shade200,
                      width: 1,
                    ),
                  )
                : null,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18.sp,
                color: Colors.grey.shade700,
              ),
              hSpace(12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8.r),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 4.w),
          child: Row(
            children: [
              Icon(
                icon,
                size: 22.sp,
                color: Colors.grey.shade700,
              ),
              hSpace(12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
