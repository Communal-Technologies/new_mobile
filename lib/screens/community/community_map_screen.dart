import 'dart:async';

import 'package:flutter/material.dart';
import 'package:communal_mobile/core/widgets/back_to_exit_wrapper.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:go_router/go_router.dart';

import 'package:communal_mobile/core/widgets/bottom_nav_bar.dart';
import 'package:communal_mobile/core/widgets/bottomsheet_handlebar.dart';
import 'package:communal_mobile/core/widgets/cooperative_sidebar.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/data/models/community_membership_model.dart';
import 'package:communal_mobile/data/repositories/community_repository.dart';
import 'package:communal_mobile/data/repositories/community_settings_repository.dart';
import 'package:communal_mobile/injection.dart';
import 'package:communal_mobile/screens/community/community_map/community_card.dart';
import 'package:communal_mobile/screens/community/community_map/join_community_bottom_sheet.dart';
import 'package:communal_mobile/screens/community/data/sample_community_locations.dart';

class CommunityMapScreen extends StatefulWidget {
  const CommunityMapScreen({super.key});

  @override
  State<CommunityMapScreen> createState() => _CommunityMapScreenState();
}

class _CommunityMapScreenState extends State<CommunityMapScreen> {
  final Completer<GoogleMapController> _mapController = Completer();
  final TextEditingController _searchController = TextEditingController();
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  String _searchQuery = '';
  String? _selectedCommunityId;
  int _currentIndex = 2;
  bool _isSheetExpanded = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Live cooperative list loaded from /fetch-cooperatives. Empty until
  // the first fetch completes; failure surfaces via [_loadError] so we
  // can show an inline retry on the bottom sheet.
  List<CommunityLocation> _communities = const [];
  bool _loading = true;
  String? _loadError;

  /// cooperative_ids the signed-in user already belongs to. Used to
  /// suppress the Join CTA on the corresponding cards.
  Set<String> _memberCooperativeIds = const <String>{};

  static const double _collapsedSheetSize = 0.34;
  static const double _expandedSheetSize = 0.82;

  /// Fallback camera centre when the device location isn't known and no
  /// cooperative has coordinates yet — keeps the map from opening on
  /// the equator.
  static const LatLng _fallbackCenter = LatLng(6.5244, 3.3792);

  @override
  void initState() {
    super.initState();
    _sheetController.addListener(_handleSheetExtentChange);
    _loadCooperatives();
  }

  @override
  void dispose() {
    _sheetController.removeListener(_handleSheetExtentChange);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCooperatives() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      // Fan-out fetches in parallel — the user's memberships and the
      // public cooperatives list are independent. Failure on the
      // memberships side is non-fatal: we just don't dim Join CTAs
      // for already-joined coops, and the backend's 409 still gates
      // the actual submit.
      final results = await Future.wait<dynamic>([
        getIt<CommunityRepository>().fetchPublicCooperatives(),
        getIt<CommunitySettingsRepository>().fetchMemberships().catchError(
          (_) => const <CommunityMembership>[],
        ),
      ]);
      if (!mounted) return;
      final coops = results[0] as List;
      final memberships = results[1] as List;
      final mapped = coops
          .map((c) => CommunityLocation.fromPublicCooperative(c))
          .toList();
      final memberIds = <String>{
        for (final m in memberships)
          if (m.cooperativeId is String &&
              (m.cooperativeId as String).isNotEmpty)
            m.cooperativeId as String,
      };
      setState(() {
        _communities = mapped;
        _memberCooperativeIds = memberIds;
        _loading = false;
        // Default selection: first featured, else the first with
        // coordinates so the featured banner has something to show.
        _selectedCommunityId = _pickInitialSelection(mapped);
      });
      // If we picked something with real coordinates, animate the map
      // there once it's ready.
      if (_selectedCommunityId != null) {
        final selected = mapped.firstWhere(
          (c) => c.id == _selectedCommunityId,
          orElse: () => mapped.first,
        );
        if (selected.hasCoordinate) {
          unawaited(_focusOnCommunity(selected));
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  String? _pickInitialSelection(List<CommunityLocation> list) {
    if (list.isEmpty) return null;
    final featured = list.firstWhere(
      (c) => c.isFeatured,
      orElse: () =>
          list.firstWhere((c) => c.hasCoordinate, orElse: () => list.first),
    );
    return featured.id;
  }

  void _handleSheetExtentChange() {
    final isExpanded =
        _sheetController.size > (_collapsedSheetSize + _expandedSheetSize) / 2;
    if (isExpanded != _isSheetExpanded) {
      setState(() => _isSheetExpanded = isExpanded);
    }
  }

  Future<void> _toggleBottomSheet() async {
    final targetSize = _isSheetExpanded
        ? _collapsedSheetSize
        : _expandedSheetSize;
    await _sheetController.animateTo(
      targetSize,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  List<CommunityLocation> get _filteredCommunities {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return List.unmodifiable(_communities);
    return _communities.where((c) {
      return c.name.toLowerCase().contains(q) ||
          c.category.toLowerCase().contains(q) ||
          c.address.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _focusOnCommunity(CommunityLocation community) async {
    setState(() => _selectedCommunityId = community.id);
    if (!community.hasCoordinate) return;
    final controller = await _mapController.future;
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: community.coordinate!, zoom: 15),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BackToExitWrapper(child: _buildRootBody(context));
  }

  Widget _buildRootBody(BuildContext context) {
    final communities = _filteredCommunities;
    final selectedCommunity = _communities.isEmpty
        ? null
        : _communities.firstWhere(
            (community) => community.id == _selectedCommunityId,
            orElse: () => _communities.first,
          );

    final markers = communities
        .where((c) => c.hasCoordinate)
        .map(
          (community) => Marker(
            markerId: MarkerId(community.id),
            position: community.coordinate!,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              community.id == _selectedCommunityId
                  ? BitmapDescriptor.hueViolet
                  : community.markerHue,
            ),
            infoWindow: InfoWindow(
              title: community.name,
              snippet: community.address,
            ),
            onTap: () => _focusOnCommunity(community),
          ),
        )
        .toSet();

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Theme.of(context).cardColor,
      drawer: const CooperativeSidebar(),
      drawerEdgeDragWidth: 50.w,
      drawerScrimColor: Colors.black.withValues(alpha: 0.4),
      body: Stack(
        children: [
          _buildMap(markers),
          _buildTopBar(),
          if (selectedCommunity != null)
            _buildFeaturedBanner(selectedCommunity),
          _buildBottomSheet(communities),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: 96.h),
        child: FloatingActionButton(
          heroTag: 'community-map-toggle',
          backgroundColor: const Color(0xFF7434FF),
          onPressed: _toggleBottomSheet,
          child: Icon(
            _isSheetExpanded ? Icons.map : Icons.list,
            color: Colors.white,
          ),
        ),
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
    );
  }

  Future<void> _handleCommunityAction(CommunityLocation community) async {
    final result = await showModalBottomSheet<CommunityJoinRequest>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return JoinCommunityBottomSheet(community: community);
      },
    );

    if (!mounted || result == null) return;
    _openApplicationStatus(community);
  }

  void _openCommunityDetails(CommunityLocation community) {
    context.pushNamed('community-detail', extra: community);
  }

  void _openApplicationStatus(CommunityLocation community) {
    context.pushNamed('community-application-status', extra: community);
  }

  Widget _buildMap(Set<Marker> markers) {
    return GoogleMap(
      initialCameraPosition: const CameraPosition(
        target: _fallbackCenter,
        zoom: 12.5,
      ),
      markers: markers,
      myLocationButtonEnabled: false,
      myLocationEnabled: false,
      zoomControlsEnabled: false,
      compassEnabled: false,
      mapToolbarEnabled: false,
      onMapCreated: (controller) {
        if (!_mapController.isCompleted) {
          _mapController.complete(controller);
        }
      },
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        child: Row(
          children: [
            _roundIconButton(
              icon: Icons.menu,
              onTap: () {
                _scaffoldKey.currentState?.openDrawer();
              },
            ),
            Expanded(
              child: Text(
                'Explore Communities',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 19.sp,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            _roundIconButton(
              icon: Icons.favorite_border,
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Saved communities coming soon')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturedBanner(CommunityLocation community) {
    final initials = community.name
        .split(' ')
        .where((word) => word.isNotEmpty)
        .take(2)
        .map((word) => word[0])
        .join()
        .toUpperCase();

    return Positioned(
      top: 118.h,
      left: 12.w,
      right: 12.w,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 14.h),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF7434FF), Color(0xFF9749FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12.r),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7434FF).withOpacity(0.25),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56.w,
              height: 56.w,
              decoration: BoxDecoration(
                color: Colors.white24,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  initials.isNotEmpty ? initials : 'CM',
                  style: TextStyle(
                    fontSize: 19.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            hSpace(14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          community.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 19.sp,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      if (_isVerified(community)) ...[
                        hSpace(6),
                        Icon(Icons.verified, size: 18.sp, color: Colors.white),
                      ],
                    ],
                  ),
                  vSpace(4),
                  Row(
                    children: [
                      Icon(
                        Icons.verified_user,
                        size: 14.sp,
                        color: Colors.white70,
                      ),
                      hSpace(4),
                      Text(
                        '${community.communityType} • ${community.members} members',
                        style: TextStyle(
                          fontSize: 16.sp,
                          color: Colors.white.withOpacity(0.85),
                        ),
                      ),
                    ],
                  ),
                  vSpace(6),
                  Row(
                    children: [
                      Icon(Icons.place, size: 14.sp, color: Colors.white70),
                      hSpace(4),
                      Expanded(
                        child: Text(
                          community.address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16.sp,
                            color: Colors.white.withOpacity(0.85),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            hSpace(12),
            OutlinedButton(
              onPressed: () => _openCommunityDetails(community),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.15),
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withOpacity(0.6)),
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Open',
                    style: TextStyle(
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  hSpace(6),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 14.sp,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomSheet(List<CommunityLocation> communities) {
    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: _collapsedSheetSize,
      minChildSize: _collapsedSheetSize,
      maxChildSize: _expandedSheetSize,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              const BottomSheetHandlebar(),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) =>
                      setState(() => _searchQuery = value.trim()),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search communities near you...',
                    hintStyle: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    filled: true,
                    fillColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 0,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              vSpace(14),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: Row(
                  children: [
                    Text(
                      'Nearby Communities',
                      style: TextStyle(
                        fontSize: 19.sp,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    hSpace(8),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 4.h,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).primaryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text(
                        '${communities.length} found',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {},
                      child: Text(
                        'View all',
                        style: TextStyle(
                          fontSize: 17.sp,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF7434FF),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _loadError != null
                    ? Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 24.w,
                          vertical: 24.h,
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Color(0xFFB42318),
                              size: 36,
                            ),
                            vSpace(8),
                            Text(
                              _loadError!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 17.sp,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.7),
                              ),
                            ),
                            vSpace(12),
                            OutlinedButton(
                              onPressed: _loadCooperatives,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : communities.isEmpty
                    ? Padding(
                        padding: EdgeInsets.only(top: 32.h),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.location_off_outlined,
                              color: Color(0xFFB0B0C3),
                              size: 48,
                            ),
                            vSpace(12),
                            Text(
                              _searchQuery.isEmpty
                                  ? 'No communities are accepting new members yet.'
                                  : 'No communities match your search',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 17.sp,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: EdgeInsets.only(
                          left: 20.w,
                          right: 20.w,
                          bottom: 32.h,
                        ),
                        itemCount: communities.length,
                        separatorBuilder: (_, __) => vSpace(12),
                        itemBuilder: (context, index) {
                          final community = communities[index];
                          return _buildCommunityCard(community);
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCommunityCard(CommunityLocation community) {
    return CommunityCard(
      community: community,
      isSelected: community.id == _selectedCommunityId,
      accentColor: _markerColorFromHue(community.markerHue),
      isMember: _memberCooperativeIds.contains(community.id),
      onTap: () => _focusOnCommunity(community),
      onJoinPressed: () => _handleCommunityAction(community),
    );
  }

  /// Used by the featured banner; mirrors `CommunityCard`'s isVerified
  /// guard for the banner case.
  bool _isVerified(CommunityLocation community) {
    try {
      return community.isVerified;
    } catch (_) {
      return false;
    }
  }

  /// Floating round icon-button used by the map's top controls.
  Widget _roundIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(10.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, color: Theme.of(context).colorScheme.onSurface),
      ),
    );
  }

  Color _markerColorFromHue(double hue) {
    return HSVColor.fromAHSV(1, hue, 0.6, 0.9).toColor();
  }
}
