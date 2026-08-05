/// A public cooperative the user can discover and request to join. Returned
/// by GET /fetch-cooperatives (filtered to coops with allow_signup=1) and
/// GET /fetch-cooperative-profile/{id} for the detail screen.
///
/// Latitude / longitude may be null when the cooperative admin hasn't set
/// them via Google Places autocomplete on the dashboard yet — UI must
/// handle missing coordinates (skip from map markers; show in list).
class PublicCooperative {
  const PublicCooperative({
    required this.cooperativeId,
    required this.uniqueId,
    required this.name,
    this.address,
    this.latitude,
    this.longitude,
    this.category,
    this.isVerified = false,
    this.isFeatured = false,
    this.allowSignup = true,
    this.membersCount = 0,
    this.minContributionKobo,
    this.rating,
    this.ratingAverage,
    this.ratingCount = 0,
  });

  final String cooperativeId;
  final String uniqueId;
  final String name;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? category;
  final bool isVerified;
  final bool isFeatured;
  final bool allowSignup;
  final int membersCount;
  final int? minContributionKobo;
  final String? rating;

  /// Aggregate member rating from cooperative-svc (tbl_cooperative_ratings).
  /// Null until at least one member has rated; [ratingCount] is the number of
  /// ratings that produced [ratingAverage].
  final double? ratingAverage;
  final int ratingCount;

  bool get hasCoordinates => latitude != null && longitude != null;

  /// Two-or-three letter avatar derived from the name. "Total Lenders Forum"
  /// → "TLF"; "Mushin Main Market" → "MMM"; "Tech" → "TE".
  String get initials {
    final parts = name
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final p = parts.first;
      return p.length >= 2 ? p.substring(0, 2).toUpperCase() : p.toUpperCase();
    }
    return parts.take(3).map((p) => p[0].toUpperCase()).join();
  }

  factory PublicCooperative.fromJson(Map<String, dynamic> json) {
    double? parseDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      if (v is String && v.isNotEmpty) return double.tryParse(v);
      return null;
    }

    int? parseInt(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toInt();
      if (v is String && v.isNotEmpty) return int.tryParse(v);
      return null;
    }

    return PublicCooperative(
      cooperativeId: json['cooperative_id']?.toString() ?? '',
      uniqueId: json['unique_id']?.toString() ?? '',
      name: json['cooperative_name']?.toString().trim().isNotEmpty == true
          ? json['cooperative_name'].toString().trim()
          : 'Cooperative',
      address: json['address']?.toString().trim().isNotEmpty == true
          ? json['address'].toString().trim()
          : null,
      latitude: parseDouble(json['latitude']),
      longitude: parseDouble(json['longitude']),
      category: json['category']?.toString().trim().isNotEmpty == true
          ? json['category'].toString().trim()
          : null,
      isVerified: json['is_verified'] == true || json['is_verified'] == 1,
      isFeatured: json['is_featured'] == true || json['is_featured'] == 1,
      allowSignup: json['allow_signup'] == true || json['allow_signup'] == 1,
      membersCount: parseInt(json['members_count']) ?? 0,
      minContributionKobo: parseInt(json['min_contribution_kobo']),
      rating: json['rating']?.toString(),
      ratingAverage: parseDouble(json['rating_average']),
      ratingCount: parseInt(json['rating_count']) ?? 0,
    );
  }
}
