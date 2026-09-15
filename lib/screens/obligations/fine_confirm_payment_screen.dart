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
import 'package:communal_mobile/core/widgets/pin_pad_body.dart';
import 'package:communal_mobile/data/models/obligation.dart';
import 'package:communal_mobile/data/repositories/coop_payout_route.dart';
import 'package:communal_mobile/data/repositories/member_obligations_repository.dart';
import 'package:communal_mobile/data/repositories/transfer_repository.dart';
import 'package:communal_mobile/injection.dart';
import 'package:communal_mobile/screens/obligations/data/fine_nip_settlement.dart';
import 'package:communal_mobile/screens/transactions/models/transaction_details_data.dart';
import 'package:communal_mobile/core/widgets/space.dart';

const Color _kFineRed = Color(0xFFD7263D);

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

class _FineConfirmPaymentScreenState extends State<FineConfirmPaymentScreen>
    with PaymentAuthorization<FineConfirmPaymentScreen> {
  final MemberObligationsRepository _repository =
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
            promptTitle: 'Authorize payment',
            promptSubtitle:
                'Use biometrics to confirm paying fine: ${widget.fine.description}',
          )
        : biometricSigner.signTransferIntent(
            promptTitle: 'Authorize payment',
            promptSubtitle: 'Use biometrics to confirm this fine payment',
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
          child: PinPadBody(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
            header: [
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
            ],
            pad: buildPaymentPinPad(),
            footer: [
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
            ? _kFineRed.withValues(alpha: 0.16)
            : const Color(0xFFFFEEF0),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        children: [
          Text(
            "You're paying a fine",
            style: TextStyle(
              fontSize: 15.sp,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          vSpace(2),
          Text(
            Money(widget.amountMinor, widget.fine.currency).format(),
            style: TextStyle(
              fontSize: 24.sp,
              fontWeight: FontWeight.w800,
              color: _kFineRed,
            ),
          ),
          vSpace(2),
          Text(
            widget.fine.description,
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

  Future<void> _confirmNipFundedPayment(
    AuthAuthenticated authState,
    Map<String, String> authHeaders,
  ) async {
    CooperativeCashBankAccount? cash = widget.cashAccount;
    if (cash == null || cash.id.isEmpty) {
      final accounts = await _repository.fetchCooperativeCashBankAccounts(
        cooperativeId: widget.cooperativeId,
      );
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

    final currencySymbol =
        activeCurrency.display.forCurrency(widget.fine.currency).symbol;
    final currencyCode = resolveCurrencyCode(authState.user);
    final narration = 'Fine: ${widget.fine.description}';

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
          currencyCode: widget.fine.currency,
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
    AuthAuthenticated authState,
    Map<String, String> authHeaders,
  ) async {
    final sourceCode = widget.sourceObligationCode?.trim() ?? '';
    if (sourceCode.isEmpty) {
      throw Exception(
          'Missing source obligation. Please go back and pick one.');
    }

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
    final currencySymbol =
        activeCurrency.display.forCurrency(widget.fine.currency).symbol;
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
          currencyCode: widget.fine.currency,
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
