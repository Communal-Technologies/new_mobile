import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/screens/account/widgets/community_info_card.dart';
import 'package:communal_mobile/screens/account/widgets/community_toggle_setting_item.dart';
import 'package:communal_mobile/screens/account/widgets/community_action_item.dart';
import 'package:communal_mobile/screens/account/widgets/settings_info_box.dart';

class CommunitySettingsScreen extends StatefulWidget {
  const CommunitySettingsScreen({super.key});

  @override
  State<CommunitySettingsScreen> createState() => _CommunitySettingsScreenState();
}

class _CommunitySettingsScreenState extends State<CommunitySettingsScreen> {
  // Mute All Notifications
  bool _muteAllNotifications = false;

  // Notifications Section
  bool _contributionReminders = true;
  bool _loanNotifications = true;
  bool _chatMessages = true;
  bool _announcements = true;

  // Privacy & Security Section
  bool _showProfileToCommunity = true;
  bool _allowGroupAdditions = true;
  bool _showPhoneNumber = false;

  // Financial Settings Section
  bool _autoContribution = false;
  bool _autoAcceptLoanOffers = false;
  bool _setContributionLimit = false;

  // Data & Storage Section
  bool _autoDownloadMedia = true;
  bool _showContributionHistory = true;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => context.pop(),
          ),
          title: Text(
            'Community Settings',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              vSpace(16),
              const CommunityInfoCard(
                communityName: 'Total Lenders Forum',
                memberCount: 156,
                role: 'Senior Member',
              ),
              vSpace(16),
              // Mute All Notifications
              CommunityToggleSettingItem(
                icon: Icons.volume_off,
                title: 'Mute All Notifications',
                description: 'Silence all community notifications',
                value: _muteAllNotifications,
                onChanged: (value) {
                  setState(() {
                    _muteAllNotifications = value;
                    if (value) {
                      // When muting all, turn off individual notifications
                      _contributionReminders = false;
                      _loanNotifications = false;
                      _chatMessages = false;
                      _announcements = false;
                    }
                  });
                },
              ),
              vSpace(16),
              // Notifications Section
              _buildSectionHeader('Notifications'),
              vSpace(12),
              CommunityToggleSettingItem(
                icon: Icons.calendar_today,
                title: 'Contribution Reminders',
                description: 'Get notified before contribution deadlines',
                value: _contributionReminders,
                onChanged: (value) {
                  setState(() {
                    _contributionReminders = value;
                    if (value) _muteAllNotifications = false;
                  });
                },
                enabled: !_muteAllNotifications,
              ),
              CommunityToggleSettingItem(
                icon: Icons.attach_money,
                title: 'Loan Notifications',
                description: 'Updates on loan applications and approvals',
                value: _loanNotifications,
                onChanged: (value) {
                  setState(() {
                    _loanNotifications = value;
                    if (value) _muteAllNotifications = false;
                  });
                },
                enabled: !_muteAllNotifications,
              ),
              CommunityToggleSettingItem(
                icon: Icons.notifications,
                title: 'Chat Messages',
                description: 'Notifications for community chat messages',
                value: _chatMessages,
                onChanged: (value) {
                  setState(() {
                    _chatMessages = value;
                    if (value) _muteAllNotifications = false;
                  });
                },
                enabled: !_muteAllNotifications,
              ),
              CommunityToggleSettingItem(
                icon: Icons.info,
                title: 'Announcements',
                description: 'Important community announcements',
                value: _announcements,
                onChanged: (value) {
                  setState(() {
                    _announcements = value;
                    if (value) _muteAllNotifications = false;
                  });
                },
                enabled: !_muteAllNotifications,
              ),
              vSpace(16),
              // Privacy & Security Section
              _buildSectionHeader('Privacy & Security'),
              vSpace(12),
              CommunityToggleSettingItem(
                icon: Icons.visibility,
                title: 'Show Profile to Community',
                description: 'Allow members to view your profile',
                value: _showProfileToCommunity,
                onChanged: (value) {
                  setState(() => _showProfileToCommunity = value);
                },
              ),
              CommunityToggleSettingItem(
                icon: Icons.person_add,
                title: 'Allow Group Additions',
                description: 'Let others add you to new groups',
                value: _allowGroupAdditions,
                onChanged: (value) {
                  setState(() => _allowGroupAdditions = value);
                },
              ),
              CommunityToggleSettingItem(
                icon: Icons.lock,
                title: 'Show Phone Number',
                description: 'Display your phone to community members',
                value: _showPhoneNumber,
                onChanged: (value) {
                  setState(() => _showPhoneNumber = value);
                },
              ),
              vSpace(16),
              // Financial Settings Section
              _buildSectionHeader('Financial Settings'),
              vSpace(12),
              CommunityToggleSettingItem(
                icon: Icons.calendar_today,
                title: 'Auto-Contribution',
                description: 'Automatically pay scheduled contributions',
                value: _autoContribution,
                onChanged: (value) {
                  setState(() => _autoContribution = value);
                },
              ),
              CommunityToggleSettingItem(
                icon: Icons.attach_money,
                title: 'Auto-Accept Loan Offers',
                description: 'Automatically accept pre-approved loans',
                value: _autoAcceptLoanOffers,
                onChanged: (value) {
                  setState(() => _autoAcceptLoanOffers = value);
                },
              ),
              CommunityToggleSettingItem(
                icon: Icons.info,
                title: 'Set Contribution Limit',
                description: 'Enable maximum contribution limits',
                value: _setContributionLimit,
                onChanged: (value) {
                  setState(() => _setContributionLimit = value);
                },
              ),
              vSpace(16),
              // Data & Storage Section
              _buildSectionHeader('Data & Storage'),
              vSpace(12),
              CommunityToggleSettingItem(
                icon: Icons.download,
                title: 'Auto-Download Media',
                description: 'Download images and videos on WiFi only',
                value: _autoDownloadMedia,
                onChanged: (value) {
                  setState(() => _autoDownloadMedia = value);
                },
              ),
              CommunityToggleSettingItem(
                icon: Icons.description,
                title: 'Show Contribution History',
                description: 'Display your contribution records',
                value: _showContributionHistory,
                onChanged: (value) {
                  setState(() => _showContributionHistory = value);
                },
              ),
              vSpace(16),
              // Community Actions Section
              _buildSectionHeader('Community Actions'),
              vSpace(12),
              CommunityActionItem(
                icon: Icons.report_problem,
                title: 'Report Community',
                description: 'Report fraud or violations',
                iconColor: Colors.orange,
                textColor: Colors.orange,
                onTap: () {
                  _showReportDialog(context);
                },
              ),
              CommunityActionItem(
                icon: Icons.exit_to_app,
                title: 'Exit Community',
                description: 'Leave this cooperative',
                iconColor: Colors.red,
                textColor: Colors.red,
                onTap: () {
                  _showExitDialog(context);
                },
              ),
              vSpace(24),
              const SettingsInfoBox(),
              vSpace(32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16.sp,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF0F1D40),
        ),
      ),
    );
  }

  void _showReportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Community'),
        content: const Text('Are you sure you want to report this community?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Report submitted')),
              );
            },
            child: const Text('Report', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
  }

  void _showExitDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit Community'),
        content: const Text(
          'Are you sure you want to leave this community? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('You have left the community')),
              );
            },
            child: const Text('Exit', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

