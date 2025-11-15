import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:communal_mobile/core/widgets/bottomsheet_handlebar.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/screens/community/data/sample_community_locations.dart';

class CommunityMapScreen extends StatefulWidget {
  const CommunityMapScreen({super.key});

  @override
  State<CommunityMapScreen> createState() => _CommunityMapScreenState();
}

class _CommunityMapScreenState extends State<CommunityMapScreen> {
  final Completer<GoogleMapController> _mapController = Completer();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedCommunityId;

  @override
  void initState() {
    super.initState();
    _selectedCommunityId = SampleCommunityLocations.featured.id;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
      backgroundColor: Colors.white,
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
          heroTag: 'community-map-fab',
          backgroundColor: const Color(0xFF7434FF),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Create community coming soon')),
            );
          },
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
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
              onTap: () => ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Menu coming soon'))),
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
    return Positioned(
      top: 96.h,
      left: 16.w,
      right: 16.w,
      child: Container(
        padding: EdgeInsets.all(18.w),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF7434FF), Color(0xFF9749FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(26.r),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7434FF).withOpacity(0.25),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              community.name,
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            vSpace(4),
            Text(
              '${community.communityType} • ${community.members} members',
              style: TextStyle(
                fontSize: 13.sp,
                color: Colors.white.withOpacity(0.85),
              ),
            ),
            vSpace(16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Member • ${community.membersLabel}',
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: Colors.white.withOpacity(0.85),
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => _focusOnCommunity(community),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF7434FF),
                    elevation: 0,
                    padding: EdgeInsets.symmetric(
                      horizontal: 20.w,
                      vertical: 10.h,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                  ),
                  child: const Text(
                    'Open',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomSheet(List<CommunityLocation> communities) {
    return DraggableScrollableSheet(
      initialChildSize: 0.38,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
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
                      borderRadius: BorderRadius.circular(18.r),
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
                        borderRadius: BorderRadius.circular(14.r),
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
    final isSelected = community.id == _selectedCommunityId;
    final accentColor = _markerColorFromHue(community.markerHue);

    return GestureDetector(
      onTap: () => _focusOnCommunity(community),
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22.r),
          border: Border.all(
            color: isSelected ? const Color(0xFF7434FF) : Colors.transparent,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildCommunityAvatar(accentColor),
                hSpace(12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        community.name,
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F1D40),
                        ),
                      ),
                      vSpace(4),
                      Text(
                        community.category,
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF4D9),
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.star,
                        color: Color(0xFFFFA426),
                        size: 14,
                      ),
                      hSpace(4),
                      Text(
                        community.rating.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFB46A00),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            vSpace(12),
            Row(
              children: [
                Icon(
                  Icons.people_alt,
                  size: 16.sp,
                  color: Colors.grey.shade600,
                ),
                hSpace(4),
                Text(
                  community.membersLabel,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.grey.shade600,
                  ),
                ),
                hSpace(12),
                Icon(
                  Icons.place_outlined,
                  size: 16.sp,
                  color: Colors.grey.shade600,
                ),
                hSpace(4),
                Text(
                  community.distanceLabel,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            vSpace(12),
            Text(
              'Min. Contribution',
              style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600),
            ),
            vSpace(4),
            Text(
              community.minContributionLabel,
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F1D40),
              ),
            ),
            vSpace(12),
            ElevatedButton(
              onPressed: () {
                final message = community.isMember
                    ? 'Opening ${community.name}'
                    : 'Request sent to join ${community.name}';
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(message)));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: community.isMember
                    ? const Color(0xFF31E3FF)
                    : const Color(0xFF7434FF),
                foregroundColor: community.isMember
                    ? const Color(0xFF0F1D40)
                    : Colors.white,
                elevation: 0,
                minimumSize: Size(double.infinity, 48.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.r),
                ),
              ),
              child: Text(
                community.isMember ? 'Open Community' : 'Join Community',
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _roundIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
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

  Widget _buildCommunityAvatar(Color accentColor) {
    return Container(
      height: 48.w,
      width: 48.w,
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Icon(Icons.apartment_rounded, color: accentColor, size: 24.sp),
    );
  }

  Color _markerColorFromHue(double hue) {
    return HSVColor.fromAHSV(1, hue, 0.6, 0.9).toColor();
  }
}
