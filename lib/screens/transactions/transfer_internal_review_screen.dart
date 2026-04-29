import 'package:communal_mobile/core/utils/app_currency.dart';
import 'package:communal_mobile/core/utils/money.dart';
import 'package:communal_mobile/core/utils/money_formatter.dart';
import 'package:communal_mobile/core/utils/tap_debouncer.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_state.dart';
import 'package:communal_mobile/data/local/transfer_favorites_prefs.dart';
import 'package:communal_mobile/screens/obligations/data/obligation_nip_settlement.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class TransferInternalReviewScreen extends StatefulWidget {
  const TransferInternalReviewScreen({
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

  /// Integer count of the smallest unit of [currency] (kobo for NGN, cents
  /// for USD, no fractional unit for JPY). Audit M20 leaf migration.
  final int amountMinor;

  /// ISO 4217 alpha-3 code (`NGN`, `USD`, `BHD`, ...).
  final String currency;
  final String narration;
  final bool saveAsBeneficiary;

  /// When true, continue to NIP verify flow instead of book transfer verify.
  final bool useExternalNipFlow;

  /// When set, a successful transfer will record an obligation payment on the receipt screen.
  final ObligationNipSettlement? obligationNipSettlement;

  @override
  State<TransferInternalReviewScreen> createState() =>
      _TransferInternalReviewScreenState();
}

class _TransferInternalReviewScreenState
    extends State<TransferInternalReviewScreen> {
  bool _saveAsBeneficiary = false;
  // Audit M28: swallows rapid double-taps on the Send Money button.
  final TapDebouncer _sendDebouncer = TapDebouncer();

  @override
  void initState() {
    super.initState();
    _saveAsBeneficiary = widget.saveAsBeneficiary;
  }

  String _amountText(String currencySymbol) {
    final formatted = formatMinor(widget.amountMinor, widget.currency);
    return '$currencySymbol$formatted';
  }

  String _amountInWords(String currencyCode) {
    // Whole-major part for the words form; fractional minor units (kobo,
    // cents, ...) are rendered numerically by [_amountText] above.
    final major = widget.amountMinor ~/ factorFor(widget.currency);
    final name = majorCurrencyNameForCode(currencyCode);
    if (major <= 0) return 'Zero $name only';
    return '${_toWords(major)} $name only';
  }

  String _balanceAfterTransferText(
    int currentBalanceMinor,
    String currencySymbol,
  ) {
    final after = currentBalanceMinor - widget.amountMinor;
    final safeAfter = after < 0 ? 0 : after;
    return '$currencySymbol${formatMinor(safeAfter, widget.currency)}';
  }

  String _toWords(int value) {
    const units = [
      'Zero',
      'One',
      'Two',
      'Three',
      'Four',
      'Five',
      'Six',
      'Seven',
      'Eight',
      'Nine',
      'Ten',
      'Eleven',
      'Twelve',
      'Thirteen',
      'Fourteen',
      'Fifteen',
      'Sixteen',
      'Seventeen',
      'Eighteen',
      'Nineteen',
    ];
    const tens = [
      '',
      '',
      'Twenty',
      'Thirty',
      'Forty',
      'Fifty',
      'Sixty',
      'Seventy',
      'Eighty',
      'Ninety',
    ];
    if (value < 20) return units[value];
    if (value < 100) {
      final t = tens[value ~/ 10];
      final r = value % 10;
      return r == 0 ? t : '$t ${units[r]}';
    }
    if (value < 1000) {
      final h = '${units[value ~/ 100]} Hundred';
      final r = value % 100;
      return r == 0 ? h : '$h ${_toWords(r)}';
    }
    if (value < 1000000) {
      final th = '${_toWords(value ~/ 1000)} Thousand';
      final r = value % 1000;
      return r == 0 ? th : '$th ${_toWords(r)}';
    }
    if (value < 1000000000) {
      final m = '${_toWords(value ~/ 1000000)} Million';
      final r = value % 1000000;
      return r == 0 ? m : '$m ${_toWords(r)}';
    }
    final b = '${_toWords(value ~/ 1000000000)} Billion';
    final r = value % 1000000000;
    return r == 0 ? b : '$b ${_toWords(r)}';
  }

  String _dateTimeText(DateTime dt) {
    return DateFormat('MMMM d, y • h:mm a').format(dt);
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

  Future<void> _sendMoney() async {
    final extra = <String, dynamic>{
      'favorite': widget.recipient.toJson(),
      'amountMinor': widget.amountMinor,
      'currency': widget.currency,
      'narration': widget.narration,
      'saveAsBeneficiary': _saveAsBeneficiary,
      if (widget.useExternalNipFlow) 'useExternalNipFlow': true,
      if (widget.obligationNipSettlement != null)
        'obligationNipSettlement': widget.obligationNipSettlement!.toJson(),
    };
    // ignore: unawaited_futures
    context.pushNamed(
      widget.useExternalNipFlow
          ? 'transfer-external-verify'
          : 'transfer-internal-verify',
      extra: extra,
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final authState = context.watch<AuthBloc>().state;
    final walletBalanceKobo = authState is AuthAuthenticated
        ? authState.user.walletBalanceKobo
        : 0;
    final currencyCode = authState is AuthAuthenticated
        ? resolveCurrencyCode(authState.user)
        : 'NGN';
    final currencySymbol = currencySymbolForCode(currencyCode);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 22),
          onPressed: () => context.pop(),
        ),
        title: const Text('Review Transfer'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12.r),
                gradient: const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Color(0xFF8C66F5), Color(0xFF6A39F3)],
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'Transfer Amount',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  vSpace(6),
                  Text(
                    _amountText(currencySymbol),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  vSpace(4),
                  Text(
                    _amountInWords(currencyCode),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            vSpace(12),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: const Color(0xFFE7E7E7)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recipient Details',
                    style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w700),
                  ),
                  vSpace(10),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20.r,
                        backgroundColor: const Color(0xFF8F6BFF),
                        child: Text(
                          _initials(widget.recipient.accountName),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w700,
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
                                      fontSize: 15.sp,
                                      fontWeight: FontWeight.w600,
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
                ],
              ),
            ),
            vSpace(12),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: const Color(0xFFE7E7E7)),
              ),
              child: Column(
                children: [
                  _kv('Transfer Type', 'Book Transfer'),
                  _kv(
                    'Transfer fee',
                    '$currencySymbol${NumberFormat('#,##0.00').format(0)}',
                  ),
                  _kv(
                    'Naration',
                    widget.narration.trim().isEmpty ? 'Transfer' : widget.narration,
                  ),
                  _kv('Date & Time', _dateTimeText(now), isLast: true),
                ],
              ),
            ),
            vSpace(12),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: const Color(0xFFE7E7E7)),
              ),
              child: Row(
                children: [
                  Icon(Icons.account_balance_wallet, color: Colors.green, size: 20.sp),
                  hSpace(8),
                  Expanded(
                    child: Text(
                      'Balance After Transfer',
                      style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    _balanceAfterTransferText(walletBalanceKobo, currencySymbol),
                    style: TextStyle(
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1AAE70),
                    ),
                  ),
                ],
              ),
            ),
            vSpace(10),
            Row(
              children: [
                Checkbox(
                  value: _saveAsBeneficiary,
                  side: BorderSide(
                    color: Theme.of(context).primaryColor,
                    width: 1.5,
                  ),
                  activeColor: Theme.of(context).primaryColor,
                  checkColor: Colors.white,
                  onChanged: (v) =>
                      setState(() => _saveAsBeneficiary = v ?? false),
                ),
                Expanded(
                  child: Text(
                    'Save as beneficiary',
                    style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(
                  color: Theme.of(context).primaryColor,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.shield_outlined, color: Theme.of(context).primaryColor),
                  hSpace(8),
                  Expanded(
                    child: Text(
                      "You'll need to confirm this transfer with your secure PIN or biometrics",
                      style: TextStyle(
                        fontSize: 15.sp,
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            vSpace(10),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: EdgeInsets.fromLTRB(16.w, 0, 16.w, 14.h),
        child: SizedBox(
          width: double.infinity,
          height: 50.h,
          child: InkWell(
            onTap: () => _sendDebouncer.run(_sendMoney),
            borderRadius: BorderRadius.circular(12.r),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12.r),
                gradient: const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Color(0xFF8C66F5), Color(0xFF6A39F3)],
                ),
              ),
              child: Center(
                child: Text(
                  'Send Money',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _kv(String label, String value, {bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 15.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          hSpace(8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
