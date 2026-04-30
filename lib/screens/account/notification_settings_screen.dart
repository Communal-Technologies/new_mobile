import 'package:flutter/material.dart';
import 'package:communal_mobile/core/utils/system_ui_style.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/data/models/notification_preferences.dart';
import 'package:communal_mobile/data/repositories/notifications_repository.dart';
import 'package:communal_mobile/injection.dart';
import 'package:communal_mobile/screens/account/widgets/notification_toggle_item.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  late final NotificationsRepository _repo;
  NotificationPreferences? _prefs;
  bool _loading = true;
  String? _error;
  // Tracks the most recent saved-server snapshot so we can restore on
  // failure. Without this, a network blip after an optimistic toggle
  // would leave the UI in a state the server doesn't agree with.
  NotificationPreferences? _lastSaved;

  @override
  void initState() {
    super.initState();
    _repo = getIt<NotificationsRepository>();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final p = await _repo.fetchPreferences();
      if (!mounted) return;
      setState(() {
        _prefs = p;
        _lastSaved = p;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  /// Optimistic toggle: update the UI immediately, send the change to
  /// the backend, revert + show a snackbar on failure.
  Future<void> _patch(NotificationPreferences next, Map<String, dynamic> change) async {
    final prev = _prefs;
    setState(() => _prefs = next);
    try {
      final saved = await _repo.updatePreferences(change);
      if (!mounted) return;
      setState(() {
        _prefs = saved;
        _lastSaved = saved;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _prefs = prev ?? _lastSaved);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
    }
  }

  void _setMuteAll(bool value) {
    final current = _prefs ?? const NotificationPreferences();
    if (value) {
      // Mirrors the existing UX rule: muting flips every individual
      // channel off so the screen state matches what the server stores.
      final next = current.copyWith(
        muteAll: true,
        pushNotifications: false,
        emailNotifications: false,
        smsNotifications: false,
        paymentReminders: false,
        largeTransactions: false,
        promotionalOffers: false,
        productUpdates: false,
        newsletters: false,
      );
      _patch(next, next.toJson());
    } else {
      final next = current.copyWith(muteAll: false);
      _patch(next, {'mute_all': false});
    }
  }

  void _setField(NotificationPreferences next, String key, bool value) {
    // Whenever an individual channel is enabled, mute_all must turn off
    // (server-side validator allows both flags to be sent together).
    final payload = <String, dynamic>{key: value};
    if (value && (_prefs?.muteAll ?? false)) {
      payload['mute_all'] = false;
    }
    _patch(next, payload);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemOverlayForTheme(Theme.of(context)),
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          title: Text(
            'Notification Settings',
            style: TextStyle(
              fontSize: 19.sp,
              fontWeight: FontWeight.w700,
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
    if (_error != null && _prefs == null) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 32.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                color: Color(0xFFB42318), size: 36),
            vSpace(12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17.sp,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.7),
              ),
            ),
            vSpace(12),
            OutlinedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    final p = _prefs ?? const NotificationPreferences();
    final mutedDisabled = p.muteAll;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          vSpace(16),
          NotificationToggleItem(
            icon: Icons.volume_off,
            title: 'Mute All Notifications',
            description: 'Temporarily silence all notifications',
            value: p.muteAll,
            onChanged: _setMuteAll,
          ),
          vSpace(16),
          _buildSectionHeader('General'),
          vSpace(12),
          NotificationToggleItem(
            icon: Icons.square_outlined,
            title: 'Push Notifications',
            description: 'Receive push notifications on this device',
            value: p.pushNotifications,
            enabled: !mutedDisabled,
            onChanged: (v) => _setField(
              p.copyWith(pushNotifications: v, muteAll: v ? false : p.muteAll),
              'push_notifications',
              v,
            ),
          ),
          NotificationToggleItem(
            icon: Icons.mail_outline,
            title: 'Email Notifications',
            description: 'Receive notifications via email',
            value: p.emailNotifications,
            enabled: !mutedDisabled,
            onChanged: (v) => _setField(
              p.copyWith(emailNotifications: v, muteAll: v ? false : p.muteAll),
              'email_notifications',
              v,
            ),
          ),
          NotificationToggleItem(
            icon: Icons.chat_bubble_outline,
            title: 'SMS Notifications',
            description: 'Receive important alerts via SMS',
            value: p.smsNotifications,
            enabled: !mutedDisabled,
            tag: NotificationTag.premium,
            onChanged: (v) => _setField(
              p.copyWith(smsNotifications: v, muteAll: v ? false : p.muteAll),
              'sms_notifications',
              v,
            ),
          ),
          vSpace(16),
          _buildSectionHeader('Transactions'),
          vSpace(12),
          NotificationToggleItem(
            icon: Icons.attach_money,
            title: 'Payment Reminders',
            description: 'Reminders for upcoming payments',
            value: p.paymentReminders,
            enabled: !mutedDisabled,
            onChanged: (v) => _setField(
              p.copyWith(paymentReminders: v, muteAll: v ? false : p.muteAll),
              'payment_reminders',
              v,
            ),
          ),
          NotificationToggleItem(
            icon: Icons.trending_up,
            title: 'Large Transactions',
            description: 'Alerts for transactions above ₦50,000',
            value: p.largeTransactions,
            enabled: !mutedDisabled,
            onChanged: (v) => _setField(
              p.copyWith(largeTransactions: v, muteAll: v ? false : p.muteAll),
              'large_transactions',
              v,
            ),
          ),
          vSpace(16),
          _buildSectionHeader('Marketing & Updates'),
          vSpace(12),
          NotificationToggleItem(
            icon: Icons.trending_up,
            title: 'Promotional Offers',
            description: 'Special offers and discounts',
            value: p.promotionalOffers,
            enabled: !mutedDisabled,
            onChanged: (v) => _setField(
              p.copyWith(promotionalOffers: v, muteAll: v ? false : p.muteAll),
              'promotional_offers',
              v,
            ),
          ),
          NotificationToggleItem(
            icon: Icons.notifications_outlined,
            title: 'Product Updates',
            description: 'New features and improvements',
            value: p.productUpdates,
            enabled: !mutedDisabled,
            onChanged: (v) => _setField(
              p.copyWith(productUpdates: v, muteAll: v ? false : p.muteAll),
              'product_updates',
              v,
            ),
          ),
          NotificationToggleItem(
            icon: Icons.mail_outline,
            title: 'Newsletters',
            description: 'Monthly newsletter and tips',
            value: p.newsletters,
            enabled: !mutedDisabled,
            onChanged: (v) => _setField(
              p.copyWith(newsletters: v, muteAll: v ? false : p.muteAll),
              'newsletters',
              v,
            ),
          ),
          vSpace(32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Builder(
        builder: (context) => Text(
          title,
          style: TextStyle(
            fontSize: 17.sp,
            fontWeight: FontWeight.w600,
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }
}
