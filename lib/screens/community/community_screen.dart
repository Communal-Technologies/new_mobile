import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_event.dart';
import 'package:communal_mobile/core/widgets/bottom_nav_bar.dart';
import 'package:communal_mobile/core/widgets/cooperative_sidebar.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/data/repositories/community_repository.dart';
import 'package:communal_mobile/screens/community/data/sample_communities.dart';
import 'package:communal_mobile/screens/community/widgets/community_tile.dart';
import 'package:communal_mobile/screens/community/widgets/featured_community_card.dart';
import 'package:communal_mobile/screens/community/widgets/find_nearby_card.dart';
import 'package:communal_mobile/screens/community/widgets/join_community_invite_sheet.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  int _currentIndex = 2;
  late String _activeCommunityId;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _activeCommunityId = SampleCommunities.all.first.id;
  }

  @override
  Widget build(BuildContext context) {
    final featured = SampleCommunities.featured;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: const Color(0xFFF2F2F5),
        drawer: const CooperativeSidebar(),
        drawerEdgeDragWidth: 50.w,
        drawerScrimColor: Colors.black.withValues(alpha: 0.4),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTopBar(),
                vSpace(20),
                FeaturedCommunityCard(
                  community: featured,
                  onOpenChat: () => _showComingSoon('Open chat'),
                  onViewCommunity: () => _showComingSoon('View cooperative'),
                ),
                vSpace(24),
                Text(
                  'Your Communities',
                  style: TextStyle(
                    fontSize: 19.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
                vSpace(12),
                ...SampleCommunities.all.map(
                  (community) => CommunityTile(
                    community: community,
                    isActive: community.id == _activeCommunityId,
                    onSelect: () =>
                        setState(() => _activeCommunityId = community.id),
                  ),
                ),
                vSpace(24),
                FindNearbyCard(onTap: () => context.pushNamed('community-map')),
                vSpace(32),
              ],
            ),
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        floatingActionButton: FloatingActionButton(
          shape: const CircleBorder(),
          backgroundColor: const Color(0xFF7434FF),
          onPressed: _showJoinCommunitySheet,
          child: const Icon(Icons.add, color: Colors.white),
        ),
        bottomNavigationBar: BottomNavBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            if (index == _currentIndex) return;
            switch (index) {
              case 0:
                context.goNamed('home');
                break;
              case 1:
                context.goNamed('obligations');
                break;
              case 3:
                context.goNamed('loans');
                break;
              case 4:
                context.goNamed('account-settings');
                break;
              default:
                setState(() => _currentIndex = index);
            }
          },
        ),
      ),
    );
  }

  Future<void> _showJoinCommunitySheet() async {
    final result = await showModalBottomSheet<CommunityJoinResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const JoinCommunityInviteSheet(),
    );

    if (!mounted || result == null) return;
    // Refresh user identity so hasCooperativeMembership flips and the
    // bottom nav, quick actions, and sidebar re-evaluate.
    context.read<AuthBloc>().add(AuthRefreshUserRequested());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.cooperativeName.isEmpty
              ? 'You have joined the cooperative.'
              : 'Welcome to ${result.cooperativeName}.',
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.menu, color: Colors.black),
          onPressed: () {
            _scaffoldKey.currentState?.openDrawer();
          },
        ),
        Expanded(
          child: Text(
            'Communities',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22.sp,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.location_on_outlined, color: Colors.black),
          onPressed: () {},
        ),
      ],
    );
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$feature is coming soon')));
  }
}
