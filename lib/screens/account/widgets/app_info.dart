import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:package_info_plus/package_info_plus.dart';
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
        Text(
          '© 2026 All rights reserved',
          style: style,
        ),
      ],
    );
  }
}
