import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_event.dart';
import 'package:communal_mobile/blocs/auth/auth_state.dart';
import 'package:communal_mobile/core/navigation/root_navigator_key.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/data/models/user_model.dart';
import 'package:communal_mobile/data/repositories/community_repository.dart';
import 'package:communal_mobile/screens/community/widgets/join_community_invite_sheet.dart';

class CooperativeSidebar extends StatefulWidget {
  const CooperativeSidebar({super.key});

  @override
  State<CooperativeSidebar> createState() => _CooperativeSidebarState();
}

class _CooperativeSidebarState extends State<CooperativeSidebar> {
  void _openJoinCooperativeSheet(BuildContext drawerContext) {
    Navigator.of(drawerContext).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navCtx = rootNavigatorKey.currentContext;
      if (navCtx == null || !navCtx.mounted) return;
      showModalBottomSheet<CommunityJoinResult>(
        context: navCtx,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => const JoinCommunityInviteSheet(),
      ).then((result) {
        if (result == null) return;
        if (!navCtx.mounted) return;
        navCtx.read<AuthBloc>().add(AuthRefreshUserRequested());
        ScaffoldMessenger.of(navCtx).showSnackBar(
          SnackBar(
            content: Text(
              result.cooperativeName.isEmpty
                  ? 'You have joined the cooperative.'
                  : 'Welcome to ${result.cooperativeName}.',
            ),
          ),
        );
      });
    });
  }

  void _openSettings(BuildContext drawerContext) {
    Navigator.of(drawerContext).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navCtx = rootNavigatorKey.currentContext;
      if (navCtx == null || !navCtx.mounted) return;
      navCtx.pushNamed('account-settings');
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Drawer(
      width: 360.w,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
      ),
      child: Stack(
            children: [
              // Main content with SafeArea only for top
              SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 12.h),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Current Cooperative Card with Header inside
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color(0xFFE8E3FF), // Light lavender
                                Color(0xFFE0D9FF), // Slightly darker lavender
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12.r),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: BlocBuilder<AuthBloc, AuthState>(
                            buildWhen: (prev, next) {
                              final pu =
                                  prev is AuthAuthenticated ? prev.user : null;
                              final nu =
                                  next is AuthAuthenticated ? next.user : null;
                              return pu != nu;
                            },
                            builder: (context, authState) {
                              final user = authState is AuthAuthenticated
                                  ? authState.user
                                  : null;
                              final hasCoop =
                                  user?.hasCooperativeMembership ?? false;
                              final coopLabel =
                                  user?.cooperativeDisplayName ?? '—';
                              final ledger = user?.ledgerNumber ?? '';
                              final accountName =
                                  user?.name.isNotEmpty == true
                                      ? user!.name
                                      : (user?.login ?? 'Member');
                              final role = user?.roleLabel ?? 'Member';
                              final primaryTitle = hasCoop
                                  ? coopLabel
                                  : 'Not in a cooperative yet';
                              final secondaryLine =
                                  '$accountName · $role';

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Current Cooperative',
                                        style: TextStyle(
                                          fontSize: 19.sp,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey.shade800,
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () => Navigator.pop(context),
                                        child: Icon(
                                          Icons.close,
                                          color: Colors.grey.shade700,
                                          size: 22.sp,
                                        ),
                                      ),
                                    ],
                                  ),
                                  vSpace(8),
                                  Row(
                                    children: [
                                      Container(
                                        width: 44.w,
                                        height: 44.w,
                                        padding: EdgeInsets.all(5.w),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(8.r),
                                          border: Border.all(
                                            color: Colors.grey.shade300,
                                            width: 1,
                                          ),
                                        ),
                                        child: _cooperativeListThumb(
                                          user: user,
                                          theme: theme,
                                          hasCoop: hasCoop,
                                          coopLabel: coopLabel,
                                          ledger: ledger,
                                        ),
                                      ),
                                      hSpace(14),
                                      Expanded(
                                        child: Padding(
                                          padding: EdgeInsets.only(right: 20.w),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                primaryTitle,
                                                style: TextStyle(
                                                  fontSize: 17.sp,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.black,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              vSpace(2),
                                              Text(
                                                secondaryLine,
                                                style: TextStyle(
                                                  fontSize: 15.sp,
                                                  color: Colors.grey.shade700,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Icon(
                                        Icons.more_vert,
                                        color: Colors.grey.shade600,
                                        size: 22.sp,
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            },
                          ),
                        ),

                        vSpace(16),

                        // Other cooperatives (API-driven list not wired yet)
                        Text(
                          'Other cooperatives',
                          style: TextStyle(
                            fontSize: 17.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                        ),

                        vSpace(10),

                        Expanded(
                          child: ListView(
                            children: [
                              Padding(
                                padding: EdgeInsets.symmetric(vertical: 12.h),
                                child: Text(
                                  'You can use Communal without belonging to a cooperative. '
                                  'When you join one (or more) with an invite code, they will show here.',
                                  style: TextStyle(
                                    fontSize: 15.sp,
                                    height: 1.35,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        vSpace(12),

                        // Bottom Actions
                        _buildBottomAction(
                          icon: Icons.add_circle_outline,
                          label: 'Join with Invite Code',
                          onTap: () => _openJoinCooperativeSheet(context),
                        ),
                        vSpace(8),
                        _buildBottomAction(
                          icon: Icons.person_add_outlined,
                          label: 'Add Another Account',
                          onTap: () {},
                        ),
                        vSpace(8),
                        _buildBottomAction(
                          icon: Icons.settings_outlined,
                          label: 'Settings',
                          onTap: () => _openSettings(context),
                        ),

                        vSpace(8),
                      ],
                    ),
                  ),
                ),
            ],
          ),
    );
  }

  /// Matches home header: logo when URL is valid, else compact id + ledger text.
  Widget _cooperativeListThumb({
    required UserModel? user,
    required ThemeData theme,
    required bool hasCoop,
    required String coopLabel,
    required String ledger,
  }) {
    final logo = user?.cooperativeLogoUrl?.trim();
    final useNet = logo != null &&
        logo.isNotEmpty &&
        (logo.startsWith('http://') || logo.startsWith('https://'));

    if (!hasCoop && !useNet) {
      return Icon(
        Icons.groups_outlined,
        size: 26.sp,
        color: theme.primaryColor,
      );
    }

    if (useNet) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6.r),
        child: Image.network(
          logo,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _cooperativeThumbText(
            theme: theme,
            coopLabel: coopLabel,
            ledger: ledger,
          ),
        ),
      );
    }

    return _cooperativeThumbText(
      theme: theme,
      coopLabel: coopLabel,
      ledger: ledger,
    );
  }

  Widget _cooperativeThumbText({
    required ThemeData theme,
    required String coopLabel,
    required String ledger,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          coopLabel,
          style: TextStyle(
            fontSize: 7.sp,
            fontWeight: FontWeight.w700,
            color: theme.primaryColor,
            height: 1.0,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        if (ledger.isNotEmpty) ...[
          SizedBox(height: 1.h),
          Text(
            ledger,
            style: TextStyle(
              fontSize: 5.5.sp,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
              height: 1.0,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget _buildBottomAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8.r),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 4.w),
          child: Row(
            children: [
              Icon(
                icon,
                size: 22.sp,
                color: Colors.grey.shade700,
              ),
              hSpace(12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
