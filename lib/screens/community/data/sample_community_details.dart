import 'package:communal_mobile/screens/community/data/sample_community_locations.dart';

class CommunityDetailStats {
  const CommunityDetailStats({
    required this.totalLoans,
    required this.totalSavings,
    required this.monthlyContribution,
    required this.activeLoans,
    required this.defaultRate,
    required this.loanInterestRate,
  });

  final String totalLoans;
  final String totalSavings;
  final String monthlyContribution;
  final String activeLoans;
  final String defaultRate;
  final String loanInterestRate;
}

class CommunityRecentActivity {
  const CommunityRecentActivity({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.daysAgo,
  });

  final String icon;
  final String title;
  final String subtitle;
  final String daysAgo;
}

class CommunityDetail {
  CommunityDetail({
    required this.location,
    required this.categoryLabel,
    required this.stats,
    required this.about,
    required this.foundedDate,
    required this.contributionRange,
    required this.isVerified,
    required this.coordinatorName,
    required this.coordinatorRole,
    required this.meetingSchedule,
    required this.meetingTime,
    required this.membershipRequirements,
    required this.benefits,
    required this.recentActivities,
  });

  final CommunityLocation location;
  final String categoryLabel;
  final CommunityDetailStats stats;
  final String about;
  final String foundedDate;
  final String contributionRange;
  final bool isVerified;
  final String coordinatorName;
  final String coordinatorRole;
  final String meetingSchedule;
  final String meetingTime;
  final List<String> membershipRequirements;
  final List<String> benefits;
  final List<CommunityRecentActivity> recentActivities;
}

class SampleCommunityDetails {
  static final Map<String, CommunityDetail> _details = {
    'lagos-market': CommunityDetail(
      location: SampleCommunityLocations.all.firstWhere(
        (community) => community.id == 'lagos-market',
      ),
      categoryLabel: 'Trading Cooperative',
      stats: const CommunityDetailStats(
        totalLoans: '₦45.2M',
        totalSavings: '₦28.7M',
        monthlyContribution: '₦50k /mo',
        activeLoans: '67',
        defaultRate: '2.1%',
        loanInterestRate: '5% per annum',
      ),
      about:
          'A thriving cooperative for market traders across Lagos State. We provide financial support, business loans, and shared resources to help our members grow their trading businesses and achieve financial stability.',
      foundedDate: 'Created March 2022',
      contributionRange: '₦10,000 - ₦500,000',
      isVerified: true,
      coordinatorName: 'Mrs. Adunni Okafor',
      coordinatorRole: 'Admin',
      meetingSchedule: 'First Saturday of every month',
      meetingTime: '4pm',
      membershipRequirements: const [
        'Must be a registered market trader in Lagos State',
        'Minimum 6 months trading experience',
        'Valid means of identification (NIN, Driver’s License, or Passport)',
        'Two references from existing members (optional)',
        'Commitment to monthly contributions',
      ],
      benefits: const [
        'Access to low-interest loans up to 4x your contribution',
        'Emergency financial assistance',
        'Group buying power for wholesale purchases',
        'Business training and development programs',
        'Insurance coverage for trading activities',
        'Networking opportunities with other traders',
      ],
      recentActivities: const [
        CommunityRecentActivity(
          icon: 'loan',
          title: 'New loan approved for Kemi Adebayo',
          subtitle: '₦150,000',
          daysAgo: '2 days ago',
        ),
        CommunityRecentActivity(
          icon: 'calendar',
          title: 'Monthly general meeting scheduled',
          subtitle: 'Next meeting in a week',
          daysAgo: '1 week ago',
        ),
        CommunityRecentActivity(
          icon: 'members',
          title: '5 new members joined this month',
          subtitle: 'Welcome to the cooperative!',
          daysAgo: '2 weeks ago',
        ),
      ],
    ),
  };

  /// Builds a [CommunityDetail] for any [CommunityLocation] — uses the
  /// hand-curated sample content when the id matches a known fixture,
  /// otherwise wraps the location with placeholder stats. The detail
  /// screens read `location.id`, so this preserves the real cooperative
  /// id whether or not we have rich content to show.
  static CommunityDetail forLocation(CommunityLocation location) {
    final cached = _details[location.id];
    if (cached != null) return cached;
    // Empty strings / lists where the backend has no real data yet.
    // The detail screen renders each section only when its source is
    // populated, so empty fields collapse instead of showing
    // placeholder content like "Community Coordinator / Admin".
    return CommunityDetail(
      location: location,
      categoryLabel: location.category,
      stats: const CommunityDetailStats(
        totalLoans: '',
        totalSavings: '',
        monthlyContribution: '',
        activeLoans: '',
        defaultRate: '',
        loanInterestRate: '',
      ),
      about: 'Details will appear once the cooperative admin completes their profile.',
      foundedDate: '',
      contributionRange: location.minContributionLabel,
      isVerified: location.isVerified,
      coordinatorName: '',
      coordinatorRole: '',
      meetingSchedule: '',
      meetingTime: '',
      membershipRequirements: const [],
      benefits: const [],
      recentActivities: const [],
    );
  }
}
