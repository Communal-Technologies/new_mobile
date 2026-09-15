import 'package:communal_mobile/core/security/biometric_signer_service.dart';
import 'package:communal_mobile/core/utils/app_currency.dart';
import 'package:communal_mobile/core/utils/idempotency.dart';
import 'package:communal_mobile/core/utils/money.dart';
import 'package:communal_mobile/core/utils/money_formatter.dart';
import 'package:communal_mobile/core/widgets/payment_authorization.dart';
import 'package:communal_mobile/core/widgets/pin_pad_body.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/data/local/transfer_favorites_prefs.dart';
import 'package:communal_mobile/data/repositories/transfer_repository.dart';
import 'package:communal_mobile/injection.dart';
import 'package:communal_mobile/screens/obligations/data/obligation_nip_settlement.dart';
import 'package:communal_mobile/screens/transactions/models/transaction_details_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

/// Transfer authorization screen. Biometrics or the PIN pad, as described on
/// [PaymentAuthorization]; a PIN is submitted through `verifySecurityPin`,
/// which writes the marker transactions-svc checks.
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
    extends State<TransferInternalVerifyScreen>
    with PaymentAuthorization<TransferInternalVerifyScreen> {
  final _repo = getIt<TransferRepository>();
  final _favorites = getIt<TransferFavoritesPrefs>();

  /// Audit M23: minted once per screen mount and reused across retries so a
  /// network drop + user retry on the Confirm button dedupes server-side.
  /// A fresh key is only generated when the user navigates away and re-enters.
  late final String _idempotencyKey = newIdempotencyKey();

  @override
  String get pinIntent => 'transfer';

  @override
  Future<BiometricSignedHeaders> signBiometricIntent() {
    // Audit M38: backend mints a one-time nonce via /security/biometric/
    // challenge; we sign it with the Keystore-bound key; headers travel
    // with the initiate call.
    return biometricSigner.signTransferIntent(
      promptTitle: 'Authorize transfer',
      promptSubtitle: 'Use biometrics to confirm this transfer',
    );
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

  @override
  Future<void> submitAuthorized({
    String? pin,
    Map<String, String>? biometricHeaders,
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
    return withPaymentLoader(
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
          child: PinPadBody(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            header: [
              Text(
                offerBiometric ? 'Confirm Transfer' : 'Enter Transaction PIN',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              vSpace(4),
              Text(
                offerBiometric
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
            ],
            pad: buildPaymentPinPad(),
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
