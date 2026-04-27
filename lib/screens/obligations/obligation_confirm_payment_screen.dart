import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_state.dart';
import 'package:communal_mobile/core/utils/app_currency.dart';
import 'package:communal_mobile/core/utils/idempotency.dart';
import 'package:communal_mobile/core/utils/money.dart';
import 'package:communal_mobile/core/utils/money_formatter.dart';
import 'package:communal_mobile/data/local/transfer_favorites_prefs.dart';
import 'package:communal_mobile/data/repositories/member_obligations_repository.dart';
import 'package:communal_mobile/data/repositories/transfer_repository.dart';
import 'package:communal_mobile/injection.dart';
import 'package:communal_mobile/screens/obligations/data/obligation_nip_settlement.dart';
import 'package:communal_mobile/screens/obligations/data/sample_obligations.dart';
import 'package:communal_mobile/screens/transactions/models/transaction_details_data.dart';
import 'package:communal_mobile/core/widgets/space.dart';

class ObligationConfirmPaymentScreen extends StatefulWidget {
  const ObligationConfirmPaymentScreen({
    super.key,
    required this.obligation,
    required this.amount,
    required this.method,
    this.cashAccount,
    this.cashRepositoryId,
  });

  final Obligation obligation;
  final double amount;
  final String method;
  final CooperativeCashBankAccount? cashAccount;

  /// When [cashAccount] is missing (e.g. route extra dropped), resolve via API using this id.
  final String? cashRepositoryId;

  @override
  State<ObligationConfirmPaymentScreen> createState() =>
      _ObligationConfirmPaymentScreenState();
}

class _ObligationConfirmPaymentScreenState
    extends State<ObligationConfirmPaymentScreen> {
  final MemberObligationsRepository _repository =
      MemberObligationsRepository(getIt());
  final TransferRepository _transferRepo = getIt<TransferRepository>();
  late final List<TextEditingController> _pinControllers;
  late final List<FocusNode> _pinFocusNodes;
  bool _obscurePin = true;
  bool _submitting = false;

  /// Audit M23: minted once per screen mount; reused across user-initiated
  /// retries of the Confirm action so a transient failure + retry dedupes
  /// server-side instead of double-paying the obligation.
  late final String _idempotencyKey = newIdempotencyKey();

  @override
  void initState() {
    super.initState();
    _pinControllers = List.generate(
      4,
      (_) => TextEditingController(),
      growable: false,
    );
    _pinFocusNodes = List.generate(4, (_) => FocusNode(), growable: false);
  }

  @override
  void dispose() {
    for (final controller in _pinControllers) {
      controller.dispose();
    }
    for (final node in _pinFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  bool get _pinCompletelyEmpty =>
      _pinControllers.every((c) => c.text.isEmpty);

  /// System / gesture back while PIN is partial: clear the last filled digit first.
  void _handleSystemBackDuringPinEntry() {
    for (var i = _pinControllers.length - 1; i >= 0; i--) {
      if (_pinControllers[i].text.isNotEmpty) {
        _pinControllers[i].clear();
        _pinFocusNodes[i].requestFocus();
        setState(() {});
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _pinCompletelyEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleSystemBackDuringPinEntry();
      },
      child: Scaffold(
      backgroundColor: const Color(0xFFF6F6F9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            if (!_pinCompletelyEmpty) {
              _handleSystemBackDuringPinEntry();
              return;
            }
            Navigator.of(context).maybePop();
          },
        ),
        title: Text(
          'Confirm Payment',
          style: TextStyle(
            fontSize: 19.sp,
            fontWeight: FontWeight.w700,
            color: Colors.black,
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
              Icons.lock_outline,
              color: const Color(0xFF7434FF),
              size: 44.sp,
            ),
            vSpace(16),
            Text(
              'Enter Your PIN',
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
            vSpace(6),
            Text(
              'Enter your 4-digit transaction PIN to authorize this payment',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14.sp, color: Colors.grey.shade600),
            ),
            vSpace(24),
            _buildAmountBanner(),
            vSpace(24),
            _buildPinInputs(),
            vSpace(12),
            TextButton.icon(
              onPressed: () => setState(() => _obscurePin = !_obscurePin),
              icon: Icon(
                _obscurePin ? Icons.visibility : Icons.visibility_off,
                color: Colors.grey.shade700,
                size: 18.sp,
              ),
              label: Text(
                _obscurePin ? 'Show PIN' : 'Hide PIN',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
            vSpace(24),
            _buildSecureInfo(),
            vSpace(32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _onConfirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7434FF),
                  minimumSize: Size(double.infinity, 52.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18.r),
                  ),
                ),
                child: Text(
                  _submitting ? 'Processing...' : 'Authorize Payment',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                      color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildAmountBanner() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 18.h),
      decoration: BoxDecoration(
        color: const Color(0xFFEFE7FF),
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: Column(
        children: [
          Text(
            "You're paying",
            style: TextStyle(fontSize: 14.sp, color: Colors.grey.shade700),
          ),
          vSpace(4),
          Text(
            '₦${formatMoney(widget.amount)}',
            style: TextStyle(
              fontSize: 30.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF7434FF),
            ),
          ),
          vSpace(4),
          Text(
            'to ${widget.obligation.category}',
            style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade600),
          ),
          Text(
            widget.obligation.title,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPinInputs() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12.w,
      children: List.generate(
        4,
        (index) => Focus(
          onKeyEvent: (node, event) {
            if (event is! KeyDownEvent) return KeyEventResult.ignored;
            if (event.logicalKey != LogicalKeyboardKey.backspace) {
              return KeyEventResult.ignored;
            }
            if (_pinControllers[index].text.isNotEmpty) {
              return KeyEventResult.ignored;
            }
            if (index <= 0) return KeyEventResult.ignored;
            _pinControllers[index - 1].clear();
            _pinFocusNodes[index - 1].requestFocus();
            setState(() {});
            return KeyEventResult.handled;
          },
          child: SizedBox(
            width: 56.w,
            child: TextField(
              controller: _pinControllers[index],
              focusNode: _pinFocusNodes[index],
              textAlign: TextAlign.center,
              obscureText: _obscurePin,
              maxLength: 1,
              keyboardType: TextInputType.number,
              style: TextStyle(
                fontSize: 26.sp,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                counterText: '',
                contentPadding: EdgeInsets.symmetric(vertical: 18.h),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14.r),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14.r),
                  borderSide: const BorderSide(
                    color: Color(0xFF7434FF),
                    width: 2,
                  ),
                ),
              ),
              onChanged: (value) => _handlePinInput(index, value),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSecureInfo() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: const Color(0xFFE6F1FF),
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
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F1D40),
                  ),
                ),
                vSpace(4),
                Text(
                  'Your transaction is encrypted and secure. Never share your PIN with anyone.',
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handlePinInput(int index, String value) {
    if (value.isNotEmpty) {
      if (index < _pinFocusNodes.length - 1) {
        _pinFocusNodes[index + 1].requestFocus();
      } else {
        _pinFocusNodes[index].unfocus();
      }
    } else if (index > 0) {
      _pinFocusNodes[index - 1].requestFocus();
    }
    setState(() {});
  }

  Future<void> _onConfirm() async {
    final pin = _pinControllers.map((c) => c.text).join();
    if (pin.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your 4-digit PIN to continue.')),
      );
      return;
    }

    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in again and retry.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await _repository.verifySecurityPin(pin);

      if (widget.obligation.category == 'Equity' &&
          widget.amount > widget.obligation.balance + 0.009) {
        throw Exception(
          'Equity payments cannot exceed your remaining cap (₦${formatMoney(widget.obligation.balance)}).',
        );
      }

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
        amountNaira: widget.amount,
      );

      final currencySymbol = currencySymbolForUser(authState.user);
      final currencyCode = resolveCurrencyCode(authState.user);
      final narration = 'Obligation: ${widget.obligation.title}';
      // Audit M20: integer minor units derived currency-agnostically rather
      // than the legacy `(amount * 100).round()` (which was kobo-locked).
      final amountMinor = Money.fromMajor(widget.amount, currencyCode).amountMinor;

      final result = await _transferRepo.initiateTransfer(
        type: 'NIPTransfer',
        amountMinor: amountMinor,
        narration: narration.trim().isEmpty ? 'Transfer' : narration,
        counterPartyId: fav.accountId,
        currencyCode: currencyCode,
        idempotencyKey: _idempotencyKey,
      );

      if (!mounted) return;
      final mapped = transactionStatusFromApi(result.status);
      context.pushNamed(
        'transaction-receipt',
        extra: {
          'details': TransactionDetailsData(
            id: result.transferId,
            counterpartyName: fav.accountName,
            counterpartyBank: fav.bank,
            counterpartyAccount: fav.accountNumber,
            amount: widget.amount,
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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
