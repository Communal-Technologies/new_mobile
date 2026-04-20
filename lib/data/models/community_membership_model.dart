/// Cooperative membership + per-cooperative community settings from the API.
class CommunityCooperativeSettings {
  /// Matches backend [MemberCooperativeSetting::defaultAttributes].
  factory CommunityCooperativeSettings.defaults() {
    return const CommunityCooperativeSettings(
      muteAllNotifications: false,
      contributionReminders: true,
      loanNotifications: true,
      chatMessages: true,
      announcements: true,
      showProfileToCommunity: true,
      allowGroupAdditions: true,
      showPhoneNumber: false,
      autoContribution: false,
      autoAcceptLoanOffers: false,
      setContributionLimit: false,
      autoDownloadMedia: true,
      showContributionHistory: true,
    );
  }

  const CommunityCooperativeSettings({
    required this.muteAllNotifications,
    required this.contributionReminders,
    required this.loanNotifications,
    required this.chatMessages,
    required this.announcements,
    required this.showProfileToCommunity,
    required this.allowGroupAdditions,
    required this.showPhoneNumber,
    required this.autoContribution,
    required this.autoAcceptLoanOffers,
    required this.setContributionLimit,
    required this.autoDownloadMedia,
    required this.showContributionHistory,
  });

  final bool muteAllNotifications;
  final bool contributionReminders;
  final bool loanNotifications;
  final bool chatMessages;
  final bool announcements;
  final bool showProfileToCommunity;
  final bool allowGroupAdditions;
  final bool showPhoneNumber;
  final bool autoContribution;
  final bool autoAcceptLoanOffers;
  final bool setContributionLimit;
  final bool autoDownloadMedia;
  final bool showContributionHistory;

  static bool _bool(dynamic v) =>
      v == true || v == 1 || v == '1' || v == 'true';

  factory CommunityCooperativeSettings.fromJson(Map<String, dynamic> json) {
    return CommunityCooperativeSettings(
      muteAllNotifications: _bool(json['mute_all_notifications']),
      contributionReminders: _bool(json['contribution_reminders']),
      loanNotifications: _bool(json['loan_notifications']),
      chatMessages: _bool(json['chat_messages']),
      announcements: _bool(json['announcements']),
      showProfileToCommunity: _bool(json['show_profile_to_community']),
      allowGroupAdditions: _bool(json['allow_group_additions']),
      showPhoneNumber: _bool(json['show_phone_number']),
      autoContribution: _bool(json['auto_contribution']),
      autoAcceptLoanOffers: _bool(json['auto_accept_loan_offers']),
      setContributionLimit: _bool(json['set_contribution_limit']),
      autoDownloadMedia: _bool(json['auto_download_media']),
      showContributionHistory: _bool(json['show_contribution_history']),
    );
  }

  CommunityCooperativeSettings copyWith({
    bool? muteAllNotifications,
    bool? contributionReminders,
    bool? loanNotifications,
    bool? chatMessages,
    bool? announcements,
    bool? showProfileToCommunity,
    bool? allowGroupAdditions,
    bool? showPhoneNumber,
    bool? autoContribution,
    bool? autoAcceptLoanOffers,
    bool? setContributionLimit,
    bool? autoDownloadMedia,
    bool? showContributionHistory,
  }) {
    return CommunityCooperativeSettings(
      muteAllNotifications:
          muteAllNotifications ?? this.muteAllNotifications,
      contributionReminders:
          contributionReminders ?? this.contributionReminders,
      loanNotifications: loanNotifications ?? this.loanNotifications,
      chatMessages: chatMessages ?? this.chatMessages,
      announcements: announcements ?? this.announcements,
      showProfileToCommunity:
          showProfileToCommunity ?? this.showProfileToCommunity,
      allowGroupAdditions: allowGroupAdditions ?? this.allowGroupAdditions,
      showPhoneNumber: showPhoneNumber ?? this.showPhoneNumber,
      autoContribution: autoContribution ?? this.autoContribution,
      autoAcceptLoanOffers:
          autoAcceptLoanOffers ?? this.autoAcceptLoanOffers,
      setContributionLimit: setContributionLimit ?? this.setContributionLimit,
      autoDownloadMedia: autoDownloadMedia ?? this.autoDownloadMedia,
      showContributionHistory:
          showContributionHistory ?? this.showContributionHistory,
    );
  }
}

class CommunityMembership {
  const CommunityMembership({
    required this.cooperativeId,
    required this.cooperativeName,
    required this.logoUrl,
    required this.memberCount,
    required this.roleLabel,
    required this.ledgerNumber,
    required this.isDefault,
    required this.settings,
  });

  final String cooperativeId;
  final String cooperativeName;
  final String? logoUrl;
  final int memberCount;
  final String roleLabel;
  final String ledgerNumber;
  final bool isDefault;
  final CommunityCooperativeSettings settings;

  factory CommunityMembership.fromJson(Map<String, dynamic> json) {
    final settingsRaw = json['settings'];
    final Map<String, dynamic> settingsMap;
    if (settingsRaw is Map) {
      settingsMap = Map<String, dynamic>.from(settingsRaw);
    } else {
      settingsMap = <String, dynamic>{};
    }
    final settings = settingsMap.isEmpty
        ? CommunityCooperativeSettings.defaults()
        : CommunityCooperativeSettings.fromJson(settingsMap);

    return CommunityMembership(
      cooperativeId: json['cooperative_id']?.toString() ?? '',
      cooperativeName:
          json['cooperative_name']?.toString().trim().isNotEmpty == true
              ? json['cooperative_name'].toString().trim()
              : 'Cooperative',
      logoUrl: json['logo_url']?.toString().trim().isNotEmpty == true
          ? json['logo_url'].toString().trim()
          : null,
      memberCount: int.tryParse(json['member_count']?.toString() ?? '') ?? 0,
      roleLabel: json['role_label']?.toString().trim().isNotEmpty == true
          ? json['role_label'].toString().trim()
          : 'Member',
      ledgerNumber: json['ledger_number']?.toString() ?? '',
      isDefault: json['is_default'] == true || json['is_default'] == 1,
      settings: settings,
    );
  }

  CommunityMembership copyWith({
    CommunityCooperativeSettings? settings,
  }) {
    return CommunityMembership(
      cooperativeId: cooperativeId,
      cooperativeName: cooperativeName,
      logoUrl: logoUrl,
      memberCount: memberCount,
      roleLabel: roleLabel,
      ledgerNumber: ledgerNumber,
      isDefault: isDefault,
      settings: settings ?? this.settings,
    );
  }
}
