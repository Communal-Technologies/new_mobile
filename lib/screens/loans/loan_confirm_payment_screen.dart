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
import 'package:communal_mobile/data/models/loan_application.dart';
import 'package:communal_mobile/data/repositories/loan_repository.dart';
import 'package:communal_mobile/data/repositories/member_obligations_repository.dart';
import 'package:communal_mobile/data/repositories/transfer_repository.dart';
import 'package:communal_mobile/injection.dart';
import 'package:communal_mobile/screens/loans/data/loan_nip_settlement.dart';
import 'package:communal_mobile/screens/transactions/models/transaction_details_data.dart';
import 'package:communal_mobile/core/widgets/space.dart';

const Color _kLoanOrange = Color(0xFFE67E22);

/// The biometric-sig middleware on /pay-loan accepts a biometric signature OR
/// a valid transaction PIN supplied via `X-Security-Pin`, so the screen offers
/// both as described on [PaymentAuthorization].
class LoanConfirmPaymentScreen extends StatefulWidget {
  const LoanConfirmPaymentScreen({
    super.key,
    required this.loan,
    required this.amountMinor,
    required this.method,
    this.cashAccount,
    this.cashRepositoryId,
    this.sourceObligationCode,
    this.sourceObligationTitle,
  });

  final LoanApplication loan;

  /// Integer minor units of [loan.currency] (e.g. kobo for NGN).
  final int amountMinor;

  /// `'NIP transfer'` triggers wallet → cooperative-bank flow.
  /// `'Obligation'` triggers obligation → loan flow (no NIP transfer);
  /// `sourceObligationCode` must be set in that case.
  final String method;
  final CooperativeCashBankAccount? cashAccount;

  /// When [cashAccount] is missing (e.g. route extra dropped), resolve
  /// via API using this id.
  final String? cashRepositoryId;

  /// Source obligation's `account_code` for the obligation-funded path.
  /// Equity obligations are filtered out by the picker — never set here.
  final String? sourceObligationCode;

  /// Pretty title for the source obligation, shown in receipts /
  /// summaries.
  final String? sourceObligationTitle;

  @override
  State<LoanConfirmPaymentScreen> createState() =>
      _LoanConfirmPaymentScreenState();
}

class _LoanConfirmPaymentScreenState extends State<LoanConfirmPaymentScreen>
    with PaymentAuthorization<LoanConfirmPaymentScreen> {
  final LoanRepository _loanRepo = LoanRepository(getIt());
  final MemberObligationsRepository _obligationsRepo =
      MemberObligationsRepository(getIt());
  final TransferRepository _transferRepo = getIt<TransferRepository>();

  late final String _idempotencyKey = newIdempotencyKey();

  bool get _fundedFromObligation => widget.method == 'Obligation';

  @override
  String get pinIntent => 'pay-obligation';

  @override
  Future<BiometricSignedHeaders> signBiometricIntent() {
    return _fundedFromObligation
        ? biometricSigner.signObligationIntent(
            promptTitle: 'Authorize repayment',
            promptSubtitle:
                'Use biometrics to confirm repaying ${widget.loan.displayLabel}',
          )
        : biometricSigner.signTransferIntent(
            promptTitle: 'Authorize repayment',
            promptSubtitle: 'Use biometrics to confirm this loan repayment',
          );
  }

  @override
  String? paymentBlockedReason() {
    if (context.read<AuthBloc>().state is! AuthAuthenticated) {
      return 'Please sign in again and retry.';
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
      await _confirmObligationFundedRepayment(authState, authHeaders);
    } else {
      await _confirmNipFundedRepayment(authState, authHeaders);
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
            'Confirm Repayment',
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
                  offerBiometric
                      ? 'Confirm Repayment'
                      : 'Enter Transaction PIN',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.w700),
                ),
                vSpace(4),
                Text(
                  offerBiometric
                      ? 'Use biometrics, or enter your 4-digit PIN.'
                      : 'Enter your 4-digit PIN to authorise this repayment.',
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
            ? _kLoanOrange.withValues(alpha: 0.16)
            : const Color(0xFFFFF4E9),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        children: [
          Text(
            "You're repaying",
            style: TextStyle(
              fontSize: 15.sp,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          vSpace(2),
          Text(
            Money(widget.amountMinor, widget.loan.currency).format(),
            style: TextStyle(
              fontSize: 24.sp,
              fontWeight: FontWeight.w800,
              color: _kLoanOrange,
            ),
          ),
          vSpace(2),
          Text(
            widget.loan.referenceId.isNotEmpty
                ? '${widget.loan.displayLabel} · Ref ${widget.loan.referenceId}'
                : widget.loan.displayLabel,
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

  /// Wallet → cooperative-bank NIP transfer, then record the loan
  /// repayment via the no-biometric record route. Same shape as the
  /// obligation flow.
  Future<void> _confirmNipFundedRepayment(
    AuthAuthenticated authState,
    Map<String, String> authHeaders,
  ) async {
    CooperativeCashBankAccount? cash = widget.cashAccount;
    if (cash == null || cash.id.isEmpty) {
      final accounts = await _obligationsRepo
          .fetchCooperativeCashBankAccounts();
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
        'No cooperative bank account is available. Please go back, '
        'wait for accounts to load, or contact your cooperative '
        'administrator.',
      );
    }

    final route = await resolveCoopPayoutRoute(_transferRepo, cash);

    final coopId = authState.user.cooperativeId?.trim() ?? '';
    final settlement = LoanNipSettlement(
      cashRepositoryId: cash.id,
      cooperativeId: coopId,
      loanId: widget.loan.id,
      loanCode: widget.loan.loanCode,
      amountMinor: widget.amountMinor,
      currency: widget.loan.currency,
    );

    final currencySymbol =
        activeCurrency.display.forCurrency(widget.loan.currency).symbol;
    final currencyCode = resolveCurrencyCode(authState.user);
    final narration = 'Loan re-payment: ${widget.loan.displayLabel}';

    final result = await _transferRepo.initiateTransfer(
      type: route.type,
      amountMinor: widget.amountMinor,
      narration: narration,
      counterPartyId: route.counterPartyId,
      destinationAccountId: route.destinationAccountId,
      currencyCode: currencyCode,
      idempotencyKey: _idempotencyKey,
      biometricHeaders: authHeaders,
      obligationContext: settlement.toJson(),
    );

    if (!mounted) return;
    final mapped = transactionStatusFromApi(result.status);
    final amountMajor = widget.amountMinor / factorFor(widget.loan.currency);
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
          currencyCode: widget.loan.currency,
          transactionType: 'Loan re-payment',
          dateTime: DateTime.now(),
          sessionId: result.transferId,
          reference: result.reference,
          description: narration,
          paymentMethod: route.isBook ? 'Transfer' : 'NIP transfer',
          fees: 0,
          isIncoming: false,
          status: mapped,
          failureReason: result.failureReason,
        ),
        'loanNipSettlement': settlement.toJson(),
      },
    );
  }

  /// Source-obligation balance → loan. No NIP transfer; backend
  /// `pay-loan` endpoint with `gateway: 'obligation'` atomically
  /// decrements the source's `amount_paid` and credits the loan.
  /// Equity sources were filtered out of the picker upstream and are
  /// rejected server-side too.
  Future<void> _confirmObligationFundedRepayment(
    AuthAuthenticated authState,
    Map<String, String> authHeaders,
  ) async {
    final sourceCode = widget.sourceObligationCode?.trim() ?? '';
    if (sourceCode.isEmpty) {
      throw Exception(
        'Missing source obligation. Please go back and pick one.',
      );
    }

    await _loanRepo.payLoanFromObligation(
      user: authState.user,
      loanId: widget.loan.id,
      sourceObligationAccountCode: sourceCode,
      amountMinor: widget.amountMinor,
      idempotencyKey: _idempotencyKey,
      biometricHeaders: authHeaders,
    );

    if (!mounted) return;
    final currencySymbol =
        activeCurrency.display.forCurrency(widget.loan.currency).symbol;
    final receiptReference = _idempotencyKey.length > 12
        ? _idempotencyKey.substring(0, 12)
        : _idempotencyKey;
    final sourceTitle =
        (widget.sourceObligationTitle?.trim().isNotEmpty ?? false)
        ? widget.sourceObligationTitle!.trim()
        : 'Obligation';
    final narration = 'Loan re-payment: ${widget.loan.displayLabel}';
    final amountMajor = widget.amountMinor / factorFor(widget.loan.currency);
    final cooperativeName = (authState.user.cooperativeName ?? '').trim();
    // ignore: unawaited_futures
    context.pushNamed(
      'transaction-receipt',
      extra: {
        'details': TransactionDetailsData(
          id: receiptReference,
          // Recipient on a loan repayment is the cooperative — no real
          // bank movement when the source is an obligation, so we name
          // the cooperative + the loan being repaid instead of leaving
          // it as the loan_code with a "—" bank line.
          counterpartyName: cooperativeName.isNotEmpty
              ? cooperativeName
              : 'Cooperative',
          counterpartyBank: 'Loan: ${widget.loan.displayLabel}',
          counterpartyAccount: widget.loan.referenceId,
          amount: amountMajor,
          currencySymbol: currencySymbol,
          currencyCode: widget.loan.currency,
          transactionType: 'Loan re-payment',
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
        // No `loanNipSettlement` — backend already recorded the
        // repayment in the same call; the receipt page would otherwise
        // re-trigger a NIP-settlement record-keeper.
      },
    );
  }
}
