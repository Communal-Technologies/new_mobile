import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/screens/account/widgets/setting_item.dart';
import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_event.dart';

class SupportSection extends StatelessWidget {
  const SupportSection({super.key});

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out? This will clear all your data.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              // Clear all storage and logout (onboarding flag is preserved in secure storage)
              context.read<AuthBloc>().add(LogoutRequested());
              
              // Clear SharedPreferences (onboarding flag is in secure storage, so it's safe)
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              
              // Navigate to login
              context.go('/login');
            },
            child: const Text('Log Out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Text(
            'Support',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F1D40),
            ),
          ),
        ),
        vSpace(12),
        SettingItem(
          icon: Icons.headphones,
          title: 'Help & FAQ',
          description: 'Get help and find answers',
          onTap: () {
            context.pushNamed('help-support');
          },
        ),
        SettingItem(
          icon: Icons.logout,
          title: 'Log Out',
          description: 'Sign out of your account',
          onTap: () {
            _showLogoutDialog(context);
          },
        ),
      ],
    );
  }
}

