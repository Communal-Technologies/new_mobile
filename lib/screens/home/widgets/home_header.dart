import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_state.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/screens/home/widgets/cooperative_header_badge.dart';
import 'package:go_router/go_router.dart';

class HomeHeader extends StatelessWidget {
  final GlobalKey<ScaffoldState> scaffoldKey;
  final ThemeData theme;

  const HomeHeader({
    super.key,
    required this.scaffoldKey,
    required this.theme,
  });

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

        final displayName = user?.name.isNotEmpty == true ? user!.name : 'Member';
        final roleLabel = user?.roleLabel ?? 'Member';
        final subtitle = user != null && user.login.isNotEmpty

            ? user.login
            : 'Welcome back';

        final avatar = user?.avatar;
        final ImageProvider<Object> avatarImage = (avatar != null &&
                (avatar.startsWith('http://') || avatar.startsWith('https://')))
            ? NetworkImage(avatar)
            : const AssetImage('assets/images/demo_user.png');

        return Container(
          padding:
              EdgeInsets.only(right: 16.w, top: 12.h, bottom: 12.h, left: 0),
          color: Colors.white,
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
                    child:
                        Icon(Icons.swap_horiz, color: Colors.white, size: 22.sp),
                  ),
                ),
              ),
              CooperativeHeaderBadge(user: user, theme: theme),
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
                              fontSize: 17.sp,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey.shade800,
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
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    vSpace(4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => context.pushNamed('notifications'),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(
                  Icons.notifications_outlined,
                  color: Colors.grey.shade700,
                  size: 28.sp,
                ),
              ),
              hSpace(12),
              InkWell(
                onTap: () {
                  context.pushNamed('my-profile');
                },
                borderRadius: BorderRadius.circular(22.w),
                child: CircleAvatar(
                  radius: 22.w,
                  backgroundColor: Colors.grey.shade300,
                  backgroundImage: avatarImage,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
