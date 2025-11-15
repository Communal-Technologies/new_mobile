import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:go_router/go_router.dart';

import 'package:communal_mobile/core/widgets/bottom_nav_bar.dart';
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
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  String _searchQuery = '';
  String? _selectedCommunityId;
  int _currentIndex = 2;
  bool _isSheetExpanded = false;

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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result)));
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
          borderRadius: BorderRadius.circular(24.r),
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
                  Text(
                    community.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
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
                  borderRadius: BorderRadius.circular(20.r),
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Min. Contribution',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.grey.shade600,
                        ),
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
                    ],
                  ),
                ),
                SizedBox(
                  width: 160.w,
                  child: ElevatedButton(
                    onPressed: () => _handleCommunityAction(community),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7434FF),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: Size(double.infinity, 38.h),
                      padding: EdgeInsets.symmetric(
                        horizontal: 4.w,
                        vertical: 8.h,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    child: Text(
                      'Join Community',
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
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

class JoinCommunityBottomSheet extends StatefulWidget {
  const JoinCommunityBottomSheet({required this.community});

  final CommunityLocation community;

  @override
  State<JoinCommunityBottomSheet> createState() =>
      _JoinCommunityBottomSheetState();
}

class _JoinCommunityBottomSheetState extends State<JoinCommunityBottomSheet> {
  late final TextEditingController _messageController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    Navigator.of(context).pop({
      'status': 'pending',
      'community': widget.community,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.only(
                left: 24.w,
                right: 24.w,
                top: 12.h,
                bottom: 24.h,
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const BottomSheetHandlebar(),
                    _buildHeader(),
                    vSpace(16),
                    _buildMessageField(),
                    vSpace(16),
                    _buildAlertCard(),
                    vSpace(16),
                    _buildActions(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          height: 64.w,
          width: 64.w,
          decoration: BoxDecoration(
            color: const Color(0xFFEDE5FF),
            borderRadius: BorderRadius.circular(20.r),
          ),
          child: Icon(
            Icons.store_mall_directory_outlined,
            color: const Color(0xFF7434FF),
            size: 30.sp,
          ),
        ),
        vSpace(12),
        Text(
          'Join ${widget.community.name}?',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F1D40),
          ),
        ),
        vSpace(8),
        Text(
          'By joining, you agree to the community guidelines and contribution requirements.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildMessageField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Add a message (optional)',
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF0F1D40),
          ),
        ),
        vSpace(8),
        TextField(
          controller: _messageController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Hi, my name is ... I would like to join because...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.r),
              borderSide: const BorderSide(color: Color(0xFFE6E6F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.r),
              borderSide: const BorderSide(color: Color(0xFF7434FF)),
            ),
            filled: true,
            fillColor: const Color(0xFFF8F8FB),
          ),
        ),
      ],
    );
  }

  Widget _buildAlertCard() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E9),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFFFD9B3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFEE7B00)),
          hSpace(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Application Review Required',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF9A4F00),
                  ),
                ),
                vSpace(4),
                Text(
                  'Your application will be reviewed by the community coordinator. You’ll receive a response within 2-3 business days.',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: const Color(0xFF9A4F00),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              minimumSize: Size(double.infinity, 52.h),
              side: const BorderSide(color: Color(0xFFE0E0EC)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r),
              ),
            ),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0F1D40),
              ),
            ),
          ),
        ),
        hSpace(12),
        Expanded(
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              minimumSize: Size(double.infinity, 52.h),
              backgroundColor: const Color(0xFF7434FF),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r),
              ),
            ),
            child: _isSubmitting
                ? SizedBox(
                    height: 20.sp,
                    width: 20.sp,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : Text(
                    'Submit Request',
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
