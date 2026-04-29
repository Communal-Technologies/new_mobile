import 'package:communal_mobile/core/security/biometric_signer_service.dart';
import 'package:communal_mobile/core/utils/app_currency.dart';
import 'package:communal_mobile/data/local/biometric_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart' as shared_prefs;
import 'package:communal_mobile/core/utils/idempotency.dart';
import 'package:communal_mobile/core/utils/money.dart';
import 'package:communal_mobile/core/utils/money_formatter.dart';
import 'package:communal_mobile/core/utils/tap_debouncer.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/data/local/transfer_favorites_prefs.dart';
import 'package:communal_mobile/data/repositories/transfer_repository.dart';
import 'package:communal_mobile/injection.dart';
import 'package:communal_mobile/screens/obligations/data/obligation_nip_settlement.dart';
import 'package:communal_mobile/screens/transactions/models/transaction_details_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

/// Three states the verify screen can be in. Backend M38 middleware
/// requires a biometric signature on `transfer/initiate`, so PIN-only
/// confirmation is no longer a valid auth path — `_AuthMode.notReady`
/// surfaces a "set this up first" page instead.
enum _AuthMode { checking, biometric, notReady }

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
  final _repo = getIt<TransferRepository>();
  final _favorites = getIt<TransferFavoritesPrefs>();
  final _biometricSigner = getIt<BiometricSignerService>();
  // Audit M28: swallows rapid double-taps on Confirm Transfer.
  final TapDebouncer _confirmDebouncer = TapDebouncer();
  bool _submitting = false;

  _AuthMode _authMode = _AuthMode.checking;
  String? _notReadyReason;

  /// Audit M23: minted once per screen mount and reused across retries so a
  /// network drop + user retry on the Confirm button dedupes server-side.
  /// A fresh key is only generated when the user navigates away and re-enters.
  late final String _idempotencyKey = newIdempotencyKey();

  @override
  void initState() {
    super.initState();
    _checkAuthReadiness();
  }

  Future<void> _checkAuthReadiness() async {
    try {
      final shared = await shared_prefs.SharedPreferences.getInstance();
      final prefs = BiometricPrefs(shared);
      if (!prefs.transactionsEnabled) {
        if (!mounted) return;
        setState(() {
          _authMode = _AuthMode.notReady;
          _notReadyReason =
              'Biometric authorization for transactions is turned off. '
              'Re-enable it in Settings → Biometric Authentication.';
        });
        return;
      }
      final enrolled = await _biometricSigner.isEnrolled();
      if (!mounted) return;
      if (enrolled) {
        setState(() => _authMode = _AuthMode.biometric);
      } else {
        setState(() {
          _authMode = _AuthMode.notReady;
          _notReadyReason =
              'Biometric authorization is required for transfers on this account. '
              'Set it up to continue.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _authMode = _AuthMode.notReady;
        _notReadyReason =
            'Could not verify biometric setup: ${e.toString().replaceFirst('Exception: ', '')}';
      });
    }
  }

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

  Future<void> _confirm() async {
    if (_submitting || _authMode != _AuthMode.biometric) return;
    final currencySymbol = currencySymbolForCode(widget.currency);
    final currencyCode = widget.currency;

    setState(() => _submitting = true);
    try {
      // Audit M38: biometric IS the auth mechanism for transfers.
      // Server mints a one-time nonce via /security/biometric/
      // challenge, we sign it with the Keystore-bound key, and the
      // headers travel with the initiate call. The backend's
      // RequireBiometricSignature middleware verifies before letting
      // the request through.
      final biometricHeaders = await _biometricSigner.signTransferIntent(
        promptTitle: 'Authorize transfer',
        promptSubtitle: 'Use biometrics to confirm this transfer',
      );
      final biometricMap = biometricHeaders.toHeaders();

      final TransferInitiationResult result;
      if (widget.useExternalNipFlow) {
        result = await _repo.initiateTransfer(
          type: 'NIPTransfer',
          amountMinor: widget.amountMinor,
          narration: widget.narration.trim().isEmpty ? 'Transfer' : widget.narration,
          counterPartyId: widget.recipient.accountId,
          currencyCode: currencyCode,
          idempotencyKey: _idempotencyKey,
          biometricHeaders: biometricMap,
        );
      } else {
        result = await _repo.initiateTransfer(
          type: 'BookTransfer',
          amountMinor: widget.amountMinor,
          narration: widget.narration.trim().isEmpty ? 'Transfer' : widget.narration,
          destinationAccountId: widget.recipient.accountId,
          currencyCode: currencyCode,
          idempotencyKey: _idempotencyKey,
          biometricHeaders: biometricMap,
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
            // TransactionDetailsData.amount remains a `double` for now
            // (audit M20 follow-up — receipt screen migration).
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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
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
      body: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              _headerForMode(),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 26.sp, fontWeight: FontWeight.w700),
            ),
            vSpace(6),
            Text(
              _subheaderForMode(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15.sp,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
            vSpace(12),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16.w),
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
                          style: TextStyle(
                            fontSize: 17.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        vSpace(2),
                        Row(
                          children: [
                            Icon(
                              Icons.account_balance_outlined,
                              size: 14.sp,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                            hSpace(4),
                            Expanded(
                              child: Text(
                                '${widget.recipient.bank} • ${widget.recipient.accountNumber}',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                  fontSize: 14.sp,
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
            ),
            vSpace(20),
            _buildAmountBanner(),
            vSpace(20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shield_outlined, size: 16.sp, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                hSpace(6),
                Text(
                  'End-to-end encrypted transaction',
                  style: TextStyle(
                    fontSize: 15.sp,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const Spacer(),
            _buildPrimaryAction(),
          ],
        ),
      ),
    );
  }

  String _headerForMode() {
    switch (_authMode) {
      case _AuthMode.checking:
        return 'Verify Transaction';
      case _AuthMode.biometric:
        return 'Authorize with Biometrics';
      case _AuthMode.notReady:
        return 'Biometric Required';
    }
  }

  String _subheaderForMode() {
    switch (_authMode) {
      case _AuthMode.checking:
        return 'Preparing biometric…';
      case _AuthMode.biometric:
        return 'Tap below and scan your fingerprint or face to confirm.';
      case _AuthMode.notReady:
        return _notReadyReason ?? 'Biometric is not configured for this device.';
    }
  }

  Widget _buildAmountBanner() {
    final symbol = currencySymbolForCode(widget.currency);
    final amountMajor = widget.amountMinor / factorFor(widget.currency);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 18.h),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? Theme.of(context).primaryColor.withValues(alpha: 0.16) : const Color(0xFFEFE7FF),
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: Column(
        children: [
          Text(
            "You're sending",
            style: TextStyle(fontSize: 15.sp, color: Colors.grey.shade700),
          ),
          vSpace(4),
          Text(
            '$symbol${formatMoney(amountMajor)}',
            style: TextStyle(
              fontSize: 28.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF7434FF),
            ),
          ),
          vSpace(4),
          Text(
            'to ${widget.recipient.accountName}',
            style: TextStyle(fontSize: 15.sp, color: Colors.grey.shade700),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryAction() {
    switch (_authMode) {
      case _AuthMode.checking:
        return SizedBox(
          height: 52.h,
          width: 52.h,
          child: const CircularProgressIndicator(strokeWidth: 2),
        );
      case _AuthMode.biometric:
        return SizedBox(
          width: double.infinity,
          height: 50.h,
          child: ElevatedButton.icon(
            onPressed: _submitting
                ? null
                : () => _confirmDebouncer.run(_confirm),
            icon: const Icon(Icons.fingerprint, color: Colors.white),
            label: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    'Confirm Transfer',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7434FF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
          ),
        );
      case _AuthMode.notReady:
        return SizedBox(
          width: double.infinity,
          height: 50.h,
          child: ElevatedButton(
            onPressed: () => context.pushNamed('biometric-enrollment'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7434FF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
            child: Text(
              'Set up Biometrics',
              style: TextStyle(
                fontSize: 17.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
    }
  }
}
