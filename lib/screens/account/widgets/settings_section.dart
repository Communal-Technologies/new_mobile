import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_state.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/data/local/theme_mode_controller.dart';
import 'package:communal_mobile/injection.dart';
import 'package:communal_mobile/screens/account/widgets/setting_item.dart';

class SettingsSection extends StatelessWidget {
  const SettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    // Community Settings only makes sense for users that actually
    // belong to a cooperative — non-coop members would see an empty
    // surface (their per-membership prefs simply don't exist).
    final auth = context.watch<AuthBloc>().state;
    final showCommunitySettings = auth is AuthAuthenticated &&
        auth.user.hasCooperativeMembership;

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
        if (showCommunitySettings)
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

class _PreferenceItem extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Reads through the shared ThemeModeController so the switch value
    // matches the live theme on first paint and stays in sync if the
    // mode is changed elsewhere (e.g. system-mode auto-flip in future).
    final controller = getIt<ThemeModeController>();
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
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
                  controller.isDarkMode
                      ? Icons.dark_mode
                      : Icons.dark_mode_outlined,
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
                      controller.isDarkMode
                          ? 'Dark theme is on'
                          : 'Toggle dark/light theme',
                      style: TextStyle(
                        fontSize: 15.sp,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: controller.isDarkMode,
                onChanged: (value) {
                  controller.setDarkMode(value);
                },
                activeThumbColor: const Color(0xFF7434FF),
              ),
            ],
          ),
        );
      },
    );
  }
}

