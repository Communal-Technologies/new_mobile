import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:go_router/go_router.dart';

import 'package:communal_mobile/core/widgets/bottom_nav_bar.dart';
import 'package:communal_mobile/core/widgets/bottomsheet_handlebar.dart';
import 'package:communal_mobile/core/widgets/cooperative_sidebar.dart';
import 'package:communal_mobile/core/widgets/space.dart';
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

  static const double _collapsedSheetSize = 0.34;
  static const double _expandedSheetSize = 0.82;

  @override
  void initState() {
    super.initState();
    _selectedCommunityId = SampleCommunityLocations.featured.id;
    _sheetController.addListener(_handleSheetExtentChange);
  }

  @override
  void dispose() {
    _sheetController.removeListener(_handleSheetExtentChange);
    _searchController.dispose();
    super.dispose();
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

  List<CommunityLocation> get _filteredCommunities =>
      SampleCommunityLocations.search(_searchQuery);

  Future<void> _focusOnCommunity(CommunityLocation community) async {
    setState(() => _selectedCommunityId = community.id);
    final controller = await _mapController.future;
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: community.coordinate, zoom: 15),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final communities = _filteredCommunities;
    final selectedCommunity = SampleCommunityLocations.all.firstWhere(
      (community) => community.id == _selectedCommunityId,
      orElse: () => SampleCommunityLocations.featured,
    );

    final markers =
        communities
            .map(
              (community) => Marker(
                markerId: MarkerId(community.id),
                position: community.coordinate,
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
            .toSet()
          ..add(
            Marker(
              markerId: const MarkerId('user-location'),
              position: SampleCommunityLocations.userLocation,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueAzure,
              ),
            ),
          );

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      drawer: const CooperativeSidebar(),
      drawerEdgeDragWidth: 50.w,
      drawerScrimColor: Colors.black.withValues(alpha: 0.4),
      body: Stack(
        children: [
          _buildMap(markers),
          _buildTopBar(),
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
    final result = await showModalBottomSheet<dynamic>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return JoinCommunityBottomSheet(community: community);
      },
    );

    if (!mounted || result == null) return;

    if (result is Map && result['status'] == 'pending') {
      _openApplicationStatus(community);
    } else if (result is String) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result)));
    }
  }

  void _openCommunityDetails(CommunityLocation community) {
    context.pushNamed('community-detail', extra: community);
  }

  void _openApplicationStatus(CommunityLocation community) {
    context.pushNamed('community-application-status', extra: community);
  }

  Widget _buildMap(Set<Marker> markers) {
    return GoogleMap(
      initialCameraPosition: SampleCommunityLocations.initialCameraPosition,
      markers: markers,
      circles: {
        Circle(
          circleId: const CircleId('search-radius'),
          center: SampleCommunityLocations.userLocation,
          radius: 1200,
          strokeColor: const Color(0x557434FF),
          strokeWidth: 1,
          fillColor: const Color(0x1A7434FF),
        ),
      },
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
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
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
                    fontSize: 18.sp,
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
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      if (_isVerified(community)) ...[
                        hSpace(6),
                        Icon(
                          Icons.verified,
                          size: 18.sp,
                          color: Colors.white,
                        ),
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
                          fontSize: 12.sp,
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
                            fontSize: 12.sp,
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
                      fontSize: 13.sp,
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
            color: Colors.white,
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
                  decoration: InputDecoration(
                    hintText: 'Search communities near you...',
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Color(0xFF6C6C80),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF5F4F9),
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
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F1D40),
                      ),
                    ),
                    hSpace(8),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 4.h,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDE5FF),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text(
                        '${communities.length} found',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF5B4AC8),
                        ),
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {},
                      child: Text(
                        'View all',
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF7434FF),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: communities.isEmpty
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
                              'No communities match your search',
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: Colors.grey.shade600,
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
        color: Colors.white,
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
        icon: Icon(icon, color: const Color(0xFF0F1D40)),
      ),
    );
  }

  Color _markerColorFromHue(double hue) {
    return HSVColor.fromAHSV(1, hue, 0.6, 0.9).toColor();
  }
}


