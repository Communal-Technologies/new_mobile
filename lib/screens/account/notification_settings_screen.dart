import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/screens/account/widgets/notification_toggle_item.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  // Mute All Notifications
  bool _muteAllNotifications = false;

  // General Section
  bool _pushNotifications = true;
  bool _emailNotifications = true;
  bool _smsNotifications = false;

  // Transactions Section
  bool _transactionAlerts = true;
  bool _paymentReminders = true;
  bool _largeTransactions = true;

  // Security Section
  bool _loginAlerts = true;
  bool _securityAlerts = true;
  bool _passwordChanges = true;

  // Marketing & Updates Section
  bool _promotionalOffers = false;
  bool _productUpdates = true;
  bool _newsletters = false;

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
            'Notification Settings',
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              vSpace(16),
              // Mute All Notifications
              NotificationToggleItem(
                icon: Icons.volume_off,
                title: 'Mute All Notifications',
                description: 'Temporarily silence all notifications',
                value: _muteAllNotifications,
                onChanged: (value) {
                  setState(() {
                    _muteAllNotifications = value;
                    if (value) {
                      // When muting all, turn off all individual notifications
                      _pushNotifications = false;
                      _emailNotifications = false;
                      _smsNotifications = false;
                      _transactionAlerts = false;
                      _paymentReminders = false;
                      _largeTransactions = false;
                      _loginAlerts = false;
                      _securityAlerts = false;
                      _passwordChanges = false;
                      _promotionalOffers = false;
                      _productUpdates = false;
                      _newsletters = false;
                    }
                  });
                },
              ),
              vSpace(16),
              // General Section
              _buildSectionHeader('General'),
              vSpace(12),
              NotificationToggleItem(
                icon: Icons.square_outlined,
                title: 'Push Notifications',
                description: 'Receive push notifications on this device',
                value: _pushNotifications,
                onChanged: (value) {
                  setState(() {
                    _pushNotifications = value;
                    if (value) _muteAllNotifications = false;
                  });
                },
                enabled: !_muteAllNotifications,
              ),
              NotificationToggleItem(
                icon: Icons.mail_outline,
                title: 'Email Notifications',
                description: 'Receive notifications via email',
                value: _emailNotifications,
                onChanged: (value) {
                  setState(() {
                    _emailNotifications = value;
                    if (value) _muteAllNotifications = false;
                  });
                },
                enabled: !_muteAllNotifications,
              ),
              NotificationToggleItem(
                icon: Icons.chat_bubble_outline,
                title: 'SMS Notifications',
                description: 'Receive important alerts via SMS',
                value: _smsNotifications,
                onChanged: (value) {
                  setState(() {
                    _smsNotifications = value;
                    if (value) _muteAllNotifications = false;
                  });
                },
                enabled: !_muteAllNotifications,
                tag: NotificationTag.premium,
              ),
              vSpace(16),
              // Transactions Section
              _buildSectionHeader('Transactions'),
              vSpace(12),
              NotificationToggleItem(
                icon: Icons.notifications_outlined,
                title: 'Transaction Alerts',
                description: 'Get notified for all transactions',
                value: _transactionAlerts,
                onChanged: (value) {
                  setState(() {
                    _transactionAlerts = value;
                    if (value) _muteAllNotifications = false;
                  });
                },
                enabled: !_muteAllNotifications,
              ),
              NotificationToggleItem(
                icon: Icons.attach_money,
                title: 'Payment Reminders',
                description: 'Reminders for upcoming payments',
                value: _paymentReminders,
                onChanged: (value) {
                  setState(() {
                    _paymentReminders = value;
                    if (value) _muteAllNotifications = false;
                  });
                },
                enabled: !_muteAllNotifications,
              ),
              NotificationToggleItem(
                icon: Icons.trending_up,
                title: 'Large Transactions',
                description: 'Alerts for transactions above ₦50,000',
                value: _largeTransactions,
                onChanged: (value) {
                  setState(() {
                    _largeTransactions = value;
                    if (value) _muteAllNotifications = false;
                  });
                },
                enabled: !_muteAllNotifications,
              ),
              vSpace(16),
              // Security Section
              _buildSectionHeader('Security'),
              vSpace(12),
              NotificationToggleItem(
                icon: Icons.shield_outlined,
                title: 'Login Alerts',
                description: 'Notify when account is accessed',
                value: _loginAlerts,
                onChanged: (value) {
                  setState(() {
                    _loginAlerts = value;
                    if (value) _muteAllNotifications = false;
                  });
                },
                enabled: !_muteAllNotifications,
                iconColor: Colors.red,
                tag: NotificationTag.recommended,
              ),
              NotificationToggleItem(
                icon: Icons.shield_outlined,
                title: 'Security Alerts',
                description: 'Critical security notifications',
                value: _securityAlerts,
                onChanged: (value) {
                  setState(() {
                    _securityAlerts = value;
                    if (value) _muteAllNotifications = false;
                  });
                },
                enabled: !_muteAllNotifications,
                iconColor: Colors.red,
                tag: NotificationTag.recommended,
              ),
              NotificationToggleItem(
                icon: Icons.shield_outlined,
                title: 'Password Changes',
                description: 'Alerts when password is changed',
                value: _passwordChanges,
                onChanged: (value) {
                  setState(() {
                    _passwordChanges = value;
                    if (value) _muteAllNotifications = false;
                  });
                },
                enabled: !_muteAllNotifications,
                iconColor: Colors.red,
                tag: NotificationTag.recommended,
              ),
              vSpace(16),
              // Marketing & Updates Section
              _buildSectionHeader('Marketing & Updates'),
              vSpace(12),
              NotificationToggleItem(
                icon: Icons.trending_up,
                title: 'Promotional Offers',
                description: 'Special offers and discounts',
                value: _promotionalOffers,
                onChanged: (value) {
                  setState(() {
                    _promotionalOffers = value;
                    if (value) _muteAllNotifications = false;
                  });
                },
                enabled: !_muteAllNotifications,
              ),
              NotificationToggleItem(
                icon: Icons.notifications_outlined,
                title: 'Product Updates',
                description: 'New features and improvements',
                value: _productUpdates,
                onChanged: (value) {
                  setState(() {
                    _productUpdates = value;
                    if (value) _muteAllNotifications = false;
                  });
                },
                enabled: !_muteAllNotifications,
              ),
              NotificationToggleItem(
                icon: Icons.mail_outline,
                title: 'Newsletters',
                description: 'Monthly newsletter and tips',
                value: _newsletters,
                onChanged: (value) {
                  setState(() {
                    _newsletters = value;
                    if (value) _muteAllNotifications = false;
                  });
                },
                enabled: !_muteAllNotifications,
              ),
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
          fontSize: 14.sp,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade700,
        ),
      ),
    );
  }
}

