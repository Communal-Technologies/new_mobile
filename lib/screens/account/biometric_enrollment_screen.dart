import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:communal_mobile/core/security/biometric_key_service.dart';
import 'package:communal_mobile/core/security/biometric_signer_service.dart';
import 'package:communal_mobile/core/utils/biometric_service.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/data/local/biometric_prefs.dart';
import 'package:communal_mobile/injection.dart';

/// Audit M38 Phase D: user-facing enrollment + management screen for the
/// biometric-bound nonce signing flow.
///
/// Top of screen: hero icon (Face-ID brackets or fingerprint, depending on
/// what the device supports) inside a 15%-tinted primary-colour circle,
/// `'{Method} Available'` title, descriptor copy.
///
/// Master card: "Enable Biometric Authentication" + descriptor + switch.
///   - When toggled ON → confirmation modal → calls
///     [BiometricSignerService.enroll] (which generates the Keystore /
///     Secure-Enclave keypair behind a biometric prompt and posts the
///     public key to the backend).
///   - When toggled OFF → confirmation modal → calls
///     [BiometricSignerService.unenroll] (revokes server-side, deletes
///     the local key).
///
/// When master is ON, two further sections appear:
///   - "Use Biometric For" — granular per-feature toggles backed by
///     [BiometricPrefs]. App login is purely client-side (controls the
///     welcome-back auto-prompt). Transaction Authorization gates the
///     transfer / obligation flows; turning it off blocks transactions
///     until the user re-enables, since the audit M38 backend gate
///     enforces a valid signature on those endpoints.
///   - "Registered Biometrics" — informational read-only list of the
///     biometric methods the OS knows about (Face ID and / or
///     Fingerprint), each with an Active / Inactive badge.
class BiometricEnrollmentScreen extends StatefulWidget {
  const BiometricEnrollmentScreen({super.key});

  @override
  State<BiometricEnrollmentScreen> createState() =>
      _BiometricEnrollmentScreenState();
}

class _BiometricEnrollmentScreenState extends State<BiometricEnrollmentScreen> {
  final _signer = getIt<BiometricSignerService>();
  late BiometricPrefs _prefs;

  bool _loading = true;
  bool _busy = false; // master toggle in progress
  bool _hardwareAvailable = false;
  bool _masterEnabled = false;
  List<BiometricType> _availableTypes = const <BiometricType>[];

  @override
  void initState() {
    super.initState();
    _hydrate();
  }

  Future<void> _hydrate() async {
    final shared = await SharedPreferences.getInstance();
    _prefs = BiometricPrefs(shared);
    final hw = await _signer.isHardwareAvailable();
    final types = await BiometricService.getAvailableBiometrics();
    final enrolled = await _signer.isEnrolled();
    if (!mounted) return;
    setState(() {
      _hardwareAvailable = hw;
      _availableTypes = types;
      _masterEnabled = enrolled;
      _loading = false;
    });
  }

  // ---- Master toggle -------------------------------------------------------

  Future<void> _onMasterToggle(bool nextValue) async {
    if (_busy) return;
    final result = await _showConfirmModal(enabling: nextValue);
    if (result != true) return;
    setState(() => _busy = true);
    try {
      if (nextValue) {
        await _signer.enroll(deviceLabel: _deviceLabel());
        await _prefs.setAppLoginEnabled(true);
        await _prefs.setTransactionsEnabled(true);
      } else {
        await _signer.unenroll();
        await _prefs.resetAll();
      }
      if (!mounted) return;
      setState(() => _masterEnabled = nextValue);
    } on BiometricKeyException catch (e) {
      if (!mounted) return;
      _showSnack(_messageForBiometricError(e));
    } catch (e) {
      if (!mounted) return;
      _showSnack(
        e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool?> _showConfirmModal({required bool enabling}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BiometricConfirmModal(
        enabling: enabling,
        primaryMethodLabel: _primaryMethodLabel(),
      ),
    );
  }

  // ---- Granular toggles ----------------------------------------------------

  Future<void> _onAppLoginToggle(bool value) async {
    await _prefs.setAppLoginEnabled(value);
    setState(() {});
  }

  Future<void> _onTransactionsToggle(bool value) async {
    if (!value) {
      // Disabling has consequences (transfers blocked) — give the user
      // an out before flipping the switch.
      final confirm = await _showTransactionsDisableWarning();
      if (confirm != true) return;
    }
    await _prefs.setTransactionsEnabled(value);
    setState(() {});
  }

  Future<bool?> _showTransactionsDisableWarning() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disable for transactions?'),
        content: const Text(
          'Transfers and bill payments will be blocked until biometric '
          'authorization is re-enabled. App login can stay biometric.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Disable'),
          ),
        ],
      ),
    );
  }

  // ---- Helpers -------------------------------------------------------------

  /// Renders "Face ID" / "Fingerprint" / "Biometric" depending on what
  /// the device supports. Used as the hero title and inside copy.
  String _primaryMethodLabel() {
    if (_availableTypes.contains(BiometricType.face)) {
      return Platform.isIOS ? 'Face ID' : 'Face Unlock';
    }
    if (_availableTypes.contains(BiometricType.fingerprint)) {
      return Platform.isIOS ? 'Touch ID' : 'Fingerprint';
    }
    return 'Biometric';
  }

  String _deviceLabel() {
    if (Platform.isIOS) return 'iOS device';
    if (Platform.isAndroid) return 'Android device';
    return 'Unknown device';
  }

  String _messageForBiometricError(BiometricKeyException e) {
    switch (e.code) {
      case 'USER_CANCELED':
        return 'Cancelled.';
      case 'LOCKOUT':
        return 'Too many failed attempts. Try again later from device settings.';
      case 'UNAVAILABLE':
        return 'Biometric is not available on this device.';
      default:
        return e.message;
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // ---- Build ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.primaryColor;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.pop(),
        ),
        centerTitle: true,
        title: Text(
          'Biometric Authentication',
          style: TextStyle(
            color: Colors.black,
            fontSize: 17.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : !_hardwareAvailable
              ? _buildHardwareUnavailable(primary)
              : _buildContent(primary),
    );
  }

  Widget _buildHardwareUnavailable(Color primary) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 32.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _BiometricHeroIcon(primary: primary, methodLabel: 'Biometric'),
          vSpace(20),
          Text(
            'Biometric Not Available',
            style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w700),
          ),
          vSpace(8),
          Text(
            'This device does not support biometric authentication, or no '
            'biometric is enrolled in device settings.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.black54,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(Color primary) {
    final method = _primaryMethodLabel();
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20.w, 24.h, 20.w, 24.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero icon + title + slug (centred block)
          Center(child: _BiometricHeroIcon(primary: primary, methodLabel: method)),
          vSpace(16),
          Center(
            child: Text(
              '$method Available',
              style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w700),
            ),
          ),
          vSpace(6),
          Center(
            child: Text(
              'Use $method to quickly and securely access your account',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.black54,
                height: 1.4,
              ),
            ),
          ),
          vSpace(24),

          _MasterEnableCard(
            value: _masterEnabled,
            busy: _busy,
            method: method,
            onChanged: _onMasterToggle,
          ),

          if (_masterEnabled) ...[
            vSpace(28),
            _SectionTitle('Use Biometric For'),
            vSpace(12),
            _GranularToggleCard(
              icon: Icons.lock_outline,
              iconColor: const Color(0xFF2563EB),
              backgroundTint: const Color(0xFF2563EB).withValues(alpha: 0.10),
              title: 'App Login',
              subtitle: 'Sign in quickly using $method',
              value: _prefs.appLoginEnabled,
              onChanged: _onAppLoginToggle,
            ),
            vSpace(10),
            _GranularToggleCard(
              icon: Icons.check_circle_outline,
              iconColor: const Color(0xFF16A34A),
              backgroundTint: const Color(0xFF16A34A).withValues(alpha: 0.10),
              title: 'Transaction Authorization',
              subtitle:
                  'Authorize payments and transfers with $method or fingerprint',
              value: _prefs.transactionsEnabled,
              onChanged: _onTransactionsToggle,
            ),
            vSpace(28),
            _SectionTitle('Registered Biometrics'),
            vSpace(12),
            _RegisteredBiometricsCard(
              available: _availableTypes,
              primaryMethod: method,
              primaryColor: primary,
            ),
          ],
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
// Reusable widgets
// ───────────────────────────────────────────────────────────────────────────

/// 100×100 circle in primary @ 15% with the platform biometric icon at
/// 100% in the centre. Used both as the page hero and inside the enable
/// confirmation modal so the user sees the same visual cue.
class _BiometricHeroIcon extends StatelessWidget {
  const _BiometricHeroIcon({
    required this.primary,
    required this.methodLabel,
  });

  final Color primary;
  final String methodLabel;
  static const double size = 100;

  @override
  Widget build(BuildContext context) {
    final iconWidget = methodLabel.toLowerCase().contains('face')
        ? _FaceIdBrackets(color: primary, size: size * 0.55)
        : Icon(Icons.fingerprint, color: primary, size: size * 0.55);

    return Container(
      width: size.w,
      height: size.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: primary.withValues(alpha: 0.15),
      ),
      child: Center(child: iconWidget),
    );
  }
}

/// Approximation of the Face-ID brackets glyph: four L-shaped corners
/// around a stylised face. Pure paint widget so we don't need a custom
/// asset in the bundle.
class _FaceIdBrackets extends StatelessWidget {
  const _FaceIdBrackets({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _FaceIdBracketsPainter(color: color)),
    );
  }
}

class _FaceIdBracketsPainter extends CustomPainter {
  _FaceIdBracketsPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.shortestSide * 0.08;
    final corner = size.shortestSide * 0.22;
    final paint = Paint()
      ..color = color
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Top-left corner.
    canvas.drawLine(Offset(0, corner), const Offset(0, 0), paint);
    canvas.drawLine(const Offset(0, 0), Offset(corner, 0), paint);
    // Top-right.
    canvas.drawLine(Offset(size.width - corner, 0), Offset(size.width, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, corner), paint);
    // Bottom-left.
    canvas.drawLine(Offset(0, size.height - corner), Offset(0, size.height), paint);
    canvas.drawLine(Offset(0, size.height), Offset(corner, size.height), paint);
    // Bottom-right.
    canvas.drawLine(
      Offset(size.width - corner, size.height),
      Offset(size.width, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(size.width, size.height - corner),
      Offset(size.width, size.height),
      paint,
    );

    // Tiny face inside (eyes + smile).
    final eyeR = size.shortestSide * 0.04;
    final eyeY = size.height * 0.40;
    canvas.drawCircle(
      Offset(size.width * 0.36, eyeY),
      eyeR,
      Paint()..color = color,
    );
    canvas.drawCircle(
      Offset(size.width * 0.64, eyeY),
      eyeR,
      Paint()..color = color,
    );
    final smile = Path()
      ..moveTo(size.width * 0.34, size.height * 0.62)
      ..quadraticBezierTo(
        size.width * 0.50,
        size.height * 0.74,
        size.width * 0.66,
        size.height * 0.62,
      );
    canvas.drawPath(
      smile,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke * 0.7,
    );
  }

  @override
  bool shouldRepaint(covariant _FaceIdBracketsPainter old) =>
      old.color != color;
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 16.sp,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF1F1F1F),
      ),
    );
  }
}

class _MasterEnableCard extends StatelessWidget {
  const _MasterEnableCard({
    required this.value,
    required this.busy,
    required this.method,
    required this.onChanged,
  });

  final bool value;
  final bool busy;
  final String method;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: const Color(0xFFE7E7E7)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enable Biometric Authentication',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                vSpace(2),
                Text(
                  'Use your $method for secure access',
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          hSpace(12),
          if (busy)
            SizedBox(
              width: 24.w,
              height: 24.w,
              child: const CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Switch.adaptive(
              value: value,
              onChanged: onChanged,
            ),
        ],
      ),
    );
  }
}

class _GranularToggleCard extends StatelessWidget {
  const _GranularToggleCard({
    required this.icon,
    required this.iconColor,
    required this.backgroundTint,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final Color iconColor;
  final Color backgroundTint;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: const Color(0xFFE7E7E7)),
      ),
      child: Row(
        children: [
          Container(
            width: 38.w,
            height: 38.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: backgroundTint,
            ),
            child: Icon(icon, color: iconColor, size: 20.sp),
          ),
          hSpace(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                vSpace(2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12.sp, color: Colors.black54),
                ),
              ],
            ),
          ),
          hSpace(8),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// Single card with a horizontal divider between Face ID and Fingerprint
/// rows. Whichever methods the OS reports as available render in their
/// active palette + green "Active" badge; the unavailable method greys
/// out + "Inactive" badge.
class _RegisteredBiometricsCard extends StatelessWidget {
  const _RegisteredBiometricsCard({
    required this.available,
    required this.primaryMethod,
    required this.primaryColor,
  });

  final List<BiometricType> available;
  final String primaryMethod;
  final Color primaryColor;

  @override
  Widget build(BuildContext context) {
    final hasFace = available.contains(BiometricType.face);
    final hasFinger = available.contains(BiometricType.fingerprint);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: const Color(0xFFE7E7E7)),
      ),
      child: Column(
        children: [
          _RegisteredBiometricRow(
            iconBuilder: (color, size) =>
                _FaceIdBrackets(color: color, size: size),
            iconColor: hasFace
                ? primaryColor
                : const Color(0xFF9F9F9F).withValues(alpha: 0.4),
            iconBgColor: hasFace
                ? primaryColor.withValues(alpha: 0.12)
                : const Color(0xFFF1F1F1),
            title: 'Face ID',
            subtitle: 'Registered on this device',
            isActive: hasFace,
          ),
          const Divider(height: 1, color: Color(0xFFEDEDED)),
          _RegisteredBiometricRow(
            iconBuilder: (color, size) =>
                Icon(Icons.fingerprint, color: color, size: size),
            iconColor: hasFinger
                ? const Color(0xFF16A34A)
                : const Color(0xFF9F9F9F).withValues(alpha: 0.4),
            iconBgColor: hasFinger
                ? const Color(0xFF16A34A).withValues(alpha: 0.12)
                : const Color(0xFFF1F1F1),
            title: 'Fingerprint',
            subtitle: 'Available as alternative method',
            isActive: hasFinger,
          ),
        ],
      ),
    );
  }
}

class _RegisteredBiometricRow extends StatelessWidget {
  const _RegisteredBiometricRow({
    required this.iconBuilder,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.subtitle,
    required this.isActive,
  });

  final Widget Function(Color color, double size) iconBuilder;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String subtitle;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 42.w,
            height: 42.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: iconBgColor,
            ),
            child: Center(
              child: SizedBox(
                width: 24.w,
                height: 24.w,
                child: iconBuilder(iconColor, 24.sp),
              ),
            ),
          ),
          hSpace(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: isActive ? Colors.black : Colors.black54,
                  ),
                ),
                vSpace(4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.black54,
                  ),
                ),
                vSpace(6),
                _StatusBadge(isActive: isActive),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isActive});
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? const Color(0xFF16A34A) : const Color(0xFF9F9F9F);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isActive ? Icons.check_circle : Icons.remove_circle_outline,
            color: color,
            size: 12.sp,
          ),
          hSpace(4),
          Text(
            isActive ? 'Active' : 'Inactive',
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet shown when the user toggles the master switch. Different
/// icon, copy, and CTA based on whether the switch is going on or off.
class _BiometricConfirmModal extends StatelessWidget {
  const _BiometricConfirmModal({
    required this.enabling,
    required this.primaryMethodLabel,
  });

  final bool enabling;
  final String primaryMethodLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.primaryColor;
    final accent = enabling ? primary : Colors.red;
    final bgTint = accent.withValues(alpha: 0.10);

    final title = enabling
        ? 'Enable Biometric Authentication?'
        : 'Disable Biometric Authentication?';
    final body = enabling
        ? "You'll be able to use $primaryMethodLabel or fingerprint to sign in "
            'and authorize transactions.\n\nYour biometric data stays on your device.'
        : "You'll need to use your password or PIN to sign in and authorize "
            'transactions.\n\nYou can re-enable this anytime.';
    final primaryLabel = enabling ? 'Enable Biometric' : 'Disable';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 20.h),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Drag handle.
            Container(
              width: 36.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            vSpace(20),
            Container(
              width: 76.w,
              height: 76.w,
              decoration: BoxDecoration(shape: BoxShape.circle, color: bgTint),
              child: Center(
                child: enabling
                    ? _FaceIdBrackets(color: accent, size: 38.w)
                    : Icon(
                        Icons.priority_high_rounded,
                        color: accent,
                        size: 36.sp,
                      ),
              ),
            ),
            vSpace(16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            vSpace(8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.black54,
                height: 1.4,
              ),
            ),
            vSpace(20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),
                child: Text(
                  primaryLabel,
                  style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            vSpace(10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFCCCCCC)),
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  foregroundColor: Colors.black87,
                ),
                child: Text(
                  'Cancel',
                  style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
