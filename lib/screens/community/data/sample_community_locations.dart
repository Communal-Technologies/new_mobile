import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

import 'package:communal_mobile/data/models/public_cooperative.dart';

class CommunityLocation {
  CommunityLocation({
    required this.id,
    required this.name,
    required this.category,
    required this.communityType,
    required this.address,
    required this.members,
    required this.distanceKm,
    required this.minContribution,
    required this.rating,
    required this.coordinate,
    required this.markerHue,
    this.ratingCount = 0,
    this.isFeatured = false,
    this.isVerified = false,
    this.isMember = false,
  });

  /// Adapter for the discoverable cooperatives returned by
  /// /fetch-cooperatives. Coordinates may be null when the cooperative
  /// admin hasn't pinned the address on the dashboard yet — UI must
  /// check [hasCoordinate] before rendering markers / animating to it.
  /// Distance defaults to 0 (we don't yet ask for device location);
  /// expose a "—" via [distanceLabel] when distance is unknown.
  factory CommunityLocation.fromPublicCooperative(PublicCooperative coop) {
    final hue = _stableHueFor(coop.cooperativeId);
    return CommunityLocation(
      id: coop.cooperativeId,
      name: coop.name,
      category: (coop.category?.isNotEmpty == true)
          ? coop.category!
          : 'Cooperative',
      // The public listing only includes coops with allow_signup=1,
      // so we can label them "Open Group" wholesale here.
      communityType: 'Open Group',
      address: coop.address ?? '',
      members: coop.membersCount,
      distanceKm: 0,
      minContribution: coop.minContributionKobo != null
          ? (coop.minContributionKobo! / 100).round()
          : 0,
      rating: coop.ratingAverage ?? double.tryParse(coop.rating ?? '') ?? 0.0,
      ratingCount: coop.ratingCount,
      coordinate: coop.hasCoordinates
          ? LatLng(coop.latitude!, coop.longitude!)
          : null,
      markerHue: hue,
      isFeatured: coop.isFeatured,
      isVerified: coop.isVerified,
    );
  }

  final String id;
  final String name;
  final String category;
  final String communityType;
  final String address;
  final int members;
  final double distanceKm;
  final int minContribution;
  final double rating;
  final int ratingCount;
  final LatLng? coordinate;
  final double markerHue;
  final bool isFeatured;
  final bool isVerified;
  final bool isMember;

  bool get hasCoordinate => coordinate != null;

  String get membersLabel => '$members members';
  String get distanceLabel => distanceKm > 0
      ? '${distanceKm >= 1 ? distanceKm.toStringAsFixed(1) : distanceKm.toStringAsFixed(2)} km'
      : '—';

  String get minContributionLabel => minContribution > 0
      ? NumberFormat.currency(symbol: '₦', decimalDigits: 0)
            .format(minContribution)
      : '—';
}

/// Stable hue per cooperative_id so the same coop keeps the same colour
/// across loads. Hashing the id maps it onto Google Maps' canonical hue
/// palette.
double _stableHueFor(String id) {
  if (id.isEmpty) return BitmapDescriptor.hueViolet;
  const palette = <double>[
    BitmapDescriptor.hueViolet,
    BitmapDescriptor.hueGreen,
    BitmapDescriptor.hueAzure,
    BitmapDescriptor.hueOrange,
    BitmapDescriptor.hueRose,
    BitmapDescriptor.hueRed,
    BitmapDescriptor.hueYellow,
    BitmapDescriptor.hueCyan,
    BitmapDescriptor.hueMagenta,
  ];
  return palette[id.hashCode.abs() % palette.length];
}

class SampleCommunityLocations {
  static const LatLng userLocation = LatLng(6.5310, 3.3526);

  static const CameraPosition initialCameraPosition = CameraPosition(
    target: userLocation,
    zoom: 13.8,
  );

  static final List<CommunityLocation> all = [
    CommunityLocation(
      id: 'tlf',
      name: 'Total Lenders Forum',
      category: 'Financing Network',
      communityType: 'Member',
      address: 'Ilupeju, Lagos',
      members: 156,
      distanceKm: 0.3,
      minContribution: 15000,
      rating: 4.9,
      coordinate: LatLng(6.5355, 3.3548),
      markerHue: BitmapDescriptor.hueViolet,
      isFeatured: true,
      isVerified: true,
      isMember: true,
    ),
    CommunityLocation(
      id: 'lagos-market',
      name: 'Lagos Market Traders',
      category: 'Trading Cooperative',
      communityType: 'Open Group',
      address: 'Mushin Main Market',
      members: 234,
      distanceKm: 0.5,
      minContribution: 10000,
      rating: 4.8,
      coordinate: LatLng(6.5244, 3.3499),
      markerHue: BitmapDescriptor.hueGreen,
      isVerified: true,
    ),
    CommunityLocation(
      id: 'tech-workers',
      name: 'Tech Workers Coop',
      category: 'Professional Cooperative',
      communityType: 'Open Group',
      address: 'Onipanu, Lagos',
      members: 156,
      distanceKm: 1.2,
      minContribution: 50000,
      rating: 4.9,
      coordinate: LatLng(6.5399, 3.3631),
      markerHue: BitmapDescriptor.hueAzure,
      isVerified: true,
    ),
    CommunityLocation(
      id: 'tfk-printing',
      name: 'TFK Printing Solutions',
      category: 'Creative Collective',
      communityType: 'Invite Only',
      address: 'Palm Avenue, Mushin',
      members: 98,
      distanceKm: 0.8,
      minContribution: 20000,
      rating: 4.6,
      coordinate: LatLng(6.5281, 3.3605),
      markerHue: BitmapDescriptor.hueOrange,
    ),
    CommunityLocation(
      id: 'mushin-market',
      name: 'Mushin Main Market',
      category: 'Market Association',
      communityType: 'Member',
      address: 'Isolo Rd, Mushin',
      members: 312,
      distanceKm: 1.6,
      minContribution: 8000,
      rating: 4.7,
      coordinate: LatLng(6.5167, 3.3530),
      markerHue: BitmapDescriptor.hueRose,
      isVerified: true,
    ),
  ];

  static CommunityLocation get featured => all.firstWhere(
    (community) => community.isFeatured,
    orElse: () => all.first,
  );

  static List<CommunityLocation> search(String query) {
    if (query.trim().isEmpty) return List.unmodifiable(all);

    final lower = query.toLowerCase();
    return all
        .where(
          (community) =>
              community.name.toLowerCase().contains(lower) ||
              community.category.toLowerCase().contains(lower) ||
              community.address.toLowerCase().contains(lower),
        )
        .toList();
  }
}
