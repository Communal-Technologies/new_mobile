import 'package:equatable/equatable.dart';

class UserModel extends Equatable {
  final String id;
  /// Best-effort display name (full name from profile, else username).
  final String name;
  final String login;
  final String? avatar;
  final bool hasSecurityPin;
  /// Raw API role, e.g. `member`.
  final String role;
  final String? cooperativeId;
  /// From `profile.cooperative.cooperative_name` when `get-loggedin-user` eager-loads cooperative.
  final String? cooperativeName;
  /// From `profile.cooperative.logo_url` when present (absolute URL).
  final String? cooperativeLogoUrl;
  final String? ledgerNumber;

  /// Profile / account fields for KYC prefill (when present on `get-loggedin-user`).
  final String? firstName;
  final String? middleName;
  final String? lastName;
  final String? email;
  final String? phone;
  /// Profile `country` when stored as a 2-letter ISO code (e.g. NG).
  final String? countryIso;

  const UserModel({
    required this.id,
    required this.name,
    required this.login,
    this.avatar,
    this.hasSecurityPin = false,
    this.role = 'member',
    this.cooperativeId,
    this.cooperativeName,
    this.cooperativeLogoUrl,
    this.ledgerNumber,
    this.firstName,
    this.middleName,
    this.lastName,
    this.email,
    this.phone,
    this.countryIso,
  });

  String get roleLabel {
    if (role.isEmpty) return 'Member';
    return role[0].toUpperCase() + role.substring(1).toLowerCase();
  }

  /// Cooperative label for headers (prefer legal/display name over `cooperative_id`).
  String get cooperativeDisplayName {
    final n = cooperativeName?.trim();
    if (n != null && n.isNotEmpty) return n;
    final id = cooperativeId?.trim();
    if (id != null && id.isNotEmpty) return id;
    return '—';
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final userMap = json['user'];
    final userData = userMap is Map
        ? Map<String, dynamic>.from(userMap)
        : Map<String, dynamic>.from(json);
    final profileRaw = userData['profile'];
    final profile = profileRaw is Map
        ? Map<String, dynamic>.from(profileRaw)
        : null;

    final topRole = json['role']?.toString();
    final role =
        (topRole != null && topRole.isNotEmpty)
            ? topRole
            : (userData['role']?.toString() ?? 'member');

    String fullName = '';
    if (profile != null) {
      final parts = [
        profile['first_name'],
        profile['middle_name'],
        profile['last_name'],
      ]
          .map((e) => e?.toString().trim() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
      fullName = parts.join(' ');
    }

    final fallbackName =
        userData['username']?.toString() ??
        userData['name']?.toString() ??
        '';

    final emailVal = userData['email']?.toString().trim();
    final phoneVal = userData['phone']?.toString().trim();
    final loginRaw = userData['login']?.toString().trim();

    String loginVal = '';
    for (final c in [emailVal, phoneVal, loginRaw]) {
      if (c != null && c.isNotEmpty) {
        loginVal = c;
        break;
      }
    }

    final fn = profile?['first_name']?.toString().trim();
    final mn = profile?['middle_name']?.toString().trim();
    final ln = profile?['last_name']?.toString().trim();

    String? profileCountryIso;
    final rawCountry = profile?['country']?.toString().trim();
    if (rawCountry != null &&
        rawCountry.length == 2 &&
        RegExp(r'^[A-Za-z]{2}$').hasMatch(rawCountry)) {
      profileCountryIso = rawCountry.toUpperCase();
    }

    String? coopName;
    String? coopLogo;
    final coopRaw = profile?['cooperative'];
    if (coopRaw is Map) {
      final c = Map<String, dynamic>.from(coopRaw);
      final cn = c['cooperative_name']?.toString().trim();
      if (cn != null && cn.isNotEmpty) coopName = cn;
      final lu = c['logo_url']?.toString().trim();
      if (lu != null && lu.isNotEmpty) coopLogo = lu;
    }

    String? pickFirstCsv(String? primary, String? fallback) {
      final p = primary?.trim();
      if (p != null && p.isNotEmpty) return p;
      final f = fallback?.trim();
      if (f == null || f.isEmpty) return null;
      final comma = f.indexOf(',');
      return comma == -1 ? f : f.substring(0, comma).trim();
    }

    return UserModel(
      id: userData['id']?.toString() ?? '',
      name: fullName.isNotEmpty ? fullName : fallbackName,
      login: loginVal,
      avatar: profile?['avatar']?.toString(),
      hasSecurityPin:
          userData['has_security_pin'] == true ||
          userData['has_security_pin'] == 1,
      role: role,
      cooperativeId: pickFirstCsv(
        profile?['active_cooperative_id']?.toString(),
        profile?['cooperative_id']?.toString(),
      ),
      cooperativeName: coopName,
      cooperativeLogoUrl: coopLogo,
      ledgerNumber: pickFirstCsv(
        profile?['active_ledger_number']?.toString(),
        profile?['ledger_number']?.toString(),
      ),
      firstName: fn != null && fn.isNotEmpty ? fn : null,
      middleName: mn != null && mn.isNotEmpty ? mn : null,
      lastName: ln != null && ln.isNotEmpty ? ln : null,
      email: emailVal != null && emailVal.isNotEmpty ? emailVal : null,
      phone: phoneVal != null && phoneVal.isNotEmpty ? phoneVal : null,
      countryIso: profileCountryIso,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'login': login,
      'avatar': avatar,
      'has_security_pin': hasSecurityPin,
      'role': role,
      'cooperative_id': cooperativeId,
      'cooperative_name': cooperativeName,
      'cooperative_logo_url': cooperativeLogoUrl,
      'ledger_number': ledgerNumber,
      'first_name': firstName,
      'middle_name': middleName,
      'last_name': lastName,
      'email': email,
      'phone': phone,
      'country_iso': countryIso,
    };
  }

  @override
  List<Object?> get props => [
        id,
        name,
        login,
        avatar,
        hasSecurityPin,
        role,
        cooperativeId,
        cooperativeName,
        cooperativeLogoUrl,
        ledgerNumber,
        firstName,
        middleName,
        lastName,
        email,
        phone,
        countryIso,
      ];
}
