class Guarantor {
  Guarantor({
    required this.id,
    required this.name,
    required this.memberType,
    required this.memberId,
    this.membershipDuration,
  });

  final String id;
  final String name;
  final String memberType; // "Executive Member", "Regular Member", etc.
  final String memberId;
  final String? membershipDuration; // e.g., "1.5 years"

  String get displayInfo {
    if (membershipDuration != null) {
      return '$memberType • $membershipDuration';
    }
    return '$memberType • $memberId';
  }
}

class SampleGuarantors {
  static final List<Guarantor> all = [
    Guarantor(
      id: 'guarantor-1',
      name: 'Chioma Okafor',
      memberType: 'Executive Member',
      memberId: 'LER-3722923',
    ),
    Guarantor(
      id: 'guarantor-2',
      name: 'Ibrahim Musa',
      memberType: 'Regular Member',
      memberId: 'LER-3722924',
      membershipDuration: '1.5 years',
    ),
    Guarantor(
      id: 'guarantor-3',
      name: 'Adebayo Johnson',
      memberType: 'Executive Member',
      memberId: 'LER-3722925',
    ),
    Guarantor(
      id: 'guarantor-4',
      name: 'Fatima Ahmed',
      memberType: 'Regular Member',
      memberId: 'LER-3722926',
      membershipDuration: '2 years',
    ),
    Guarantor(
      id: 'guarantor-5',
      name: 'Emeka Nwankwo',
      memberType: 'Executive Member',
      memberId: 'LER-3722927',
    ),
    Guarantor(
      id: 'guarantor-6',
      name: 'Amina Hassan',
      memberType: 'Regular Member',
      memberId: 'LER-3722928',
      membershipDuration: '3 months',
    ),
  ];
}

