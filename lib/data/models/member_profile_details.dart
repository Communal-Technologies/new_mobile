/// Full member profile shape returned by GET /members/fetch-user-details/{id}.
/// The endpoint returns a Profile row with the related User row eager-loaded
/// as `contact` (email + phone live there). This model flattens the two for
/// UI consumption — the my-profile / edit-profile screens read all editable
/// fields (incl. middle name, date of birth, occupation, full address) from
/// here.
class MemberProfileDetails {
  const MemberProfileDetails({
    required this.id,
    required this.userId,
    this.firstName,
    this.middleName,
    this.lastName,
    this.email,
    this.phone,
    this.dateOfBirth,
    this.occupation,
    this.addressLine1,
    this.addressLine2,
    this.city,
    this.state,
    this.lga,
    this.country,
    this.postalCode,
    this.ledgerNumber,
    this.cooperativeId,
  });

  final String id;
  final String userId;
  final String? firstName;
  final String? middleName;
  final String? lastName;
  final String? email;
  final String? phone;
  final String? dateOfBirth;
  final String? occupation;
  final String? addressLine1;
  final String? addressLine2;
  final String? city;
  final String? state;
  final String? lga;
  final String? country;
  final String? postalCode;
  final String? ledgerNumber;
  final String? cooperativeId;

  String? _nullIfEmpty(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  String get displayName {
    final parts = [firstName, middleName, lastName]
        .map((s) => (s ?? '').trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'Member';
    return parts.join(' ');
  }

  factory MemberProfileDetails.fromJson(Map<String, dynamic> json) {
    final contact = json['contact'];
    final contactMap = contact is Map ? Map<String, dynamic>.from(contact) : null;

    String? str(dynamic v) {
      if (v == null) return null;
      final s = v.toString().trim();
      return s.isEmpty ? null : s;
    }

    return MemberProfileDetails(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      firstName: str(json['first_name']),
      middleName: str(json['middle_name']),
      lastName: str(json['last_name']),
      email: str(contactMap?['email']) ?? str(json['email']),
      phone: str(contactMap?['phone']) ?? str(json['phone']),
      dateOfBirth: str(json['date_of_birth']),
      occupation: str(json['occupation']),
      addressLine1: str(json['address_1']),
      addressLine2: str(json['address_2']),
      city: str(json['city']),
      state: str(json['state']),
      lga: str(json['lga']),
      country: str(json['country']),
      postalCode: str(json['postal_code']),
      ledgerNumber: str(json['ledger_number']),
      cooperativeId: str(json['cooperative_id']),
    );
  }
}
