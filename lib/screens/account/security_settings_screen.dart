import 'package:communal_mobile/core/security/biometric_signer_service.dart';
import 'package:communal_mobile/core/services/screenshot_service.dart';
import 'package:communal_mobile/core/utils/biometric_service.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/data/repositories/auth_repository.dart';
import 'package:communal_mobile/injection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  /// Reflects actual server-side enrollment (audit M38), not just device
  /// hardware availability — matches what the user sees inside the
  /// enrollment screen's master switch. Refreshed every time we come
  /// back from `/biometric-enrollment` so the badge stays in sync after
  /// the user toggles in there.
  bool _biometricEnrolled = false;
  bool _biometricHardwareAvailable = false;
  bool _loginAlertEnabled = true;
  bool _transactionAlertEnabled = true;

  static const _kLoginAlert = 'security_login_alert';
  static const _kTxAlert = 'security_transaction_alert';
  bool _allowScreenshotEnabled = false;

  List<Map<String, dynamic>> _activityLogs = [];
  bool _activityLoading = true;
  String? _activityError;

  @override
  void initState() {
    super.initState();
    _loadBiometricStatus();
    _loadScreenshotPref();
    _loadActivity();
    _loadAlertPrefs();
  }

  Future<void> _loadAlertPrefs() async {
    final prefs = getIt<SharedPreferences>();
    if (!mounted) return;
    setState(() {
      _loginAlertEnabled = prefs.getBool(_kLoginAlert) ?? true;
      _transactionAlertEnabled = prefs.getBool(_kTxAlert) ?? true;
    });
  }

  void _setLoginAlert(bool v) {
    setState(() => _loginAlertEnabled = v);
    getIt<SharedPreferences>().setBool(_kLoginAlert, v);
  }

  void _setTransactionAlert(bool v) {
    setState(() => _transactionAlertEnabled = v);
    getIt<SharedPreferences>().setBool(_kTxAlert, v);
  }

  Future<void> _loadActivity() async {
    try {
      final logs = await getIt<AuthRepository>().fetchLoginActivity();
      if (!mounted) return;
      setState(() {
        _activityLogs = logs;
        _activityLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _activityError = e.toString().replaceFirst('Exception: ', '');
        _activityLoading = false;
      });
    }
  }

  Future<void> _loadScreenshotPref() async {
    final enabled = await ScreenshotService.isEnabled();
    if (!mounted) return;
    setState(() => _allowScreenshotEnabled = enabled);
  }

  Future<void> _loadBiometricStatus() async {
    final available = await BiometricService.isBiometricAvailable();
    final enrolled = await getIt<BiometricSignerService>().isEnrolled();
    if (!mounted) return;
    setState(() {
      _biometricHardwareAvailable = available;
      _biometricEnrolled = enrolled;
    });
  }

  Future<void> _openBiometricEnrollment() async {
    if (!_biometricHardwareAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Biometric is not available on this device. Set it up in your device settings first.',
          ),
        ),
      );
      return;
    }
    await context.pushNamed('biometric-enrollment');
    // User may have toggled enrollment on/off — refresh.
    await _loadBiometricStatus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.primaryColor;
    final onSurface = theme.colorScheme.onSurface;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 22),
          onPressed: () => context.pop(),
        ),
        title: const Text('Security Settings'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                color: const Color(0xFF1AAE70).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: const Color(0xFF1AAE70)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 34.w,
                    height: 34.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF1AAE70).withValues(alpha: 0.15),
                      border: Border.all(color: const Color(0xFF1AAE70)),
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      size: 18,
                      color: Color(0xFF1AAE70),
                    ),
                  ),
                  hSpace(10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Secure Account',
                          style: TextStyle(
                            fontSize: 19.sp,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF12784C),
                          ),
                        ),
                        vSpace(4),
                        Text(
                          'Your account is protected. Keep your security settings up to date.',
                          style: TextStyle(
                            fontSize: 17.sp,
                            color: const Color(0xFF196C4A),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            vSpace(18),
            Text(
              'Authentication',
              style: TextStyle(
                fontSize: 19.sp,
                fontWeight: FontWeight.w700,
                color: onSurface,
              ),
            ),
            vSpace(10),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Column(
                children: [
                  _settingRow(
                    icon: Icons.vpn_key_outlined,
                    iconColor: primary,
                    iconBg: primary.withValues(alpha: 0.10),
                    title: 'Change transaction PIN',
                    subtitle: '4-digit PIN for authorizing transactions',
                    onTap: () => context.pushNamed('change-transaction-pin'),
                  ),
                  _settingRow(
                    icon: Icons.lock_outline,
                    iconColor: const Color(0xFF3A78D1),
                    iconBg: const Color(0xFFE9F2FF),
                    title: 'Change Login PIN',
                    subtitle: 'Update your app login PIN',
                    onTap: () => context.pushNamed('change-login-pin'),
                  ),
                  _settingRow(
                    icon: Icons.fingerprint,
                    iconColor: const Color(0xFFE0A400),
                    iconBg: const Color(0xFFFFF3D8),
                    title: 'Biometric Authentication',
                    subtitle: 'Use fingerprint or face ID to login',
                    trailing: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10.w,
                        vertical: 4.h,
                      ),
                      decoration: BoxDecoration(
                        color: (_biometricEnrolled
                                ? const Color(0xFF1AAE70)
                                : Colors.grey)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      child: Text(
                        _biometricEnrolled ? 'Enabled' : 'Disabled',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                          color: _biometricEnrolled
                              ? const Color(0xFF1AAE70)
                              : Colors.grey.shade700,
                        ),
                      ),
                    ),
                    onTap: _openBiometricEnrollment,
                  ),
                ],
              ),
            ),
            vSpace(18),
            Text(
              'Security Alerts',
              style: TextStyle(
                fontSize: 19.sp,
                fontWeight: FontWeight.w700,
                color: onSurface,
              ),
            ),
            vSpace(10),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Column(
                children: [
                  _toggleRow(
                    icon: Icons.notifications_none_outlined,
                    iconColor: const Color(0xFF3A78D1),
                    iconBg: const Color(0xFFE9F2FF),
                    title: 'Login Alert',
                    subtitle: 'Get notified on new device logins',
                    value: _loginAlertEnabled,
                    onChanged: _setLoginAlert,
                  ),
                  _toggleRow(
                    icon: Icons.notification_important_outlined,
                    iconColor: const Color(0xFF742CE7),
                    iconBg: const Color(0xFFEFE6FD),
                    title: 'Transactions Alert',
                    subtitle: 'Alert for all transactions',
                    value: _transactionAlertEnabled,
                    onChanged: _setTransactionAlert,
                  ),
                  _toggleRow(
                    icon: Icons.image_outlined,
                    iconColor: const Color(0xFFB8860B),
                    iconBg: const Color(0xFFFFF4CC),
                    title: 'Allow Screenshot',
                    subtitle: 'Enable taking screenshots in the app',
                    value: _allowScreenshotEnabled,
                    onChanged: (v) {
                      setState(() => _allowScreenshotEnabled = v);
                      ScreenshotService.setEnabled(v);
                    },
                  ),
                ],
              ),
            ),
            vSpace(18),
            Row(
              children: [
                Text(
                  'Recent activity',
                  style: TextStyle(
                    fontSize: 19.sp,
                    fontWeight: FontWeight.w700,
                    color: onSurface,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _showAllActivity,
                  child: Text(
                    'See all',
                    style: TextStyle(
                      fontSize: 17.sp,
                      color: primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            vSpace(10),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: theme.dividerColor),
              ),
              child: _buildActivityContent(),
            ),
            vSpace(18),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                color: const Color(0xFF3A78D1).withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.15 : 0.10),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: const Color(0xFF3A78D1).withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Security Tips',
                    style: TextStyle(
                      fontSize: 19.sp,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF90CAF9)
                          : const Color(0xFF12427A),
                    ),
                  ),
                  vSpace(8),
                  _tip('Never share your PIN or password with anyone'),
                  _tip('Change your PIN regularly for better security'),
                  _tip('Enable biometric for quick and secured access'),
                  _tip(
                    'Review your account activities regularly for suspicious activities',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _settingRow({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final muted = onSurface.withValues(alpha: 0.6);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
        child: Row(
          children: [
            Container(
              width: 40.w,
              height: 40.w,
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 21.sp),
            ),
            hSpace(10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 19.sp,
                      fontWeight: FontWeight.w700,
                      color: onSurface,
                    ),
                  ),
                  vSpace(2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w500,
                      color: muted,
                    ),
                  ),
                ],
              ),
            ),
            hSpace(8),
            trailing ??
                Icon(
                  Icons.arrow_forward_ios,
                  size: 14.sp,
                  color: muted,
                ),
          ],
        ),
      ),
    );
  }

  Widget _toggleRow({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
      child: Row(
        children: [
          Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 20.sp),
          ),
          hSpace(10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 19.sp,
                    fontWeight: FontWeight.w700,
                    color: onSurface,
                  ),
                ),
                vSpace(2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w500,
                    color: onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          hSpace(8),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Theme.of(context).primaryColor,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }

  Widget _tip(String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.only(bottom: 6.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check, color: const Color(0xFF3A78D1), size: 16.sp),
          hSpace(7),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 17.sp,
                fontWeight: FontWeight.w500,
                color: isDark
                    ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.85)
                    : const Color(0xFF1B3F6B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAllActivity() {
    if (_activityLogs.isEmpty) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        expand: false,
        builder: (_, controller) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Padding(
                padding: EdgeInsets.only(top: 12.h, bottom: 4.h),
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: Theme.of(context).dividerColor,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              child: Text(
                'Recent Activity',
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            Divider(height: 1, color: Theme.of(context).dividerColor),
            Expanded(
              child: ListView.separated(
                controller: controller,
                itemCount: _activityLogs.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: Theme.of(context).dividerColor),
                itemBuilder: (_, i) => _ActivityTile(log: _activityLogs[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityContent() {
    if (_activityLoading) {
      return Padding(
        padding: EdgeInsets.all(20.w),
        child: Center(
          child: SizedBox(
            width: 24.w,
            height: 24.w,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Theme.of(context).primaryColor,
            ),
          ),
        ),
      );
    }
    if (_activityError != null) {
      return Padding(
        padding: EdgeInsets.all(16.w),
        child: Text(
          _activityError!,
          style: TextStyle(
            fontSize: 16.sp,
            color: Colors.red,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }
    if (_activityLogs.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          children: [
            Icon(
              Icons.history_outlined,
              size: 36.sp,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            vSpace(8),
            Text(
              'No recent activity',
              style: TextStyle(
                fontSize: 17.sp,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      children: _activityLogs.take(3).map((log) => _ActivityTile(log: log)).toList(),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.log});

  final Map<String, dynamic> log;

  String _formatTime(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      // Backend stores timestamps in UTC. Laravel serialises them as ISO 8601
      // but may omit the 'Z' suffix (e.g. "2024-01-15 10:30:00"). Without a
      // timezone indicator Dart treats the string as local time, making the
      // displayed time wrong on any device not in UTC. Append 'Z' when there
      // is no timezone to force UTC interpretation before converting to local.
      final normalized =
          raw.contains('Z') || raw.contains('+') ? raw : '${raw}Z';
      final dt = DateTime.parse(normalized).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.isNegative) return DateFormat('d MMM • h:mm a').format(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays == 1) return 'Yesterday';
      return DateFormat('d MMM • h:mm a').format(dt);
    } catch (_) {
      return raw;
    }
  }

  String _actionLabel(String? action, String? status) {
    final a = (action ?? '').toLowerCase();
    final s = (status ?? '').toLowerCase();
    if (a.contains('login') || a.contains('sign_in')) {
      return (s == 'failed' || a.contains('failed')) ? 'Failed login attempt' : 'Signed in';
    }
    if (a.contains('logout') || a.contains('sign_out')) return 'Signed out';
    if (a.contains('session_takeover')) return 'Session takeover confirmed';
    if (a.contains('password')) return 'Password changed';
    if (a.contains('pin')) return 'PIN changed';
    return action ?? 'Security event';
  }

  String _deviceLabel(String? ua) {
    if (ua == null || ua.isEmpty) return 'Unknown device';
    // New format: "CommunalApp/1.0 (Pixel 7 Pro; Android 14)"
    // Extract the part before the first semicolon inside the parentheses.
    final parenContent = RegExp(r'\(([^)]+)\)').firstMatch(ua)?.group(1);
    if (parenContent != null) {
      final model = parenContent.split(';').first.trim();
      if (model.isNotEmpty &&
          model.toLowerCase() != 'android' &&
          model.toLowerCase() != 'ios' &&
          model.toLowerCase() != 'linux' &&
          model.toLowerCase() != 'macos') {
        return model;
      }
    }
    // Legacy format or unknown — fall back to OS sniffing.
    final u = ua.toLowerCase();
    if (u.contains('iphone')) return 'iPhone';
    if (u.contains('ipad')) return 'iPad';
    if (u.contains('ios')) return 'iPhone';
    if (u.contains('android')) return 'Android device';
    if (u.contains('windows')) return 'Windows PC';
    if (u.contains('mac')) return 'Mac';
    return 'Mobile device';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final muted = onSurface.withValues(alpha: 0.55);
    final action = log['action']?.toString();
    final status = log['status']?.toString();
    final ip = log['ip_address']?.toString();
    final ua = log['user_agent']?.toString();
    final createdAt = log['created_at']?.toString();
    final isFailed = (status ?? '').toLowerCase() == 'failed';

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38.w,
            height: 38.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isFailed
                  ? Colors.red.withValues(alpha: 0.12)
                  : theme.primaryColor.withValues(alpha: 0.12),
            ),
            child: Icon(
              isFailed ? Icons.warning_amber_rounded : Icons.shield_outlined,
              color: isFailed ? Colors.red : theme.primaryColor,
              size: 20.sp,
            ),
          ),
          hSpace(10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _actionLabel(action, status),
                  style: TextStyle(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w600,
                    color: onSurface,
                  ),
                ),
                vSpace(3),
                Row(
                  children: [
                    if (ip != null && ip.isNotEmpty) ...[
                      Icon(Icons.wifi_outlined, size: 13.sp, color: muted),
                      hSpace(3),
                      Text(ip, style: TextStyle(fontSize: 15.sp, color: muted)),
                      hSpace(6),
                    ],
                    Icon(Icons.devices_outlined, size: 13.sp, color: muted),
                    hSpace(3),
                    Expanded(
                      child: Text(
                        _deviceLabel(ua),
                        style: TextStyle(fontSize: 15.sp, color: muted),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                vSpace(2),
                Text(
                  _formatTime(createdAt),
                  style: TextStyle(fontSize: 14.sp, color: muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

