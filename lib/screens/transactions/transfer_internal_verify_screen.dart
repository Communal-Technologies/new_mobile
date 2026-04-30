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
import 'package:communal_mobile/core/widgets/space.dart';
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
/// PIN is the default auth mechanism — the keypad below the recipient
/// card collects a 4-digit transaction PIN and submits via the
/// `X-Security-Pin` header that the backend's `RequireBiometricSignature`
/// middleware accepts as a fallback to the biometric-signature headers.
///
/// The empty cell on the keypad (bottom-left, where most numeric pads
/// are blank) is occupied by a fingerprint icon. Tapping it shortcuts
/// to the biometric-signing flow when the device + user have biometric
/// enrolled; otherwise it surfaces a [AppToast] explaining what's
/// missing rather than a snackbar.
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

  final _repo = getIt<TransferRepository>();
  final _favorites = getIt<TransferFavoritesPrefs>();
  final _biometricSigner = getIt<BiometricSignerService>();
  // Audit M28: swallows rapid double-taps on Confirm Transfer.
  final TapDebouncer _confirmDebouncer = TapDebouncer();

  String _pin = '';
  bool _submitting = false;

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
    setState(() => _pin += d);
    if (_pin.length == _pinLength) {
      // Tiny delay so the user sees the last dot fill before the
      // overlay flips to the submitting spinner.
      Future.delayed(const Duration(milliseconds: 80), () {
        if (mounted && !_submitting) _confirmDebouncer.run(_confirmWithPin);
      });
    }
  }

  void _onBackspace() {
    if (_submitting || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  // ---- Biometric shortcut --------------------------------------------------

  Future<void> _onBiometricTap() async {
    if (_submitting) return;
    try {
      final shared = await shared_prefs.SharedPreferences.getInstance();
      final prefs = BiometricPrefs(shared);
      if (!prefs.transactionsEnabled) {
        AppToast.error(
          'Biometric for transactions is off. Enable it in '
          'Settings → Biometric Authentication.',
        );
        return;
      }
      final hwAvailable = await BiometricService.isBiometricAvailable();
      if (!hwAvailable) {
        AppToast.error(
          'Your device does not have biometrics set up. '
          'Add a fingerprint or face in your device settings first.',
        );
        return;
      }
      final enrolled = await _biometricSigner.isEnrolled();
      if (!enrolled) {
        AppToast.error(
          'Biometric authentication is not enabled for this account. '
          'Set it up in Settings → Biometric Authentication.',
        );
        return;
      }
      // ignore: unawaited_futures
      _confirmDebouncer.run(_confirmWithBiometric);
    } catch (e) {
      AppToast.error(
        'Could not check biometrics: '
        '${e.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }

  // ---- Submit paths --------------------------------------------------------

  Future<void> _confirmWithPin() async {
    if (_submitting || _pin.length != _pinLength) return;
    // ignore: unawaited_futures
    HapticFeedback.lightImpact();
    setState(() => _submitting = true);
    try {
      await _runInitiate(pin: _pin, biometricHeaders: null);
    } catch (e) {
      if (!mounted) return;
      // Wipe on failure so user can re-enter; failure path includes
      // wrong PIN (which the backend tracks toward lockout).
      setState(() {
        _pin = '';
      });
      AppToast.error(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _confirmWithBiometric() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      // Audit M38: backend mints a one-time nonce via /security/biometric/
      // challenge; we sign it with the Keystore-bound key; headers travel
      // with the initiate call. RequireBiometricSignature verifies before
      // letting the request through.
      final biometricHeaders = await _biometricSigner.signTransferIntent(
        promptTitle: 'Authorize transfer',
        promptSubtitle: 'Use biometrics to confirm this transfer',
      );
      await _runInitiate(
        pin: null,
        biometricHeaders: biometricHeaders.toHeaders(),
      );
    } catch (e) {
      if (!mounted) return;
      AppToast.error(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _runInitiate({
    required String? pin,
    required Map<String, String>? biometricHeaders,
  }) async {
    final currencySymbol = currencySymbolForCode(widget.currency);
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
    return Scaffold(
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
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Enter Transaction PIN',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.w700),
              ),
              vSpace(4),
              Text(
                'Enter your 4-digit PIN to authorise this transfer.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.sp,
                  color: Theme.of(context).colorScheme.onSurface
                      .withValues(alpha: 0.6),
                  fontWeight: FontWeight.w500,
                ),
              ),
              vSpace(12),
              _buildRecipientCard(),
              vSpace(16),
              _buildAmountBanner(),
              vSpace(20),
              _buildPinDots(),
              vSpace(16),
              Expanded(child: _buildKeypad()),
              if (_submitting)
                Padding(
                  padding: EdgeInsets.only(top: 8.h),
                  child: SizedBox(
                    width: 22.w,
                    height: 22.w,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            ],
          ),
        ),
      ),
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
                fontSize: 14.sp,
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
                  style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700),
                ),
                vSpace(2),
                Text(
                  '${widget.recipient.bank} • ${widget.recipient.accountNumber}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface
                        .withValues(alpha: 0.6),
                    fontSize: 13.sp,
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
    final symbol = currencySymbolForCode(widget.currency);
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
            style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade700),
          ),
          vSpace(2),
          Text(
            '$symbol${formatMoney(amountMajor)}',
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

  Widget _buildPinDots() {
    final activeColor = Theme.of(context).primaryColor;
    final inactiveColor = Theme.of(context).dividerColor;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_pinLength, (i) {
        final filled = i < _pin.length;
        return Container(
          margin: EdgeInsets.symmetric(horizontal: 8.w),
          width: 14.w,
          height: 14.w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? activeColor : Colors.transparent,
            border: Border.all(
              color: filled ? activeColor : inactiveColor,
              width: 1.5,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildKeypad() {
    // 4 rows × 3 cols. Bottom-left cell is the biometric shortcut so
    // the shape matches every other transaction PIN screen the user
    // has seen (1-9 across the top three rows, [bio] [0] [back]
    // along the bottom).
    return GridView.count(
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      childAspectRatio: 1.6,
      mainAxisSpacing: 6.h,
      crossAxisSpacing: 6.w,
      children: [
        _digit('1'),
        _digit('2'),
        _digit('3'),
        _digit('4'),
        _digit('5'),
        _digit('6'),
        _digit('7'),
        _digit('8'),
        _digit('9'),
        _biometricKey(),
        _digit('0'),
        _backspaceKey(),
      ],
    );
  }

  Widget _digit(String d) {
    return InkWell(
      onTap: () => _onDigit(d),
      borderRadius: BorderRadius.circular(12.r),
      child: Center(
        child: Text(
          d,
          style: TextStyle(
            fontSize: 26.sp,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _biometricKey() {
    final color = Theme.of(context).primaryColor;
    return InkWell(
      onTap: _onBiometricTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Center(
        child: Icon(Icons.fingerprint, size: 30.sp, color: color),
      ),
    );
  }

  Widget _backspaceKey() {
    return InkWell(
      onTap: _onBackspace,
      borderRadius: BorderRadius.circular(12.r),
      child: Center(
        child: Icon(
          Icons.backspace_outlined,
          size: 24.sp,
          color: Theme.of(context).colorScheme.onSurface
              .withValues(alpha: 0.7),
        ),
      ),
    );
  }
}
