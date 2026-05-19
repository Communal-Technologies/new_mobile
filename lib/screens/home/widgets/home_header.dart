import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_state.dart';
import 'package:communal_mobile/core/services/unread_notifications_service.dart';
import 'package:communal_mobile/core/widgets/member_avatar.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/injection.dart';
import 'package:communal_mobile/screens/home/widgets/cooperative_header_badge.dart';
import 'package:go_router/go_router.dart';

/// Bell button on the home header. Renders a small red dot in the
/// top-right when the unread count > 0. The count itself is held in
/// [UnreadNotificationsService] so any other surface can reuse the
/// same source of truth without a poll.
class _NotificationBell extends StatefulWidget {
  const _NotificationBell({required this.onSurface});

  final Color onSurface;

  @override
  State<_NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<_NotificationBell> {
  late final UnreadNotificationsService _unread;

  @override
  void initState() {
    super.initState();
    _unread = getIt<UnreadNotificationsService>();
    // Refresh on first paint — also catches the cold-start case
    // when the home screen is the first authenticated surface.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => unawaited(_unread.refresh()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: _unread.count,
      builder: (context, count, _) {
        return IconButton(
          onPressed: () async {
            await context.pushNamed('notifications');
            // Reconcile after the user comes back — they may have
            // marked rows read on the Notifications screen.
            unawaited(_unread.refresh());
          },
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                Icons.notifications,
                color: widget.onSurface.withValues(alpha: 0.85),
                size: 28.sp,
              ),
              if (count > 0)
                Positioned(
                  top: -1,
                  right: -1,
                  child: Container(
                    width: 10.sp,
                    height: 10.sp,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE53935),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class HomeHeader extends StatelessWidget {
  final GlobalKey<ScaffoldState> scaffoldKey;
  final ThemeData theme;

  const HomeHeader({super.key, required this.scaffoldKey, required this.theme});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      buildWhen: (prev, next) {
        final pu = prev is AuthAuthenticated ? prev.user : null;
        final nu = next is AuthAuthenticated ? next.user : null;
        return pu != nu;
      },
      builder: (context, authState) {
        final user = authState is AuthAuthenticated ? authState.user : null;

        final displayName = user?.name.isNotEmpty == true
            ? user!.name
            : 'Member';
        final roleLabel = user?.roleLabel ?? 'Member';
        final subtitle = user != null && user.login.isNotEmpty
            ? user.login
            : 'Welcome back';

        final avatar = user?.avatar;
        final onSurface = theme.colorScheme.onSurface;
        return Container(
          padding: EdgeInsets.only(
            right: 16.w,
            top: 12.h,
            bottom: 12.h,
            left: 0,
          ),
          color: theme.cardColor,
          child: Row(
            children: [
              InkWell(
                onTap: () {
                  scaffoldKey.currentState?.openDrawer();
                },
                child: Container(
                  width: 40.w,
                  height: 40.w,
                  margin: EdgeInsets.only(right: 8.w),
                  decoration: BoxDecoration(
                    color: theme.primaryColor,
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(20.r),
                      bottomRight: Radius.circular(20.r),
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.swap_horiz,
                      color: Colors.white,
                      size: 22.sp,
                    ),
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 110.w),
                child: CooperativeHeaderBadge(user: user, theme: theme),
              ),
              hSpace(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            displayName,
                            style: TextStyle(
                              fontSize: 19.sp,
                              fontWeight: FontWeight.w700,
                              color: onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        hSpace(8),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10.w,
                            vertical: 4.h,
                          ),
                          decoration: BoxDecoration(
                            color: theme.primaryColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: Text(
                            roleLabel,
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                              color: theme.primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    vSpace(4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 16.sp,
                        color: onSurface.withValues(alpha: 0.6),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              _NotificationBell(onSurface: onSurface),
              hSpace(12),
              InkWell(
                onTap: () {
                  context.pushNamed('my-profile');
                },
                borderRadius: BorderRadius.circular(22.w),
                child: MemberAvatar(
                  url: avatar,
                  radius: 22.w,
                  backgroundColor: theme.dividerColor,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
