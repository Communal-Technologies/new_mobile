import 'package:intl/intl.dart';

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
