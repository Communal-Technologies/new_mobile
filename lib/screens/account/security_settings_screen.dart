import 'package:communal_mobile/core/security/biometric_signer_service.dart';
import 'package:communal_mobile/core/utils/biometric_service.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/injection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

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
  bool _allowScreenshotEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadBiometricStatus();
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
                          'Secure Acctount',
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
                    title: 'Change Login Password',
                    subtitle: 'Update your account password',
                    onTap: () {},
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
                    subtitle: 'Get notified on new deviceS login',
                    value: _loginAlertEnabled,
                    onChanged: (v) => setState(() => _loginAlertEnabled = v),
                  ),
                  _toggleRow(
                    icon: Icons.notification_important_outlined,
                    iconColor: const Color(0xFF742CE7),
                    iconBg: const Color(0xFFEFE6FD),
                    title: 'Transactions Alert',
                    subtitle: 'Alert for all transactions',
                    value: _transactionAlertEnabled,
                    onChanged: (v) =>
                        setState(() => _transactionAlertEnabled = v),
                  ),
                  _toggleRow(
                    icon: Icons.image_outlined,
                    iconColor: const Color(0xFFB8860B),
                    iconBg: const Color(0xFFFFF4CC),
                    title: 'Allow Screenshot',
                    subtitle: 'Enable taking screenshots in the app',
                    value: _allowScreenshotEnabled,
                    onChanged: (v) =>
                        setState(() => _allowScreenshotEnabled = v),
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
                Text(
                  'See all',
                  style: TextStyle(
                    fontSize: 17.sp,
                    color: primary,
                    fontWeight: FontWeight.w700,
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
              child: Column(
                children: const [
                  _ActivityTile(
                    title: 'New login from Android device',
                    location: 'Lagos, Nigeria',
                    time: '2 mins ago',
                  ),
                  _ActivityTile(
                    title: 'PIN changed successfully',
                    location: 'Abuja, Nigeria',
                    time: 'Yesterday • 10:42 AM',
                  ),
                  _ActivityTile(
                    title: 'Biometric authentication enabled',
                    location: 'Lagos, Nigeria',
                    time: 'Jul 12 • 08:19 PM',
                  ),
                ],
              ),
            ),
            vSpace(18),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                color: const Color(0xFFBEDBFF),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: const Color(0xFF8CB9F5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Security Tips',
                    style: TextStyle(
                      fontSize: 19.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF12427A),
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
            activeColor: Theme.of(context).primaryColor,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }

  Widget _tip(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check, color: const Color(0xFF2F78D8), size: 16.sp),
          hSpace(7),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 17.sp,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF1B3F6B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({
    required this.title,
    required this.location,
    required this.time,
  });

  final String title;
  final String location;
  final String time;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final muted = onSurface.withValues(alpha: 0.6);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40.w,
            height: 40.w,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF742CE7), Color(0xFF06FDF5)],
              ),
            ),
            child: Icon(Icons.desktop_windows_outlined, color: Colors.white, size: 20.sp),
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
                vSpace(4),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 13.sp, color: muted),
                    hSpace(3),
                    Text(
                      location,
                      style: TextStyle(
                        fontSize: 17.sp,
                        color: muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    hSpace(4),
                    Icon(Icons.access_time, size: 13.sp, color: muted),
                    hSpace(3),
                    Expanded(
                      child: Text(
                        time,
                        style: TextStyle(
                          fontSize: 17.sp,
                          color: muted,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
