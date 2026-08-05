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
              color: Theme.of(context).colorScheme.onSurface,
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
    // Three-way control: System (follow device), Light, Dark. The
    // default is "System"; once the user picks Light/Dark the explicit
    // choice wins over the device's brightness on every subsequent
    // launch — only tapping System again hands control back to the OS.
    final controller = getIt<ThemeModeController>();
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final theme = Theme.of(context);
        final onSurface = theme.colorScheme.onSurface;
        final mode = controller.mode;
        IconData icon;
        String description;
        switch (mode) {
          case ThemeMode.dark:
            icon = Icons.dark_mode;
            description = 'Dark theme';
            break;
          case ThemeMode.light:
            icon = Icons.light_mode;
            description = 'Light theme';
            break;
          case ThemeMode.system:
            icon = Icons.brightness_auto;
            description = 'Follows your device setting';
            break;
        }

        return Container(
          margin: EdgeInsets.only(bottom: 1.h),
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
          color: theme.cardColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40.w,
                    height: 40.w,
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Icon(icon, color: theme.primaryColor, size: 22.sp),
                  ),
                  hSpace(16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Appearance',
                          style: TextStyle(
                            fontSize: 19.sp,
                            fontWeight: FontWeight.w600,
                            color: onSurface,
                          ),
                        ),
                        vSpace(4),
                        Text(
                          description,
                          style: TextStyle(
                            fontSize: 17.sp,
                            color: onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              vSpace(12),
              Row(
                children: [
                  _ThemeSegment(
                    label: 'System',
                    selected: mode == ThemeMode.system,
                    onTap: () => controller.setMode(ThemeMode.system),
                  ),
                  hSpace(8),
                  _ThemeSegment(
                    label: 'Light',
                    selected: mode == ThemeMode.light,
                    onTap: () => controller.setMode(ThemeMode.light),
                  ),
                  hSpace(8),
                  _ThemeSegment(
                    label: 'Dark',
                    selected: mode == ThemeMode.dark,
                    onTap: () => controller.setMode(ThemeMode.dark),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ThemeSegment extends StatelessWidget {
  const _ThemeSegment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10.r),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 10.h),
          decoration: BoxDecoration(
            color: selected
                ? theme.primaryColor
                : theme.colorScheme.onSurface.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(
              color: selected
                  ? theme.primaryColor
                  : theme.dividerColor,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 17.sp,
              fontWeight: FontWeight.w600,
              color: selected
                  ? Colors.white
                  : theme.colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
        ),
      ),
    );
  }
}

