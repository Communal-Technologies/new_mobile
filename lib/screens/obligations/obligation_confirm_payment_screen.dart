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
import 'package:communal_mobile/data/local/transfer_favorites_prefs.dart';
import 'package:communal_mobile/data/models/obligation.dart';
import 'package:communal_mobile/data/repositories/member_obligations_repository.dart';
import 'package:communal_mobile/data/repositories/transfer_repository.dart';
import 'package:communal_mobile/injection.dart';
import 'package:communal_mobile/screens/obligations/data/obligation_nip_settlement.dart';
import 'package:communal_mobile/screens/transactions/models/transaction_details_data.dart';
import 'package:communal_mobile/core/widgets/space.dart';

/// Three states the confirm screen can be in. Backend M38 middleware
/// gates `pay-obligation` on a biometric signature *or* a valid
/// transaction PIN supplied via the `X-Security-Pin` header. So when
/// the device hasn't enrolled biometric we fall through to a PIN
/// prompt instead of forcing an enrollment detour.
enum _AuthMode { checking, biometric, pin, notReady }

class ObligationConfirmPaymentScreen extends StatefulWidget {
  const ObligationConfirmPaymentScreen({
    super.key,
    required this.obligation,
    required this.amountMinor,
    required this.method,
    this.cashAccount,
    this.cashRepositoryId,
    this.sourceObligationCode,
    this.sourceObligationTitle,
  });

  final Obligation obligation;

  /// Integer minor units of [obligation.currency] (e.g. kobo for NGN).
  final int amountMinor;

  /// `'NIP transfer'` triggers the wallet → cooperative-bank flow.
  /// `'Obligation'` triggers the obligation → obligation flow (no NIP
  /// transfer); `sourceObligationCode` must be set in that case.
  final String method;
  final CooperativeCashBankAccount? cashAccount;

  /// When [cashAccount] is missing (e.g. route extra dropped), resolve via API using this id.
  final String? cashRepositoryId;

  /// Source obligation's `account_code` for the obligation-funded path.
  /// Equity obligations are filtered out by the picker — never set here.
  final String? sourceObligationCode;

  /// Pretty title for the source obligation, shown in receipts / summaries.
  final String? sourceObligationTitle;

  @override
  State<ObligationConfirmPaymentScreen> createState() =>
      _ObligationConfirmPaymentScreenState();
}

class _ObligationConfirmPaymentScreenState
    extends State<ObligationConfirmPaymentScreen> {
  final MemberObligationsRepository _repository =
      MemberObligationsRepository(getIt());
  final TransferRepository _transferRepo = getIt<TransferRepository>();
  final BiometricSignerService _biometricSigner = getIt<BiometricSignerService>();
  // Audit M28: swallows rapid double-taps on the Confirm button.
  final TapDebouncer _confirmDebouncer = TapDebouncer();
  bool _submitting = false;

  _AuthMode _authMode = _AuthMode.checking;
  String? _notReadyReason;

  /// Captures the PIN typed in the fallback prompt; the value is
  /// forwarded to the backend via the `X-Security-Pin` header on the
  /// pay-obligation request. Cleared on dispose.
  final TextEditingController _pinController = TextEditingController();

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  /// Audit M23: minted once per screen mount; reused across user-initiated
  /// retries of the Confirm action so a transient failure + retry dedupes
  /// server-side instead of double-paying the obligation.
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
        // User explicitly turned off biometric for transactions in
        // Settings. Fall through to PIN — they still need to confirm
        // the payment.
        if (!mounted) return;
        setState(() => _authMode = _AuthMode.pin);
        return;
      }
      final enrolled = await _biometricSigner.isEnrolled();
      if (!mounted) return;
      if (enrolled) {
        setState(() => _authMode = _AuthMode.biometric);
      } else {
        // No biometric enrolled on this device — drop to the PIN
        // prompt instead of marching the user off to the enrollment
        // screen for what is just a confirmation step.
        setState(() => _authMode = _AuthMode.pin);
      }
    } catch (e) {
      if (!mounted) return;
      // Last-resort PIN. Surface the reason in case the user wants
      // to retry biometric, but keep the action available.
      setState(() {
        _authMode = _AuthMode.pin;
        _notReadyReason =
            'Could not verify biometric setup: ${e.toString().replaceFirst('Exception: ', '')}. Use your PIN instead.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
              color: const Color(0xFF7434FF),
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
              style: TextStyle(fontSize: 15.sp, color: Colors.grey.shade600),
            ),
            vSpace(24),
            _buildAmountBanner(),
            vSpace(24),
            _buildSecureInfo(),
            vSpace(32),
            _buildPrimaryAction(),
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
          child: ElevatedButton.icon(
            onPressed: _submitting
                ? null
                : () => _confirmDebouncer.run(_onConfirm),
            icon: const Icon(Icons.fingerprint),
            label: Text(
              _submitting ? 'Processing…' : 'Authorize Payment',
              style: TextStyle(
                fontSize: 17.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7434FF),
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
                  fillColor: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14.r),
                    borderSide: BorderSide(
                      color: Theme.of(context).dividerColor,
                    ),
                  ),
                  contentPadding: EdgeInsets.symmetric(vertical: 16.h),
                ),
              ),
            ),
            vSpace(16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _submitting
                    ? null
                    : () => _confirmDebouncer.run(_onConfirm),
                icon: const Icon(Icons.lock_outline),
                label: Text(
                  _submitting ? 'Processing…' : 'Authorize Payment',
                  style: TextStyle(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7434FF),
                  foregroundColor: Colors.white,
                  minimumSize: Size(double.infinity, 52.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18.r),
                  ),
                ),
              ),
            ),
            vSpace(8),
            // Offer biometric setup as a secondary path; tapping it
            // routes to the enrollment screen but doesn't gate the PIN
            // flow.
            TextButton(
              onPressed: () => context.pushNamed('biometric-enrollment'),
              child: Text(
                'Set up biometric instead',
                style: TextStyle(
                  fontSize: 14.sp,
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
              side: BorderSide(color: Theme.of(context).primaryColor),
            ),
            child: Text(
              'Retry',
              style: TextStyle(
                fontSize: 17.sp,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ),
        );
    }
  }

  Widget _buildAmountBanner() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 18.h),
      decoration: BoxDecoration(
        color: isDark
            ? theme.primaryColor.withValues(alpha: 0.16)
            : const Color(0xFFEFE7FF),
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: Column(
        children: [
          Text(
            "You're paying",
            style: TextStyle(
              fontSize: 15.sp,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          vSpace(4),
          Text(
            Money(widget.amountMinor, widget.obligation.currency).format(),
            style: TextStyle(
              fontSize: 30.sp,
              fontWeight: FontWeight.w800,
              color: theme.primaryColor,
            ),
          ),
          vSpace(4),
          Text(
            'to ${widget.obligation.category}',
            style: TextStyle(
              fontSize: 15.sp,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          Text(
            widget.obligation.title,
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
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
        color: isDark
            ? accent.withValues(alpha: 0.16)
            : const Color(0xFFE6F1FF),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: const Color(0xFF4A90E2), size: 20.sp),
          hSpace(10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Secure Payment',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                vSpace(4),
                Text(
                  'Your transaction is encrypted and secure. Never share your PIN with anyone.',
                  style: TextStyle(
                    fontSize: 15.sp,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Resolves the headers we attach to the pay-obligation request.
  /// In biometric mode we sign the intent with the device-bound key;
  /// in PIN-fallback mode we forward the typed PIN as
  /// `X-Security-Pin` and the backend middleware accepts that as the
  /// alternative auth path. Throws if PIN mode is selected but the
  /// field isn't a 4-digit number, so we surface a friendly error
  /// before the round-trip.
  Future<Map<String, String>> _resolveAuthHeaders({
    required bool transfer,
    required String promptSubtitle,
  }) async {
    if (_authMode == _AuthMode.pin) {
      final pin = _pinController.text.trim();
      if (pin.length < 4 || int.tryParse(pin) == null) {
        throw Exception('Enter your 4-digit transaction PIN to continue.');
      }
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in again and retry.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      // Equity *target* cap still applies under both gateways — the
      // backend rejects over-cap payments either way; this gives a
      // friendlier message before we round-trip.
      if (widget.obligation.category == 'Equity' &&
          widget.amountMinor > widget.obligation.balanceMinor) {
        throw Exception(
          'Equity payments cannot exceed your remaining cap '
          '(${widget.obligation.balanceLabel}).',
        );
      }

      if (widget.method == 'Obligation') {
        await _confirmObligationFundedPayment(authState);
      } else {
        await _confirmNipFundedPayment(authState);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// Wallet → cooperative-bank NIP transfer, then record the payment.
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

    final verified = await _transferRepo.verifyAccount(
      bankCode: cash.bankCode,
      accountNumber: cash.accountNumber,
    );
    final counterpartyId = await _transferRepo.createCounterParty(
      bankCode: cash.bankCode,
      accountNumber: cash.accountNumber,
      accountName: verified.accountName,
    );

    final fav = TransferFavorite(
      source: 'external',
      accountId: counterpartyId,
      bank: verified.bankName ?? 'Bank',
      accountNumber: cash.accountNumber,
      accountName: verified.accountName,
      nipCode: cash.bankCode,
    );

    final coopId = authState.user.cooperativeId?.trim() ?? '';
    final settlement = ObligationNipSettlement(
      cashRepositoryId: cash.id,
      cooperativeId: coopId,
      obligationAccountCode: widget.obligation.accountCode,
      obligationTitle: widget.obligation.title,
      obligationCategory: widget.obligation.category,
      amountMinor: widget.amountMinor,
      currency: widget.obligation.currency,
    );

    final currencySymbol = currencySymbolForUser(authState.user);
    final currencyCode = resolveCurrencyCode(authState.user);
    final narration = 'Obligation: ${widget.obligation.title}';

    // Audit M38: biometric proof for the transfer that backs this
    // obligation payment. When biometric isn't enrolled the user
    // typed a PIN in the fallback field; we forward it as
    // `X-Security-Pin` and the middleware accepts that as an
    // alternative auth.
    final authHeaders = await _resolveAuthHeaders(
      transfer: true,
      promptSubtitle: 'Use biometrics to confirm this obligation payment',
    );

    final result = await _transferRepo.initiateTransfer(
      type: 'NIPTransfer',
      amountMinor: widget.amountMinor,
      narration: narration.trim().isEmpty ? 'Transfer' : narration,
      counterPartyId: fav.accountId,
      currencyCode: currencyCode,
      idempotencyKey: _idempotencyKey,
      biometricHeaders: authHeaders,
    );

    if (!mounted) return;
    final mapped = transactionStatusFromApi(result.status);
    final amountMajor = widget.amountMinor / factorFor(widget.obligation.currency);
    // ignore: unawaited_futures
    context.pushNamed(
      'transaction-receipt',
      extra: {
        'details': TransactionDetailsData(
          id: result.transferId,
          counterpartyName: fav.accountName,
          counterpartyBank: fav.bank,
          counterpartyAccount: fav.accountNumber,
          amount: amountMajor,
          currencySymbol: currencySymbol,
          transactionType: 'NIP Transfer',
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
        'obligationNipSettlement': settlement.toJson(),
      },
    );
  }

  /// Source-obligation balance → target obligation. No NIP transfer; the
  /// backend `pay-obligation` endpoint with `gateway: 'obligation'`
  /// atomically decrements the source's `amount_paid` and credits the
  /// target. Equity sources were filtered out of the picker upstream.
  Future<void> _confirmObligationFundedPayment(AuthAuthenticated authState) async {
    final sourceCode = widget.sourceObligationCode?.trim() ?? '';
    if (sourceCode.isEmpty) {
      throw Exception('Missing source obligation. Please go back and pick one.');
    }
    if (sourceCode == widget.obligation.accountCode.trim()) {
      throw Exception('Source and target obligations must differ.');
    }

    // Audit M38: biometric proof for the obligation-funded path uses
    // the `pay-obligation` intent (matches the backend gate on this
    // endpoint, which the NIP path satisfies via the upstream
    // transfer). PIN fallback uses `X-Security-Pin` instead.
    final authHeaders = await _resolveAuthHeaders(
      transfer: false,
      promptSubtitle:
          'Use biometrics to confirm paying ${widget.obligation.title}',
    );

    await _repository.payObligationFromObligation(
      user: authState.user,
      targetObligationAccountCode: widget.obligation.accountCode,
      sourceObligationAccountCode: sourceCode,
      amountMinor: widget.amountMinor,
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
    final narration = 'Obligation: ${widget.obligation.title}';
    final amountMajor = widget.amountMinor / factorFor(widget.obligation.currency);
    // ignore: unawaited_futures
    context.pushNamed(
      'transaction-receipt',
      extra: {
        'details': TransactionDetailsData(
          id: receiptReference,
          counterpartyName: widget.obligation.title,
          counterpartyBank: '—',
          counterpartyAccount: widget.obligation.accountCode,
          amount: amountMajor,
          currencySymbol: currencySymbol,
          transactionType: 'Obligation transfer',
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
        // No `obligationNipSettlement` — the backend already recorded
        // the payment in the same call; the receipt page would
        // otherwise re-trigger a NIP-settlement record-keeper.
      },
    );
  }
}
