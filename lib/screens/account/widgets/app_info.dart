import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:communal_mobile/core/update/app_update_service.dart';
import 'package:communal_mobile/core/widgets/app_toast.dart';
import 'package:communal_mobile/core/widgets/space.dart';

class AppInfo extends StatefulWidget {
  const AppInfo({super.key});

  @override
  State<AppInfo> createState() => _AppInfoState();
}

class _AppInfoState extends State<AppInfo> {
  // Read from the bundle rather than a literal: CI sets the version with
  // --build-name from the release tag, so a hardcoded string drifts from
  // whatever is actually on the store the moment the next build ships.
  late final Future<PackageInfo> _packageInfo = PackageInfo.fromPlatform();

  bool _checking = false;

  Future<void> _checkForUpdate() async {
    if (_checking) return;
    setState(() => _checking = true);
    try {
      final outcome = await AppUpdateService.check(userInitiated: true);
      if (!mounted) return;
      switch (outcome) {
        case AppUpdateOutcome.none:
          AppToast.success('You are on the latest version.');
        case AppUpdateOutcome.downloading:
          AppToast.success('An update is downloading in the background.');
        case AppUpdateOutcome.readyToInstall:
          AppToast.success('Update downloaded. Relaunch the app to finish.');
        case AppUpdateOutcome.storeUpdateAvailable:
          final opened = await AppUpdateService.openStore();
          if (!opened && mounted) {
            AppToast.error('Could not open the store. Please try again.');
          }
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 17.sp,
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
    );

    return Column(
      children: [
        FutureBuilder<PackageInfo>(
          future: _packageInfo,
          builder: (context, snapshot) {
            final version = snapshot.data?.version;
            return Text(
              version == null ? 'Communal' : 'Communal v$version',
              style: style,
            );
          },
        ),
        vSpace(8),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: _checking ? null : _checkForUpdate,
            child: Text(
              _checking ? 'Checking…' : 'Check for updates',
              style: style.copyWith(
                color: Theme.of(context).colorScheme.primary,
                decoration: TextDecoration.underline,
                decorationColor: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ),
        vSpace(8),
        Text(
          '© 2026 All rights reserved',
          style: style,
        ),
      ],
    );
  }
}
