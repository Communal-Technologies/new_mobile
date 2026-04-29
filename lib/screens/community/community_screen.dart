import 'package:flutter/material.dart';
import 'package:communal_mobile/core/utils/system_ui_style.dart';
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
import 'package:communal_mobile/data/repositories/community_settings_repository.dart';
import 'package:communal_mobile/injection.dart';
import 'package:communal_mobile/screens/community/data/sample_communities.dart';
import 'package:communal_mobile/screens/community/data/sample_community_locations.dart';
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
  String? _activeCommunityId;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late Future<List<Community>> _communitiesFuture;
  // Pending join requests survive across app reload — without this, a
  // user who submitted a request, closed the app, and reopened it
  // would have no surface to see their pending state and might
  // re-submit (the backend already 409s, but the UX is bad).
  List<CommunityJoinRequest> _pendingRequests = const [];

  @override
  void initState() {
    super.initState();
    _communitiesFuture = _loadMemberships();
    _refreshPendingRequests();
  }

  Future<List<Community>> _loadMemberships() async {
    final memberships =
        await getIt<CommunitySettingsRepository>().fetchMemberships();
    return memberships.map((m) => Community.fromMembership(m)).toList();
  }

  Future<void> _refreshPendingRequests() async {
    try {
      final all = await getIt<CommunityRepository>().fetchMyJoinRequests();
      if (!mounted) return;
      setState(() {
        _pendingRequests = all
            .where((r) => r.status == JoinRequestStatus.pending)
            .toList();
      });
    } catch (_) {
      // Pending banner is a hint — silent failure is fine; the join
      // sheet's own backend 409 still gates the duplicate-submit case.
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _communitiesFuture = _loadMemberships();
    });
    await Future.wait([
      _communitiesFuture,
      _refreshPendingRequests(),
    ]);
  }

  /// Resolve a real CommunityLocation for [cooperativeId] (the user's
  /// "Your Communities" tiles store membership-side data, not a full
  /// PublicCooperative — the detail screen needs the latter), then
  /// push the detail screen.
  Future<void> _openCooperativeDetails(String cooperativeId) async {
    try {
      final coop = await getIt<CommunityRepository>()
          .fetchCooperativeProfile(cooperativeId);
      if (!mounted) return;
      final location = CommunityLocation.fromPublicCooperative(coop);
      // ignore: unawaited_futures
      context.pushNamed('community-detail', extra: location);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  Future<void> _openPendingStatus(CommunityJoinRequest req) async {
    try {
      final coop = await getIt<CommunityRepository>()
          .fetchCooperativeProfile(req.cooperativeId);
      if (!mounted) return;
      final location = CommunityLocation.fromPublicCooperative(coop);
      // ignore: unawaited_futures
      context.pushNamed('community-application-status', extra: location);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemOverlayForTheme(Theme.of(context)),
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: const Color(0xFFF2F2F5),
        drawer: const CooperativeSidebar(),
        drawerEdgeDragWidth: 50.w,
        drawerScrimColor: Colors.black.withValues(alpha: 0.4),
        body: SafeArea(
          child: FutureBuilder<List<Community>>(
            future: _communitiesFuture,
            builder: (context, snapshot) {
              return RefreshIndicator(
                onRefresh: _refresh,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 16.h,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTopBar(),
                      vSpace(20),
                      ..._buildBody(snapshot),
                      if (_pendingRequests.isNotEmpty) ...[
                        vSpace(16),
                        ..._pendingRequests.map(_buildPendingBanner),
                      ],
                      vSpace(24),
                      FindNearbyCard(
                        onTap: () => context.pushNamed('community-map'),
                      ),
                      vSpace(32),
                    ],
                  ),
                ),
              );
            },
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
    // bottom nav, quick actions, and sidebar re-evaluate, and reload
    // memberships so the new cooperative appears in this list.
    context.read<AuthBloc>().add(AuthRefreshUserRequested());
    setState(() {
      _communitiesFuture = _loadMemberships();
    });
    // ignore: unawaited_futures
    _refreshPendingRequests();
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

  List<Widget> _buildBody(AsyncSnapshot<List<Community>> snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 48.h),
          child: const Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (snapshot.hasError) {
      return [
        Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: const Color(0xFFFDECEA),
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: Text(
            snapshot.error.toString().replaceFirst('Exception: ', ''),
            style: TextStyle(
              fontSize: 14.sp,
              color: const Color(0xFFB42318),
            ),
          ),
        ),
      ];
    }
    final communities = snapshot.data ?? const <Community>[];
    if (communities.isEmpty) {
      return [_buildEmptyState()];
    }
    final featured = communities.firstWhere(
      (c) => c.isFeatured,
      orElse: () => communities.first,
    );
    _activeCommunityId ??= featured.id;
    return [
      FeaturedCommunityCard(
        community: featured,
        // Open Chat is hidden inside FeaturedCommunityCard with a TODO
        // until in-app chat ships. Callback is left wired so we don't
        // have to thread state through if/when it returns.
        onOpenChat: () => _showComingSoon('Open chat'),
        onViewCommunity: () => _openCooperativeDetails(featured.id),
      ),
      vSpace(24),
      Text(
        'Your Communities',
        style: TextStyle(
          fontSize: 19.sp,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      vSpace(12),
      ...communities.map(
        (community) => CommunityTile(
          community: community,
          isActive: community.id == _activeCommunityId,
          onSelect: () => setState(() => _activeCommunityId = community.id),
        ),
      ),
    ];
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F4FF),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: const Color(0xFFE2D2FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40.w,
                height: 40.w,
                decoration: const BoxDecoration(
                  color: Color(0xFF7434FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.group_add,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              hSpace(12),
              Expanded(
                child: Text(
                  'You haven\'t joined a cooperative yet',
                  style: TextStyle(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF3F2B8F),
                  ),
                ),
              ),
            ],
          ),
          vSpace(8),
          Text(
            'Tap “Find Nearby” below to discover open cooperatives, '
            'or use the + button to redeem an invite code from an admin.',
            style: TextStyle(
              fontSize: 15.sp,
              color: const Color(0xFF4D3C8A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingBanner(CommunityJoinRequest request) {
    final coopName = request.cooperativeName.trim().isNotEmpty
        ? request.cooperativeName
        : 'a cooperative';
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: GestureDetector(
        onTap: () => _openPendingStatus(request),
        child: Container(
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF4E9),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: const Color(0xFFFFD2B0)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.schedule,
                color: Color(0xFFEE7B00),
              ),
              hSpace(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Application pending',
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF9A4F00),
                      ),
                    ),
                    vSpace(2),
                    Text(
                      'Your request to join $coopName is awaiting admin review.',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: const Color(0xFF9A4F00),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: Color(0xFF9A4F00),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.menu),
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
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        // TODO(communal-mobile): re-enable the top-right location
        // icon once it has a real action wired (likely "open
        // community map at your current location"). Hidden until
        // then so it doesn't read as a no-op tap target.
        // IconButton(
        //   icon: const Icon(Icons.location_on_outlined),
        //   onPressed: () {},
        // ),
        SizedBox(width: 48.w),
      ],
    );
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$feature is coming soon')));
  }
}
