import 'package:flutter/material.dart';
import 'package:communal_mobile/core/utils/system_ui_style.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/data/models/community_membership_model.dart';
import 'package:communal_mobile/data/repositories/community_settings_repository.dart';
import 'package:communal_mobile/injection.dart';
import 'package:communal_mobile/screens/account/widgets/community_action_item.dart';
import 'package:communal_mobile/screens/account/widgets/community_info_card.dart';
import 'package:communal_mobile/screens/account/widgets/community_toggle_setting_item.dart';
import 'package:communal_mobile/screens/account/widgets/settings_info_box.dart';

class CommunitySettingsScreen extends StatefulWidget {
  const CommunitySettingsScreen({super.key});

  @override
  State<CommunitySettingsScreen> createState() =>
      _CommunitySettingsScreenState();
}

class _CommunitySettingsScreenState extends State<CommunitySettingsScreen> {
  List<CommunityMembership> _memberships = [];
  String? _selectedCooperativeId;
  bool _loading = true;
  String? _error;

  CommunityMembership? get _current {
    final id = _selectedCooperativeId;
    if (id == null) return null;
    for (final m in _memberships) {
      if (m.cooperativeId == id) return m;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list =
          await getIt<CommunitySettingsRepository>().fetchMemberships();
      if (!mounted) return;
      setState(() {
        _memberships = list;
        _loading = false;
        final sel = _selectedCooperativeId;
        final stillValid =
            sel != null && list.any((m) => m.cooperativeId == sel);
        if (!stillValid) {
          CommunityMembership? pick;
          for (final m in list) {
            if (m.isDefault) {
              pick = m;
              break;
            }
          }
          pick ??= list.isNotEmpty ? list.first : null;
          _selectedCooperativeId = pick?.cooperativeId;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _patch(Map<String, dynamic> body) async {
    final id = _selectedCooperativeId;
    if (id == null) return;
    try {
      final next =
          await getIt<CommunitySettingsRepository>().updateSettings(id, body);
      if (!mounted) return;
      setState(() {
        final i = _memberships.indexWhere((m) => m.cooperativeId == id);
        if (i >= 0) {
          _memberships[i] = _memberships[i].copyWith(settings: next);
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _patchWithMuteClear(Map<String, dynamic> body) async {
    final merged = Map<String, dynamic>.from(body);
    if (merged['mute_all_notifications'] == true) {
      merged['contribution_reminders'] = false;
      merged['loan_notifications'] = false;
      merged['chat_messages'] = false;
      merged['announcements'] = false;
    }
    await _patch(merged);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemOverlayForTheme(Theme.of(context)),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).cardColor,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          title: Text(
            'Community Settings',
            style: TextStyle(
              fontSize: 21.sp,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          centerTitle: true,
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17.sp, color: Colors.grey.shade800),
              ),
              vSpace(16),
              FilledButton(
                onPressed: _load,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (_memberships.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Text(
            'You are not a member of any cooperative yet. Join a cooperative to manage community settings.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 17.sp, color: Colors.grey.shade800),
          ),
        ),
      );
    }

    final current = _current;
    if (current == null) {
      return Center(
        child: Text(
          'Select a cooperative',
          style: TextStyle(fontSize: 17.sp),
        ),
      );
    }

    final s = current.settings;
    final mute = s.muteAllNotifications;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          vSpace(16),
          if (_memberships.length > 1) ...[
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: InputDecorator(
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  labelText: 'Cooperative',
                  labelStyle: TextStyle(fontSize: 17.sp),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 4.h,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedCooperativeId,
                    style: TextStyle(
                      fontSize: 17.sp,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    items: _memberships
                        .map(
                          (m) => DropdownMenuItem(
                            value: m.cooperativeId,
                            child: Text(
                              m.cooperativeName,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _selectedCooperativeId = v);
                    },
                  ),
                ),
              ),
            ),
            vSpace(16),
          ],
          CommunityInfoCard(
            communityName: current.cooperativeName,
            memberCount: current.memberCount,
            role: current.roleLabel,
            logoUrl: current.logoUrl,
          ),
          vSpace(16),
          CommunityToggleSettingItem(
            icon: Icons.volume_off,
            title: 'Mute All Notifications',
            description: 'Silence all community notifications',
            value: mute,
            onChanged: (value) {
              _patchWithMuteClear({'mute_all_notifications': value});
            },
          ),
          vSpace(16),
          _buildSectionHeader('Notifications'),
          vSpace(12),
          CommunityToggleSettingItem(
            icon: Icons.calendar_today,
            title: 'Contribution Reminders',
            description: 'Get notified before contribution deadlines',
            value: s.contributionReminders,
            onChanged: (value) {
              final body = <String, dynamic>{
                'contribution_reminders': value,
              };
              if (value) body['mute_all_notifications'] = false;
              _patch(body);
            },
            enabled: !mute,
          ),
          CommunityToggleSettingItem(
            icon: Icons.attach_money,
            title: 'Loan Notifications',
            description: 'Updates on loan applications and approvals',
            value: s.loanNotifications,
            onChanged: (value) {
              final body = <String, dynamic>{'loan_notifications': value};
              if (value) body['mute_all_notifications'] = false;
              _patch(body);
            },
            enabled: !mute,
          ),
          CommunityToggleSettingItem(
            icon: Icons.notifications,
            title: 'Chat Messages',
            description: 'Notifications for community chat messages',
            value: s.chatMessages,
            onChanged: (value) {
              final body = <String, dynamic>{'chat_messages': value};
              if (value) body['mute_all_notifications'] = false;
              _patch(body);
            },
            enabled: !mute,
          ),
          CommunityToggleSettingItem(
            icon: Icons.info,
            title: 'Announcements',
            description: 'Important community announcements',
            value: s.announcements,
            onChanged: (value) {
              final body = <String, dynamic>{'announcements': value};
              if (value) body['mute_all_notifications'] = false;
              _patch(body);
            },
            enabled: !mute,
          ),
          vSpace(16),
          _buildSectionHeader('Privacy & Security'),
          vSpace(12),
          CommunityToggleSettingItem(
            icon: Icons.visibility,
            title: 'Show Profile to Community',
            description: 'Allow members to view your profile',
            value: s.showProfileToCommunity,
            onChanged: (value) =>
                _patch({'show_profile_to_community': value}),
          ),
          CommunityToggleSettingItem(
            icon: Icons.person_add,
            title: 'Allow Group Additions',
            description: 'Let others add you to new groups',
            value: s.allowGroupAdditions,
            onChanged: (value) => _patch({'allow_group_additions': value}),
          ),
          CommunityToggleSettingItem(
            icon: Icons.lock,
            title: 'Show Phone Number',
            description: 'Display your phone to community members',
            value: s.showPhoneNumber,
            onChanged: (value) => _patch({'show_phone_number': value}),
          ),
          vSpace(16),
          _buildSectionHeader('Financial Settings'),
          vSpace(12),
          CommunityToggleSettingItem(
            icon: Icons.calendar_today,
            title: 'Auto-Contribution',
            description: 'Automatically pay scheduled contributions',
            value: s.autoContribution,
            onChanged: (value) => _patch({'auto_contribution': value}),
          ),
          CommunityToggleSettingItem(
            icon: Icons.attach_money,
            title: 'Auto-Accept Loan Offers',
            description: 'Automatically accept pre-approved loans',
            value: s.autoAcceptLoanOffers,
            onChanged: (value) =>
                _patch({'auto_accept_loan_offers': value}),
          ),
          CommunityToggleSettingItem(
            icon: Icons.info,
            title: 'Set Contribution Limit',
            description: 'Enable maximum contribution limits',
            value: s.setContributionLimit,
            onChanged: (value) => _patch({'set_contribution_limit': value}),
          ),
          vSpace(16),
          _buildSectionHeader('Data & Storage'),
          vSpace(12),
          CommunityToggleSettingItem(
            icon: Icons.download,
            title: 'Auto-Download Media',
            description: 'Download images and videos on WiFi only',
            value: s.autoDownloadMedia,
            onChanged: (value) => _patch({'auto_download_media': value}),
          ),
          CommunityToggleSettingItem(
            icon: Icons.description,
            title: 'Show Contribution History',
            description: 'Display your contribution records',
            value: s.showContributionHistory,
            onChanged: (value) =>
                _patch({'show_contribution_history': value}),
          ),
          vSpace(16),
          _buildSectionHeader('Community Actions'),
          vSpace(12),
          CommunityActionItem(
            icon: Icons.report_problem,
            title: 'Report Community',
            description: 'Report fraud or violations',
            iconColor: Colors.orange,
            textColor: Colors.orange,
            onTap: () => _showReportDialog(context),
          ),
          CommunityActionItem(
            icon: Icons.exit_to_app,
            title: 'Exit Community',
            description: 'Leave this cooperative',
            iconColor: Colors.red,
            textColor: Colors.red,
            onTap: () => _showExitDialog(context),
          ),
          vSpace(24),
          const SettingsInfoBox(),
          vSpace(32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 19.sp,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  void _showReportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Report Community',
          style: TextStyle(fontSize: 19.sp, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Are you sure you want to report this community?',
          style: TextStyle(fontSize: 17.sp),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(fontSize: 17.sp)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Report submitted')),
              );
            },
            child: Text(
              'Report',
              style: TextStyle(color: Colors.orange, fontSize: 17.sp),
            ),
          ),
        ],
      ),
    );
  }

  void _showExitDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Exit Community',
          style: TextStyle(fontSize: 19.sp, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Are you sure you want to leave this cooperative? This action cannot be undone.',
          style: TextStyle(fontSize: 17.sp),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(fontSize: 17.sp)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Contact support to leave a cooperative. Self-service exit is not available yet.',
                  ),
                ),
              );
            },
            child: Text(
              'Exit',
              style: TextStyle(color: Colors.red, fontSize: 17.sp),
            ),
          ),
        ],
      ),
    );
  }
}
