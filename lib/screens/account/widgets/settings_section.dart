import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/screens/account/widgets/setting_item.dart';

class SettingsSection extends StatelessWidget {
  const SettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Text(
            'Settings',
            style: TextStyle(
              fontSize: 19.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F1D40),
            ),
          ),
        ),
        vSpace(12),
        SettingItem(
          icon: Icons.people,
          title: 'Community Settings',
          description: 'Manage cooperative preferences',
          onTap: () {
            context.pushNamed('community-settings');
          },
        ),
        SettingItem(
          icon: Icons.shield,
          title: 'Security Settings',
          description: 'Password, PIN, and security options',
          onTap: () {
            context.pushNamed('security-settings');
          },
        ),
        SettingItem(
          icon: Icons.notifications_outlined,
          title: 'Notification Settings',
          description: 'Push notifications and alerts',
          onTap: () {
            context.pushNamed('notification-settings');
          },
        ),
        _PreferenceItem(),
      ],
    );
  }
}

class _PreferenceItem extends StatefulWidget {
  @override
  State<_PreferenceItem> createState() => _PreferenceItemState();
}

class _PreferenceItemState extends State<_PreferenceItem> {
  bool _isDarkMode = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 1.h),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      color: Colors.white,
      child: Row(
        children: [
          Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(
              Icons.dark_mode_outlined,
              color: const Color(0xFF7434FF),
              size: 22.sp,
            ),
          ),
          hSpace(16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Preferences',
                  style: TextStyle(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0F1D40),
                  ),
                ),
                vSpace(4),
                Text(
                  'Toggle dark/light theme',
                  style: TextStyle(
                    fontSize: 15.sp,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _isDarkMode,
            onChanged: (value) {
              setState(() {
                _isDarkMode = value;
              });
            },
            activeThumbColor: const Color(0xFF7434FF),
          ),
        ],
      ),
    );
  }
}

