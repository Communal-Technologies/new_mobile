import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_state.dart';
import 'package:communal_mobile/core/security/biometric_signer_service.dart';
import 'package:communal_mobile/core/utils/app_currency.dart';
import 'package:communal_mobile/core/utils/idempotency.dart';
import 'package:communal_mobile/core/utils/money.dart';
import 'package:communal_mobile/core/widgets/payment_authorization.dart';
import 'package:communal_mobile/data/repositories/coop_payout_route.dart';
import 'package:communal_mobile/data/models/obligation.dart';
import 'package:communal_mobile/data/repositories/member_obligations_repository.dart';
import 'package:communal_mobile/data/repositories/transfer_repository.dart';
import 'package:communal_mobile/injection.dart';
import 'package:communal_mobile/screens/obligations/data/obligation_nip_settlement.dart';
import 'package:communal_mobile/screens/transactions/models/transaction_details_data.dart';
import 'package:communal_mobile/core/widgets/space.dart';

/// Backend M38 middleware gates `pay-obligation` on a biometric signature *or*
/// a valid transaction PIN supplied via the `X-Security-Pin` header, so the
/// screen offers both as described on [PaymentAuthorization].
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
    extends State<ObligationConfirmPaymentScreen>
    with PaymentAuthorization<ObligationConfirmPaymentScreen> {
  final MemberObligationsRepository _repository =
      MemberObligationsRepository(getIt());
  final TransferRepository _transferRepo = getIt<TransferRepository>();

  /// Audit M23: minted once per screen mount; reused across user-initiated
  /// retries of the Confirm action so a transient failure + retry dedupes
  /// server-side instead of double-paying the obligation.
  late final String _idempotencyKey = newIdempotencyKey();

  bool get _fundedFromObligation => widget.method == 'Obligation';

  @override
  String get pinIntent => 'pay-obligation';

  @override
  Future<BiometricSignedHeaders> signBiometricIntent() {
    // Audit M38: the NIP path is authorised by the transfer that backs the
    // payment; the obligation-funded path by the `pay-obligation` intent.
    return _fundedFromObligation
        ? biometricSigner.signObligationIntent(
            promptTitle: 'Authorize payment',
            promptSubtitle:
                'Use biometrics to confirm paying ${widget.obligation.title}',
          )
        : biometricSigner.signTransferIntent(
            promptTitle: 'Authorize payment',
            promptSubtitle: 'Use biometrics to confirm this obligation payment',
          );
  }

  @override
  String? paymentBlockedReason() {
    if (context.read<AuthBloc>().state is! AuthAuthenticated) {
      return 'Please sign in again and retry.';
    }
    // Equity *target* cap still applies under both gateways — the backend
    // rejects over-cap payments either way; this gives a friendlier message
    // before the member authorises.
    if (widget.obligation.category == 'Equity' &&
        widget.amountMinor > widget.obligation.balanceMinor) {
      return 'Equity payments cannot exceed your remaining cap '
          '(${widget.obligation.balanceLabel}).';
    }
    return null;
  }

  @override
  Future<void> submitAuthorized({
    String? pin,
    Map<String, String>? biometricHeaders,
  }) async {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) {
      throw Exception('Please sign in again and retry.');
    }
    final authHeaders = biometricHeaders ?? {'X-Security-Pin': pin!};
    if (_fundedFromObligation) {
      await _confirmObligationFundedPayment(authState, authHeaders);
    } else {
      await _confirmNipFundedPayment(authState, authHeaders);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    return withPaymentLoader(
      Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: theme.cardColor,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: Text(
            'Confirm Payment',
            style: TextStyle(
              fontSize: 19.sp,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
            child: Column(
              children: [
                Text(
                  offerBiometric ? 'Confirm Payment' : 'Enter Transaction PIN',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.w700),
                ),
                vSpace(4),
                Text(
                  offerBiometric
                      ? 'Use biometrics, or enter your 4-digit PIN.'
                      : 'Enter your 4-digit PIN to authorise this payment.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15.sp,
                    color: muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                vSpace(12),
                _buildAmountBanner(),
                vSpace(20),
                buildPaymentPinPad(),
                vSpace(12),
                Text(
                  'Your transaction is encrypted and secure. Never share your PIN with anyone.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14.sp, color: muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAmountBanner() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: isDark
            ? theme.primaryColor.withValues(alpha: 0.16)
            : const Color(0xFFEFE7FF),
        borderRadius: BorderRadius.circular(16.r),
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
          vSpace(2),
          Text(
            Money(widget.amountMinor, widget.obligation.currency).format(),
            style: TextStyle(
              fontSize: 24.sp,
              fontWeight: FontWeight.w800,
              color: theme.primaryColor,
            ),
          ),
          vSpace(2),
          Text(
            '${widget.obligation.category} · ${widget.obligation.title}',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  /// Wallet → cooperative-bank NIP transfer, then record the payment.
  Future<void> _confirmNipFundedPayment(
    AuthAuthenticated authState,
    Map<String, String> authHeaders,
  ) async {
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

    final currencySymbol =
        activeCurrency.display.forCurrency(widget.obligation.currency).symbol;
    final currencyCode = resolveCurrencyCode(authState.user);
    final narration = 'Obligation: ${widget.obligation.title}';

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
    final amountMajor = widget.amountMinor / factorFor(widget.obligation.currency);
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
          currencyCode: widget.obligation.currency,
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
        'obligationNipSettlement': settlement.toJson(),
      },
    );
  }

  /// Source-obligation balance → target obligation. No NIP transfer; the
  /// backend `pay-obligation` endpoint with `gateway: 'obligation'`
  /// atomically decrements the source's `amount_paid` and credits the
  /// target. Equity sources were filtered out of the picker upstream.
  Future<void> _confirmObligationFundedPayment(
    AuthAuthenticated authState,
    Map<String, String> authHeaders,
  ) async {
    final sourceCode = widget.sourceObligationCode?.trim() ?? '';
    if (sourceCode.isEmpty) {
      throw Exception('Missing source obligation. Please go back and pick one.');
    }
    if (sourceCode == widget.obligation.accountCode.trim()) {
      throw Exception('Source and target obligations must differ.');
    }

    await _repository.payObligationFromObligation(
      user: authState.user,
      targetObligationAccountCode: widget.obligation.accountCode,
      sourceObligationAccountCode: sourceCode,
      amountMinor: widget.amountMinor,
      idempotencyKey: _idempotencyKey,
      biometricHeaders: authHeaders,
    );

    if (!mounted) return;
    final currencySymbol =
        activeCurrency.display.forCurrency(widget.obligation.currency).symbol;
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
          currencyCode: widget.obligation.currency,
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
