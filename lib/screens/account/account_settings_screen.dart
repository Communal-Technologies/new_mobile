import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:communal_mobile/core/widgets/bottom_nav_bar.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/screens/account/widgets/profile_card.dart';
import 'package:communal_mobile/screens/account/widgets/security_banner.dart';
import 'package:communal_mobile/screens/account/widgets/account_management_section.dart';
import 'package:communal_mobile/screens/account/widgets/settings_section.dart';
import 'package:communal_mobile/screens/account/widgets/support_section.dart';
import 'package:communal_mobile/screens/account/widgets/app_info.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  int _currentNavIndex = 4;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.menu, color: Colors.black),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Open menu')),
              );
            },
          ),
          title: Text(
            'Account Settings',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.settings, color: Colors.black),
              onPressed: () {},
            ),
          ],
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              const ProfileCard(),
              vSpace(16),
              const SecurityBanner(),
              vSpace(24),
              const AccountManagementSection(),
              vSpace(24),
              const SettingsSection(),
              vSpace(24),
              const SupportSection(),
              vSpace(24),
              const AppInfo(),
              vSpace(32),
            ],
          ),
        ),
        bottomNavigationBar: BottomNavBar(
          currentIndex: _currentNavIndex,
          onTap: (index) {
            if (index == _currentNavIndex) return;
            switch (index) {
              case 0:
                context.goNamed('home');
                break;
              case 1:
                context.goNamed('obligations');
                break;
              case 2:
                context.goNamed('community');
                break;
              case 3:
                context.goNamed('loans');
                break;
              default:
                setState(() => _currentNavIndex = index);
            }
          },
        ),
      ),
    );
  }
}
