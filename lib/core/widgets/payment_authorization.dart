import 'package:communal_mobile/core/security/biometric_key_service.dart';
import 'package:communal_mobile/core/security/biometric_signer_service.dart';
import 'package:communal_mobile/core/utils/biometric_service.dart';
import 'package:communal_mobile/core/utils/tap_debouncer.dart';
import 'package:communal_mobile/core/widgets/app_toast.dart';
import 'package:communal_mobile/core/widgets/loader_overlay.dart';
import 'package:communal_mobile/core/widgets/transaction_pin_pad.dart';
import 'package:communal_mobile/cubits/connectivity/connectivity_cubit.dart';
import 'package:communal_mobile/data/local/biometric_prefs.dart';
import 'package:communal_mobile/data/repositories/transfer_repository.dart';
import 'package:communal_mobile/injection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart' as shared_prefs;

/// Authorising a payment or an account action (leaving a cooperative, freezing
/// or deleting the account), identical on every screen that asks for the
/// transaction PIN.
///
/// Biometrics first when this device may authorise payments: the prompt opens
/// with the screen and the biometric key sits in the keypad's corner. The
/// in-app PIN pad is always there as the fallback — the only path when
/// biometrics is not set up, and the only path once biometrics has failed
/// [maxBiometricFailures] times. No text field is involved, so the system
/// keyboard never opens over the payment summary.
///
/// While the payment runs the screen is covered by [LoaderOverlay], started
/// only after the OS biometric prompt has returned so it never paints under it.
mixin PaymentAuthorization<T extends StatefulWidget> on State<T> {
  static const int pinLength = 4;
  static const int maxBiometricFailures = 3;

  final BiometricSignerService biometricSigner = getIt<BiometricSignerService>();
  final TransferRepository _pinRepository = getIt<TransferRepository>();
  final TapDebouncer _authorizeDebouncer = TapDebouncer();

  String _pin = '';
  bool _submitting = false;
  bool _showLoader = false;

  /// True only when transactions-biometric is enabled, the device has hardware
  /// enrolled, and the backend says this device's key may authorise a payment.
  bool _biometricAvailable = false;
  int _biometricFailures = 0;

  bool get offerBiometric =>
      _biometricAvailable && _biometricFailures < maxBiometricFailures;

  bool get authorizationInFlight => _submitting;

  /// The intent `verify-security-pin` mints the PIN marker for.
  String get pinIntent;

  /// Opens the OS biometric prompt and signs this screen's intent.
  Future<BiometricSignedHeaders> signBiometricIntent();

  /// Runs the payment once authorised: exactly one of [pin] (already verified,
  /// so its marker exists) and [biometricHeaders] is set.
  Future<void> submitAuthorized({
    String? pin,
    Map<String, String>? biometricHeaders,
  });

  /// Checked before any prompt opens or PIN is verified; a message refuses.
  String? paymentBlockedReason() => null;

  @override
  void initState() {
    super.initState();
    _resolveBiometricAvailability();
  }

  Future<void> _resolveBiometricAvailability() async {
    try {
      final shared = await shared_prefs.SharedPreferences.getInstance();
      final enabled = BiometricPrefs(shared).transactionsEnabled;
      final hw = enabled && await BiometricService.isBiometricAvailable();
      final available = hw && await biometricSigner.canAuthorizePayments();
      if (!mounted || !available) return;
      setState(() => _biometricAvailable = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_submitting && _pin.isEmpty) {
          _authorizeDebouncer.run(_confirmWithBiometric);
        }
      });
    } catch (_) {
      // Leave the key hidden on any probe failure.
    }
  }

  void _onDigit(String d) {
    if (_submitting || _pin.length >= pinLength) return;
    HapticFeedback.selectionClick();
    setState(() => _pin += d);
    if (_pin.length == pinLength) {
      // Tiny delay so the user sees the last circle fill before the pad greys
      // out for submission.
      Future.delayed(const Duration(milliseconds: 80), () {
        if (mounted && !_submitting) _authorizeDebouncer.run(_confirmWithPin);
      });
    }
  }

  void _onBackspace() {
    if (_submitting || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  bool _mayAuthorize() {
    if (!context.read<ConnectivityCubit>().isConnected) {
      AppToast.error('You are offline. Reconnect and try again.');
      return false;
    }
    final blocked = paymentBlockedReason();
    if (blocked != null) {
      AppToast.error(blocked);
      return false;
    }
    return true;
  }

  Future<void> _confirmWithPin() async {
    if (_submitting || _pin.length != pinLength) return;
    if (!_mayAuthorize()) {
      setState(() => _pin = '');
      return;
    }
    // ignore: unawaited_futures
    HapticFeedback.lightImpact();
    setState(() {
      _submitting = true;
      _showLoader = true;
    });
    try {
      await _pinRepository.verifySecurityPin(_pin, intent: pinIntent);
      await submitAuthorized(pin: _pin);
    } catch (e) {
      if (!mounted) return;
      // Wipe on failure so the member can re-enter; a wrong PIN counts toward
      // the lockout on the backend.
      setState(() => _pin = '');
      AppToast.error(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
          _showLoader = false;
        });
      }
    }
  }

  Future<void> _confirmWithBiometric() async {
    if (_submitting || !offerBiometric || !_mayAuthorize()) return;
    setState(() => _submitting = true);
    try {
      final signed = await signBiometricIntent();
      if (mounted) setState(() => _showLoader = true);
      await submitAuthorized(biometricHeaders: signed.toHeaders());
    } on BiometricKeyException catch (e) {
      if (!mounted || e.code == 'USER_CANCELED') return;
      setState(() {
        _biometricFailures = e.code == 'LOCKOUT'
            ? maxBiometricFailures
            : _biometricFailures + 1;
      });
      AppToast.error(
        offerBiometric
            ? 'Biometrics did not work. Try again or enter your PIN.'
            : 'Biometrics failed too many times. Enter your PIN instead.',
      );
    } catch (e) {
      if (!mounted) return;
      AppToast.error(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
          _showLoader = false;
        });
      }
    }
  }

  Widget buildPaymentPinPad({IconData biometricIcon = Icons.fingerprint}) {
    return TransactionPinPad(
      pin: _pin,
      length: pinLength,
      onDigit: _onDigit,
      onBackspace: _onBackspace,
      busy: _submitting,
      onBiometric: offerBiometric
          ? () => _authorizeDebouncer.run(_confirmWithBiometric)
          : null,
      biometricIcon: biometricIcon,
    );
  }

  /// Wraps the screen's scaffold so the overlay also covers the app bar.
  Widget withPaymentLoader(Widget scaffold) {
    return Stack(
      fit: StackFit.expand,
      children: [
        scaffold,
        if (_showLoader) const Positioned.fill(child: LoaderOverlay()),
      ],
    );
  }
}
