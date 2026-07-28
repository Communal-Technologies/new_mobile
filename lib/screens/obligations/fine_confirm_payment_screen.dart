import 'package:communal_mobile/core/widgets/app_toast.dart';
import 'package:communal_mobile/cubits/connectivity/connectivity_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart' as shared_prefs;

import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_state.dart';
import 'package:communal_mobile/core/security/biometric_signer_service.dart';
import 'package:communal_mobile/core/utils/app_currency.dart';
import 'package:communal_mobile/core/utils/idempotency.dart';
import 'package:communal_mobile/core/utils/tap_debouncer.dart';
import 'package:communal_mobile/core/utils/money.dart';
import 'package:communal_mobile/data/local/biometric_prefs.dart';
import 'package:communal_mobile/data/models/obligation.dart';
import 'package:communal_mobile/data/repositories/coop_payout_route.dart';
import 'package:communal_mobile/data/repositories/member_obligations_repository.dart';
import 'package:communal_mobile/data/repositories/transfer_repository.dart';
import 'package:communal_mobile/injection.dart';
import 'package:communal_mobile/screens/obligations/data/fine_nip_settlement.dart';
import 'package:communal_mobile/screens/transactions/models/transaction_details_data.dart';
import 'package:communal_mobile/core/widgets/space.dart';

enum _AuthMode { checking, biometric, pin, notReady }

class FineConfirmPaymentScreen extends StatefulWidget {
  const FineConfirmPaymentScreen({
    super.key,
    required this.fine,
    required this.cooperativeId,
    required this.amountMinor,
    required this.method,
    this.cashAccount,
    this.cashRepositoryId,
    this.sourceObligationCode,
    this.sourceObligationTitle,
  });

  final FineRecord fine;
  final String cooperativeId;
  final int amountMinor;

  /// `'NIP transfer'` → wallet→bank flow.
  /// `'Obligation'` → obligation balance → fine.
  final String method;
  final CooperativeCashBankAccount? cashAccount;
  final String? cashRepositoryId;
  final String? sourceObligationCode;
  final String? sourceObligationTitle;

  @override
  State<FineConfirmPaymentScreen> createState() =>
      _FineConfirmPaymentScreenState();
}

class _FineConfirmPaymentScreenState extends State<FineConfirmPaymentScreen> {
  final MemberObligationsRepository _repository =
      MemberObligationsRepository(getIt());
  final TransferRepository _transferRepo = getIt<TransferRepository>();
  final BiometricSignerService _biometricSigner =
      getIt<BiometricSignerService>();
  final TapDebouncer _confirmDebouncer = TapDebouncer();
  bool _submitting = false;

  _AuthMode _authMode = _AuthMode.checking;
  String? _notReadyReason;
  final TextEditingController _pinController = TextEditingController();

  late final String _idempotencyKey = newIdempotencyKey();

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

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
        setState(() => _authMode = _AuthMode.pin);
        return;
      }
      final enrolled = await _biometricSigner.isEnrolled();
      if (!mounted) return;
      setState(
        () => _authMode =
            enrolled ? _AuthMode.biometric : _AuthMode.pin,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _authMode = _AuthMode.pin;
        _notReadyReason =
            'Could not verify biometric setup: ${e.toString().replaceFirst('Exception: ', '')}. Use your PIN instead.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = context.watch<ConnectivityCubit>().isConnected;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).cardColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          'Confirm Payment',
          style: TextStyle(
            fontSize: 19.sp,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              _authMode == _AuthMode.notReady
                  ? Icons.fingerprint
                  : Icons.lock_outline,
              color: const Color(0xFFD7263D),
              size: 44.sp,
            ),
            vSpace(16),
            Text(
              _headerForMode(),
              style: TextStyle(
                fontSize: 22.sp,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            vSpace(6),
            Text(
              _subheaderForMode(),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17.sp, color: Colors.grey.shade600),
            ),
            vSpace(24),
            _buildAmountBanner(),
            vSpace(24),
            _buildSecureInfo(),
            vSpace(32),
            _buildPrimaryAction(isOnline),
          ],
        ),
      ),
    );
  }

  String _headerForMode() {
    switch (_authMode) {
      case _AuthMode.checking:
        return 'Preparing payment…';
      case _AuthMode.biometric:
        return 'Authorize with Biometrics';
      case _AuthMode.pin:
        return 'Enter your transaction PIN';
      case _AuthMode.notReady:
        return 'Authorization Unavailable';
    }
  }

  String _subheaderForMode() {
    switch (_authMode) {
      case _AuthMode.checking:
        return 'One moment.';
      case _AuthMode.biometric:
        return 'Tap below and scan your fingerprint or face to confirm.';
      case _AuthMode.pin:
        return _notReadyReason ??
            'Biometric isn\'t set up on this device. Enter your 4-digit PIN to confirm.';
      case _AuthMode.notReady:
        return _notReadyReason ??
            'We could not verify your identity. Try again later.';
    }
  }

  Widget _buildPrimaryAction(bool isOnline) {
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
          child: ElevatedButton.icon(
            onPressed: (isOnline && !_submitting)
                ? () => _confirmDebouncer.run(_onConfirm)
                : null,
            icon: const Icon(Icons.fingerprint),
            label: Text(
              _submitting ? 'Processing…' : 'Authorize Payment',
              style: TextStyle(
                fontSize: 19.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD7263D),
              foregroundColor: Colors.white,
              minimumSize: Size(double.infinity, 52.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18.r),
              ),
            ),
          ),
        );
      case _AuthMode.pin:
        return Column(
          children: [
            SizedBox(
              width: 220.w,
              child: TextField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24.sp,
                  letterSpacing: 12,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '••••',
                  hintStyle: TextStyle(
                    fontSize: 24.sp,
                    letterSpacing: 12,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.4),
                  ),
                  filled: true,
                  fillColor:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14.r),
                    borderSide:
                        BorderSide(color: Theme.of(context).dividerColor),
                  ),
                  contentPadding: EdgeInsets.symmetric(vertical: 16.h),
                ),
              ),
            ),
            vSpace(16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (isOnline && !_submitting)
                    ? () => _confirmDebouncer.run(_onConfirm)
                    : null,
                icon: const Icon(Icons.lock_outline),
                label: Text(
                  _submitting ? 'Processing…' : 'Authorize Payment',
                  style: TextStyle(
                    fontSize: 19.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD7263D),
                  foregroundColor: Colors.white,
                  minimumSize: Size(double.infinity, 52.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18.r),
                  ),
                ),
              ),
            ),
            vSpace(8),
            TextButton(
              onPressed: () => context.pushNamed('biometric-enrollment'),
              child: Text(
                'Set up biometric instead',
                style: TextStyle(
                  fontSize: 16.sp,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),
          ],
        );
      case _AuthMode.notReady:
        return SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _checkAuthReadiness,
            style: OutlinedButton.styleFrom(
              minimumSize: Size(double.infinity, 52.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18.r),
              ),
              side: const BorderSide(color: Color(0xFFD7263D)),
            ),
            child: Text(
              'Retry',
              style: TextStyle(
                fontSize: 19.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFD7263D),
              ),
            ),
          ),
        );
    }
  }

  Widget _buildAmountBanner() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const accent = Color(0xFFD7263D);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 18.h),
      decoration: BoxDecoration(
        color: isDark
            ? accent.withValues(alpha: 0.16)
            : const Color(0xFFFFEEF0),
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: Column(
        children: [
          Text(
            "You're paying",
            style: TextStyle(
              fontSize: 17.sp,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          vSpace(4),
          Text(
            Money(widget.amountMinor, widget.fine.currency).format(),
            style: TextStyle(
              fontSize: 30.sp,
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),
          vSpace(4),
          Text(
            'Fine payment',
            style: TextStyle(
              fontSize: 17.sp,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          Text(
            widget.fine.description,
            style: TextStyle(
              fontSize: 17.sp,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSecureInfo() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const accent = Color(0xFF4A90E2);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: isDark ? accent.withValues(alpha: 0.16) : const Color(0xFFE6F1FF),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: accent, size: 20.sp),
          hSpace(10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Secure Payment',
                  style: TextStyle(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                vSpace(4),
                Text(
                  'Your transaction is encrypted and secure. Never share your PIN with anyone.',
                  style: TextStyle(
                    fontSize: 17.sp,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<Map<String, String>> _resolveAuthHeaders({
    required bool transfer,
    required String promptSubtitle,
  }) async {
    if (_authMode == _AuthMode.pin) {
      final pin = _pinController.text.trim();
      if (pin.length < 4 || int.tryParse(pin) == null) {
        throw Exception('Enter your 4-digit transaction PIN to continue.');
      }
      // transactions-svc's /transfer/initiate checks a Redis flag the
      // monolith's verify-security-pin sets on success rather than
      // validating the PIN inline (it can't — security_pin lives on
      // tbl_users, owned exclusively by the monolith), so that call has
      // to happen before initiateTransfer below.
      await _transferRepo.verifySecurityPin(pin);
      return {'X-Security-Pin': pin};
    }
    final result = transfer
        ? await _biometricSigner.signTransferIntent(
            promptTitle: 'Authorize payment',
            promptSubtitle: promptSubtitle,
          )
        : await _biometricSigner.signObligationIntent(
            promptTitle: 'Authorize payment',
            promptSubtitle: promptSubtitle,
          );
    return result.toHeaders();
  }

  Future<void> _onConfirm() async {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) {
      AppToast.error('Please sign in again and retry.');
      return;
    }

    setState(() => _submitting = true);
    try {
      if (widget.method == 'Obligation') {
        await _confirmObligationFundedPayment(authState);
      } else {
        await _confirmNipFundedPayment(authState);
      }
    } catch (e) {
      if (!mounted) return;
      AppToast.error(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _confirmNipFundedPayment(AuthAuthenticated authState) async {
    CooperativeCashBankAccount? cash = widget.cashAccount;
    if (cash == null || cash.id.isEmpty) {
      final accounts = await _repository.fetchCooperativeCashBankAccounts();
      final rid = widget.cashRepositoryId?.trim() ?? '';
      if (rid.isNotEmpty) {
        for (final a in accounts) {
          if (a.id == rid) {
            cash = a;
            break;
          }
        }
      }
      cash ??= accounts.length == 1 ? accounts.first : null;
    }
    if (cash == null || cash.id.isEmpty) {
      throw Exception(
        'No cooperative bank account is available. Please go back, wait for accounts to load, or contact your cooperative administrator.',
      );
    }

    final route = await resolveCoopPayoutRoute(_transferRepo, cash);

    final settlement = FineNipSettlement(
      cashRepositoryId: cash.id,
      cooperativeId: widget.cooperativeId,
      fineId: widget.fine.id,
      fineDescription: widget.fine.description,
      amountMinor: widget.amountMinor,
      currency: widget.fine.currency,
    );

    final currencySymbol = currencySymbolForUser(authState.user);
    final currencyCode = resolveCurrencyCode(authState.user);
    final narration = 'Fine: ${widget.fine.description}';

    final authHeaders = await _resolveAuthHeaders(
      transfer: true,
      promptSubtitle: 'Use biometrics to confirm this fine payment',
    );

    final result = await _transferRepo.initiateTransfer(
      type: route.type,
      amountMinor: widget.amountMinor,
      narration: narration.trim().isEmpty ? 'Transfer' : narration,
      counterPartyId: route.counterPartyId,
      destinationAccountId: route.destinationAccountId,
      currencyCode: currencyCode,
      idempotencyKey: _idempotencyKey,
      biometricHeaders: authHeaders,
      obligationContext: settlement.toJson(),
    );

    if (!mounted) return;
    final mapped = transactionStatusFromApi(result.status);
    final amountMajor =
        widget.amountMinor / factorFor(widget.fine.currency);
    // ignore: unawaited_futures
    context.pushNamed(
      'transaction-receipt',
      extra: {
        'details': TransactionDetailsData(
          id: result.transferId,
          counterpartyName: route.accountName,
          counterpartyBank: route.bankLabel,
          counterpartyAccount: cash.accountNumber,
          amount: amountMajor,
          currencySymbol: currencySymbol,
          transactionType: route.isBook ? 'Transfer' : 'NIP Transfer',
          dateTime: DateTime.now(),
          sessionId: result.transferId,
          reference: result.reference,
          description: narration,
          paymentMethod: 'Wallet',
          fees: 0,
          isIncoming: false,
          status: mapped,
          failureReason: result.failureReason,
        ),
        'fineNipSettlement': settlement.toJson(),
      },
    );
  }

  Future<void> _confirmObligationFundedPayment(
      AuthAuthenticated authState) async {
    final sourceCode = widget.sourceObligationCode?.trim() ?? '';
    if (sourceCode.isEmpty) {
      throw Exception(
          'Missing source obligation. Please go back and pick one.');
    }

    final authHeaders = await _resolveAuthHeaders(
      transfer: false,
      promptSubtitle:
          'Use biometrics to confirm paying fine: ${widget.fine.description}',
    );

    await _repository.payFineFromObligation(
      user: authState.user,
      fineId: widget.fine.id,
      sourceObligationAccountCode: sourceCode,
      amountMinor: widget.amountMinor,
      cooperativeId: widget.cooperativeId,
      idempotencyKey: _idempotencyKey,
      biometricHeaders: authHeaders,
    );

    if (!mounted) return;
    final currencySymbol = currencySymbolForUser(authState.user);
    final receiptReference = _idempotencyKey.length > 12
        ? _idempotencyKey.substring(0, 12)
        : _idempotencyKey;
    final sourceTitle =
        (widget.sourceObligationTitle?.trim().isNotEmpty ?? false)
            ? widget.sourceObligationTitle!.trim()
            : 'Obligation';
    final narration = 'Fine: ${widget.fine.description}';
    final amountMajor =
        widget.amountMinor / factorFor(widget.fine.currency);
    // ignore: unawaited_futures
    context.pushNamed(
      'transaction-receipt',
      extra: {
        'details': TransactionDetailsData(
          id: receiptReference,
          counterpartyName: widget.fine.description,
          counterpartyBank: '—',
          counterpartyAccount: widget.fine.id,
          amount: amountMajor,
          currencySymbol: currencySymbol,
          transactionType: 'Fine payment',
          dateTime: DateTime.now(),
          sessionId: receiptReference,
          reference: receiptReference,
          description: narration,
          paymentMethod: 'From: $sourceTitle',
          fees: 0,
          isIncoming: false,
          status: transactionStatusFromApi('successful'),
          failureReason: null,
        ),
      },
    );
  }
}
