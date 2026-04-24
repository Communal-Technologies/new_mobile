import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/data/local/transfer_favorites_prefs.dart';
import 'package:communal_mobile/data/repositories/transfer_repository.dart';
import 'package:communal_mobile/injection.dart';
import 'package:communal_mobile/screens/transactions/models/transaction_details_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

class TransferInternalVerifyScreen extends StatefulWidget {
  const TransferInternalVerifyScreen({
    super.key,
    required this.recipient,
    required this.amountKobo,
    required this.narration,
    required this.saveAsBeneficiary,
  });

  final TransferFavorite recipient;
  final int amountKobo;
  final String narration;
  final bool saveAsBeneficiary;

  @override
  State<TransferInternalVerifyScreen> createState() =>
      _TransferInternalVerifyScreenState();
}

class _TransferInternalVerifyScreenState
    extends State<TransferInternalVerifyScreen> {
  final _repo = getIt<TransferRepository>();
  final _favorites = getIt<TransferFavoritesPrefs>();
  String _pin = '';
  bool _submitting = false;

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

  void _onDigit(String d) {
    if (_submitting || _pin.length >= 4) return;
    setState(() => _pin += d);
  }

  void _onBackspace() {
    if (_submitting || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _confirm() async {
    if (_pin.length != 4 || _submitting) return;
    setState(() => _submitting = true);
    try {
      await _repo.verifySecurityPin(_pin);
      final result = await _repo.initiateTransfer(
        type: 'BookTransfer',
        amountKobo: widget.amountKobo,
        narration: widget.narration.trim().isEmpty ? 'Transfer' : widget.narration,
        destinationAccountId: widget.recipient.accountId,
      );
      if (widget.saveAsBeneficiary) {
        await _favorites.upsert(widget.recipient);
      }
      if (!mounted) return;
      context.pushNamed(
        'transaction-receipt',
        extra: {
          'details': TransactionDetailsData(
            id: result.transferId,
            counterpartyName: widget.recipient.accountName,
            counterpartyBank: widget.recipient.bank,
            counterpartyAccount: widget.recipient.accountNumber,
            amount: widget.amountKobo / 100,
            currencySymbol: '₦',
            transactionType: 'Book Transfer',
            dateTime: DateTime.now(),
            sessionId: result.transferId,
            reference: result.reference,
            description: widget.narration,
            paymentMethod: 'Wallet',
            fees: 0,
            isIncoming: false,
            status: TransactionStatus.pending,
          ),
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
    final canSubmit = _pin.length == 4 && !_submitting;
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
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
              'Verify Transaction',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 26.sp, fontWeight: FontWeight.w700),
            ),
            vSpace(6),
            Text(
              'Enter your PIN to complete this transfer',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
            vSpace(12),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: const Color(0xFFE7E7E7)),
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
                        fontSize: 12.sp,
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
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        vSpace(2),
                        Row(
                          children: [
                            Icon(
                              Icons.account_balance_outlined,
                              size: 14.sp,
                              color: Colors.black54,
                            ),
                            hSpace(4),
                            Expanded(
                              child: Text(
                                '${widget.recipient.bank} • ${widget.recipient.accountNumber}',
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontSize: 12.sp,
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
            vSpace(16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                final filled = index < _pin.length;
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.w),
                  child: Container(
                  width: 64.w,
                  height: 62.h,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: filled ? Theme.of(context).primaryColor : Colors.white,
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(
                      color: filled
                          ? Theme.of(context).primaryColor
                          : const Color(0xFFDADADA),
                    ),
                  ),
                  child: Text(
                    filled ? '*' : '',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                );
              }),
            ),
            vSpace(30),
            Expanded(
              child: GridView.count(
                crossAxisCount: 3,
                mainAxisSpacing: 8.h,
                crossAxisSpacing: 10.w,
                childAspectRatio: 1.75,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (final d in ['1', '2', '3', '4', '5', '6', '7', '8', '9'])
                    _keyButton(d, onTap: () => _onDigit(d)),
                  const SizedBox.shrink(),
                  _keyButton('0', onTap: () => _onDigit('0')),
                  _keyIconButton(
                    Icons.backspace_outlined,
                    onTap: _onBackspace,
                  ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shield_outlined, size: 16.sp, color: Colors.black54),
                hSpace(6),
                Text(
                  'End-toend encrypted transaction',
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            vSpace(12),
            SizedBox(
              width: double.infinity,
              height: 50.h,
              child: InkWell(
                onTap: canSubmit ? _confirm : null,
                borderRadius: BorderRadius.circular(12.r),
                child: Ink(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12.r),
                    gradient: canSubmit
                        ? const LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [Color(0xFF8C66F5), Color(0xFF6A39F3)],
                          )
                        : null,
                    color: canSubmit ? null : const Color(0xFFE0E0E0),
                  ),
                  child: Center(
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Text(
                            'Confirm Transfer',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _keyButton(String label, {required VoidCallback onTap}) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12.r),
      child: InkWell(
        borderRadius: BorderRadius.circular(12.r),
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: const Color(0xFFE4E4E4)),
          ),
          child: Text(
            label,
            style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  Widget _keyIconButton(IconData icon, {required VoidCallback onTap}) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12.r),
      child: InkWell(
        borderRadius: BorderRadius.circular(12.r),
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: const Color(0xFFE4E4E4)),
          ),
          child: Icon(icon, size: 24.sp, color: Colors.black87),
        ),
      ),
    );
  }
}
