import 'package:flutter/material.dart';
import 'package:communal_mobile/core/utils/system_ui_style.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:communal_mobile/core/widgets/bottom_nav_bar.dart';
import 'package:communal_mobile/core/widgets/cooperative_sidebar.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/screens/account/widgets/profile_card.dart';
// TODO(communal-mobile): re-enable security_banner once the
// "Security Check" screen + status checks are implemented end-to-end.
// import 'package:communal_mobile/screens/account/widgets/security_banner.dart';
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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemOverlayForTheme(Theme.of(context)),
      child: Scaffold(
        key: _scaffoldKey,
        // Theme-driven background + AppBar — flip cleanly with the
        // dark/light toggle (see AppTheme).
        drawer: const CooperativeSidebar(),
        drawerEdgeDragWidth: 50.w,
        drawerScrimColor: Colors.black.withValues(alpha: 0.4),
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              _scaffoldKey.currentState?.openDrawer();
            },
          ),
          title: Text(
            'Account Settings',
            style: TextStyle(
              fontSize: 21.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              const ProfileCard(),
              vSpace(16),
              // TODO(communal-mobile): re-enable Security Check banner
              // when the underlying checks (linked devices, recent
              // logins, suspicious-activity feed) are wired up.
              // const SecurityBanner(),
              // vSpace(24),
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
