import 'package:intl/intl.dart';

import 'package:communal_mobile/data/models/community_membership_model.dart';

class Community {
  Community({
    required this.id,
    required this.name,
    required this.membersCount,
    required this.since,
    required this.role,
    required this.membershipLabel,
    required this.initials,
    this.isFeatured = false,
    this.isVerified = false,
  });

  /// Adapter from the API `CommunityMembership` shape (the user's own
  /// memberships) onto this UI-side model. Backend doesn't yet surface
  /// a join date or per-membership verified flag, so we fall back to
  /// `DateTime.now()` (sinceLabel becomes the current month) and false.
  factory Community.fromMembership(CommunityMembership m) {
    return Community(
      id: m.cooperativeId,
      name: m.cooperativeName,
      membersCount: m.memberCount,
      since: DateTime.now(),
      role: m.roleLabel,
      membershipLabel: m.roleLabel,
      initials: _initialsFor(m.cooperativeName),
      isFeatured: m.isDefault,
      isVerified: false,
    );
  }

  final String id;
  final String name;
  final int membersCount;
  final DateTime since;
  final String role;
  final String membershipLabel;
  final String initials;
  final bool isFeatured;
  final bool isVerified;

  String get sinceLabel => DateFormat('MMM yyyy').format(since);
  String get membersLabel => '$membersCount members';
}

String _initialsFor(String name) {
  final parts = name.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    final p = parts.first;
    return p.length >= 2 ? p.substring(0, 2).toUpperCase() : p.toUpperCase();
  }
  return parts.take(3).map((p) => p[0].toUpperCase()).join();
}

class SampleCommunities {
  static final List<Community> all = [
    Community(
      id: 'tlf',
      name: 'Total Lenders Forum',
      membersCount: 156,
      since: DateTime(2024, 1, 1),
      role: 'Admin',
      membershipLabel: 'Senior Member',
      initials: 'TLF',
      isFeatured: true,
      isVerified: true,
    ),
    Community(
      id: 'mwa',
      name: 'Market Women Association',
      membersCount: 89,
      since: DateTime(2024, 3, 1),
      role: 'Member',
      membershipLabel: 'Regular Member',
      initials: 'MWA',
      isVerified: true,
    ),
    Community(
      id: 'mwa-admin',
      name: 'Market Women Association',
      membersCount: 89,
      since: DateTime(2024, 3, 1),
      role: 'Admin',
      membershipLabel: 'Admin',
      initials: 'MWA',
      isVerified: false,
    ),
  ];

  static Community get featured =>
      all.firstWhere((community) => community.isFeatured, orElse: () => all[0]);
}
