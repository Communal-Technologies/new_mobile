import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:communal_mobile/core/security/biometric_signer_service.dart';
import 'package:communal_mobile/core/utils/biometric_service.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/data/local/biometric_prefs.dart';
import 'package:communal_mobile/injection.dart';

/// Biometric alternative to typing the transaction PIN on an account-action
/// gate — leaving a cooperative, freezing the wallet, deleting the account.
///
/// Renders nothing at all unless the member could actually use it: biometric
/// authorisation switched on in Settings, hardware enrolled on the device, and a
/// device key registered with the backend. So a member without biometrics sees
/// the PIN screen exactly as before.
///
/// [onAuthorized] runs once the authorisation has been minted server-side, and
/// is the same continuation the PIN path takes — the marker is what the action
/// spends, and it does not care which factor produced it.
class BiometricActionButton extends StatefulWidget {
  const BiometricActionButton({
    super.key,
    required this.label,
    required this.promptSubtitle,
    required this.onAuthorized,
    required this.onFailed,
    this.enabled = true,
  });

  final String label;
  final String promptSubtitle;
  final Future<void> Function() onAuthorized;
  final void Function(String message) onFailed;
  final bool enabled;

  @override
  State<BiometricActionButton> createState() => _BiometricActionButtonState();
}

class _BiometricActionButtonState extends State<BiometricActionButton> {
  final _signer = getIt<BiometricSignerService>();

  bool _available = false;
  bool _busy = false;
  String _method = 'Biometric';

  @override
  void initState() {
    super.initState();
    _resolveAvailability();
  }

  Future<void> _resolveAvailability() async {
    try {
      final shared = await SharedPreferences.getInstance();
      if (!BiometricPrefs(shared).transactionsEnabled) return;
      if (!await BiometricService.isBiometricAvailable()) return;
      if (!await _signer.isEnrolled()) return;
      final method = await BiometricService.getBiometricName();
      if (!mounted) return;
      setState(() {
        _available = true;
        _method = method;
      });
    } catch (_) {
      // An unreadable biometric state is not an error the user has to see: the
      // PIN field is right there, and it is the path this button shortcuts.
    }
  }

  Future<void> _authorize() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _signer.signAccountActionIntent(
        promptTitle: widget.label,
        promptSubtitle: widget.promptSubtitle,
      );
      if (!mounted) return;
      await widget.onAuthorized();
      if (!mounted) return;
      setState(() => _busy = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      widget.onFailed(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_available) return const SizedBox.shrink();
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Column(
      children: [
        vSpace(24),
        Row(
          children: [
            Expanded(child: Divider(color: Theme.of(context).dividerColor)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.w),
              child: Text(
                'or',
                style: TextStyle(
                  fontSize: 16.sp,
                  color: onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
            Expanded(child: Divider(color: Theme.of(context).dividerColor)),
          ],
        ),
        vSpace(16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: (widget.enabled && !_busy) ? _authorize : null,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF742CE7),
              side: const BorderSide(color: Color(0xFF742CE7), width: 1.5),
              padding: EdgeInsets.symmetric(vertical: 14.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
            icon: _busy
                ? SizedBox(
                    height: 16.sp,
                    width: 16.sp,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(Icons.fingerprint, size: 20.sp),
            label: Text(
              'Use $_method instead',
              style: TextStyle(
                fontSize: 17.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
