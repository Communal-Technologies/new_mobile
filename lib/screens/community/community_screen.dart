import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:communal_mobile/core/widgets/bottom_nav_bar.dart';
import 'package:communal_mobile/core/widgets/space.dart';
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
        backgroundColor: const Color(0xFFF2F2F5),
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
                    fontSize: 18.sp,
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
    final inviteCode = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const JoinCommunityInviteSheet(),
    );

    if (!mounted || inviteCode == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Invite code submitted: $inviteCode')),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.menu, color: Colors.black),
          onPressed: () {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Open menu')));
          },
        ),
        Expanded(
          child: Text(
            'Communities',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20.sp,
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
