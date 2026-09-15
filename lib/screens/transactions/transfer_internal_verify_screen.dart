import 'package:communal_mobile/core/security/biometric_key_service.dart';
import 'package:communal_mobile/core/security/biometric_signer_service.dart';
import 'package:communal_mobile/core/utils/app_currency.dart';
import 'package:communal_mobile/core/utils/biometric_service.dart';
import 'package:communal_mobile/data/local/biometric_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart' as shared_prefs;
import 'package:communal_mobile/core/utils/idempotency.dart';
import 'package:communal_mobile/core/utils/money.dart';
import 'package:communal_mobile/core/utils/money_formatter.dart';
import 'package:communal_mobile/core/utils/tap_debouncer.dart';
import 'package:communal_mobile/core/widgets/app_toast.dart';
import 'package:communal_mobile/core/widgets/loader_overlay.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/core/widgets/transaction_pin_pad.dart';
import 'package:communal_mobile/data/local/transfer_favorites_prefs.dart';
import 'package:communal_mobile/data/repositories/transfer_repository.dart';
import 'package:communal_mobile/injection.dart';
import 'package:communal_mobile/screens/obligations/data/obligation_nip_settlement.dart';
import 'package:communal_mobile/screens/transactions/models/transaction_details_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

/// Transfer authorization screen.
///
/// Biometrics first when this device may authorise payments: the prompt opens
/// with the screen. The PIN pad below the recipient card is the fallback — the
/// only path when biometrics is not set up, and the only path once biometrics has
/// failed [_maxBiometricFailures] times. A PIN is submitted through
/// `verifySecurityPin`, which writes the marker transactions-svc checks.
class TransferInternalVerifyScreen extends StatefulWidget {
  const TransferInternalVerifyScreen({
    super.key,
    required this.recipient,
    required this.amountMinor,
    required this.currency,
    required this.narration,
    required this.saveAsBeneficiary,
    this.useExternalNipFlow = false,
    this.obligationNipSettlement,
  });

  final TransferFavorite recipient;

  /// Integer count of the smallest unit of [currency]. Audit M20 leaf migration.
  final int amountMinor;

  /// ISO 4217 alpha-3 code.
  final String currency;
  final String narration;
  final bool saveAsBeneficiary;

  /// When true, completes an NIP transfer using [recipient.accountId] as counterparty.
  final bool useExternalNipFlow;

  final ObligationNipSettlement? obligationNipSettlement;

  @override
  State<TransferInternalVerifyScreen> createState() =>
      _TransferInternalVerifyScreenState();
}

class _TransferInternalVerifyScreenState
    extends State<TransferInternalVerifyScreen> {
  static const int _pinLength = 4;
  static const int _maxBiometricFailures = 3;

  final _repo = getIt<TransferRepository>();
  final _favorites = getIt<TransferFavoritesPrefs>();
  final _biometricSigner = getIt<BiometricSignerService>();
  // Audit M28: swallows rapid double-taps on Confirm Transfer.
  final TapDebouncer _confirmDebouncer = TapDebouncer();

  String _pin = '';
  bool _submitting = false;

  /// Separate from [_submitting], which is already set while the OS biometric
  /// prompt is open: the overlay must not paint underneath that prompt.
  bool _showLoader = false;

  /// True only when transactions-biometric is enabled, the device has hardware
  /// enrolled, and the backend says this device's key may authorise a payment
  /// (a factor-verified enrollment and a transaction PIN on the account).
  bool _biometricAvailable = false;
  int _biometricFailures = 0;

  bool get _offerBiometric =>
      _biometricAvailable && _biometricFailures < _maxBiometricFailures;

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
      final available = hw && await _biometricSigner.canAuthorizePayments();
      if (!mounted || !available) return;
      setState(() => _biometricAvailable = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_submitting && _pin.isEmpty) {
          _confirmDebouncer.run(_confirmWithBiometric);
        }
      });
    } catch (_) {
      // Leave the key hidden on any probe failure.
    }
  }

  /// Audit M23: minted once per screen mount and reused across retries so a
  /// network drop + user retry on the Confirm button dedupes server-side.
  /// A fresh key is only generated when the user navigates away and re-enters.
  late final String _idempotencyKey = newIdempotencyKey();

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) {
      final s = parts.first;
      return (s.length >= 2 ? s.substring(0, 2) : s).toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  // ---- PIN keypad ----------------------------------------------------------

  void _onDigit(String d) {
    if (_submitting || _pin.length >= _pinLength) return;
    HapticFeedback.selectionClick();
    setState(() => _pin += d);
    if (_pin.length == _pinLength) {
      // Tiny delay so the user sees the last circle fill before the pad greys
      // out for submission.
      Future.delayed(const Duration(milliseconds: 80), () {
        if (mounted && !_submitting) _confirmDebouncer.run(_confirmWithPin);
      });
    }
  }

  void _onBackspace() {
    if (_submitting || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  // ---- Submit paths --------------------------------------------------------

  Future<void> _confirmWithPin() async {
    if (_submitting || _pin.length != _pinLength) return;
    // ignore: unawaited_futures
    HapticFeedback.lightImpact();
    setState(() {
      _submitting = true;
      _showLoader = true;
    });
    try {
      // transactions-svc's /transfer/initiate no longer validates the PIN
      // inline (it can't — security_pin lives on tbl_users, which only the
      // monolith may touch). It instead checks a Redis flag the monolith's
      // verify-security-pin sets on success, so that call has to happen
      // here first.
      await _repo.verifySecurityPin(_pin, intent: 'transfer');
      await _runInitiate(pin: _pin, biometricHeaders: null);
    } catch (e) {
      if (!mounted) return;
      // Wipe on failure so user can re-enter; failure path includes
      // wrong PIN (which the backend tracks toward lockout).
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
    if (_submitting || !_offerBiometric) return;
    setState(() => _submitting = true);
    try {
      // Audit M38: backend mints a one-time nonce via /security/biometric/
      // challenge; we sign it with the Keystore-bound key; headers travel
      // with the initiate call.
      final biometricHeaders = await _biometricSigner.signTransferIntent(
        promptTitle: 'Authorize transfer',
        promptSubtitle: 'Use biometrics to confirm this transfer',
      );
      if (mounted) setState(() => _showLoader = true);
      await _runInitiate(
        pin: null,
        biometricHeaders: biometricHeaders.toHeaders(),
      );
    } on BiometricKeyException catch (e) {
      if (!mounted || e.code == 'USER_CANCELED') return;
      setState(() {
        _biometricFailures = e.code == 'LOCKOUT'
            ? _maxBiometricFailures
            : _biometricFailures + 1;
      });
      AppToast.error(
        _offerBiometric
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

  Future<void> _runInitiate({
    required String? pin,
    required Map<String, String>? biometricHeaders,
  }) async {
    final currencySymbol =
        activeCurrency.display.forCurrency(widget.currency).symbol;
    final currencyCode = widget.currency;

    final TransferInitiationResult result;
    if (widget.useExternalNipFlow) {
      result = await _repo.initiateTransfer(
        type: 'NIPTransfer',
        amountMinor: widget.amountMinor,
        narration: widget.narration.trim().isEmpty
            ? 'Transfer'
            : widget.narration,
        counterPartyId: widget.recipient.accountId,
        currencyCode: currencyCode,
        idempotencyKey: _idempotencyKey,
        biometricHeaders: biometricHeaders,
        pin: pin,
        beneficiaryName: widget.recipient.accountName,
        beneficiaryBank: widget.recipient.bank,
        beneficiaryAccount: widget.recipient.accountNumber,
      );
    } else {
      result = await _repo.initiateTransfer(
        type: 'BookTransfer',
        amountMinor: widget.amountMinor,
        narration: widget.narration.trim().isEmpty
            ? 'Transfer'
            : widget.narration,
        destinationAccountId: widget.recipient.accountId,
        currencyCode: currencyCode,
        idempotencyKey: _idempotencyKey,
        biometricHeaders: biometricHeaders,
        pin: pin,
        beneficiaryName: widget.recipient.accountName,
        beneficiaryBank: widget.recipient.bank,
        beneficiaryAccount: widget.recipient.accountNumber,
      );
    }
    if (widget.saveAsBeneficiary) {
      await _favorites.upsert(widget.recipient);
    }
    if (!mounted) return;
    final mapped = transactionStatusFromApi(result.status);
    // ignore: unawaited_futures
    context.pushNamed(
      'transaction-receipt',
      extra: {
        'details': TransactionDetailsData(
          id: result.transferId,
          counterpartyName: widget.recipient.accountName,
          counterpartyBank: widget.recipient.bank,
          counterpartyAccount: widget.recipient.accountNumber,
          amount: widget.amountMinor / factorFor(widget.currency),
          currencySymbol: currencySymbol,
          currencyCode: currencyCode,
          transactionType:
              widget.useExternalNipFlow ? 'NIP Transfer' : 'Book Transfer',
          dateTime: DateTime.now(),
          sessionId: result.transferId,
          reference: result.reference,
          description: widget.narration,
          paymentMethod: 'Wallet',
          fees: 0,
          isIncoming: false,
          status: mapped,
          failureReason: result.failureReason,
        ),
        if (widget.obligationNipSettlement != null)
          'obligationNipSettlement':
              widget.obligationNipSettlement!.toJson(),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
    return Stack(
      fit: StackFit.expand,
      children: [
        Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            titleSpacing: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 22),
              onPressed: () => context.pop(),
            ),
            title: const Text('Verify Transaction'),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              child: Column(
                children: [
                  Text(
                    _offerBiometric
                        ? 'Confirm Transfer'
                        : 'Enter Transaction PIN',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  vSpace(4),
                  Text(
                    _offerBiometric
                        ? 'Use biometrics, or enter your 4-digit PIN.'
                        : 'Enter your 4-digit PIN to authorise this transfer.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15.sp,
                      color: muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  vSpace(12),
                  _buildRecipientCard(),
                  vSpace(12),
                  _buildAmountBanner(),
                  vSpace(20),
                  TransactionPinPad(
                    pin: _pin,
                    length: _pinLength,
                    onDigit: _onDigit,
                    onBackspace: _onBackspace,
                    busy: _submitting,
                    onBiometric: _offerBiometric
                        ? () => _confirmDebouncer.run(_confirmWithBiometric)
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_showLoader) const Positioned.fill(child: LoaderOverlay()),
      ],
    );
  }

  // ---- Sub-widgets ---------------------------------------------------------

  Widget _buildRecipientCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18.r,
            backgroundColor: const Color(0xFF8F6BFF),
            child: Text(
              _initials(widget.recipient.accountName),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16.sp,
              ),
            ),
          ),
          hSpace(10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.recipient.accountName,
                  style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w700),
                ),
                vSpace(2),
                Text(
                  '${widget.recipient.bank} • ${widget.recipient.accountNumber}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface
                        .withValues(alpha: 0.6),
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountBanner() {
    final display = activeCurrency.display.forCurrency(widget.currency);
    final amountMajor = widget.amountMinor / factorFor(widget.currency);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: isDark
            ? Theme.of(context).primaryColor.withValues(alpha: 0.16)
            : const Color(0xFFEFE7FF),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        children: [
          Text(
            "You're sending",
            style: TextStyle(fontSize: 15.sp, color: Colors.grey.shade700),
          ),
          vSpace(2),
          Text(
            display.adorn(formatMoney(amountMajor)),
            style: TextStyle(
              fontSize: 24.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF7434FF),
            ),
          ),
        ],
      ),
    );
  }
}
