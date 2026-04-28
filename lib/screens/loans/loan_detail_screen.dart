import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_state.dart';
import 'package:communal_mobile/core/utils/money.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/data/models/loan_application.dart';
import 'package:communal_mobile/data/repositories/loan_repository.dart';
import 'package:communal_mobile/injection.dart';

/// Member-side loan detail screen. Repayments are admin-driven (the
/// cooperative's processor pulls from obligations + wallet — see
/// backend `MembersController::updateLoanAndWallet`), so this screen
/// surfaces the history but does not expose a member-initiated pay
/// action. Pending applications can be cancelled here.
class LoanDetailScreen extends StatefulWidget {
  const LoanDetailScreen({super.key, required this.loan});

  final LoanApplication loan;

  @override
  State<LoanDetailScreen> createState() => _LoanDetailScreenState();
}

class _LoanDetailScreenState extends State<LoanDetailScreen> {
  final LoanRepository _repo = LoanRepository(getIt());
  bool _loadingHistory = false;
  bool _cancelling = false;
  String? _historyError;
  String? _cancelError;
  List<Map<String, dynamic>> _history = const [];
  late LoanApplication _loan;

  @override
  void initState() {
    super.initState();
    _loan = widget.loan;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadHistory());
  }

  Future<void> _loadHistory() async {
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) return;
    final ledger = auth.user.ledgerNumber?.trim();
    if (ledger == null || ledger.isEmpty || _loan.referenceId.isEmpty) {
      return;
    }
    setState(() {
      _loadingHistory = true;
      _historyError = null;
    });
    try {
      final rows = await _repo.fetchLoanRepayments(
        ledgerNumber: ledger,
        referenceId: _loan.referenceId,
      );
      if (!mounted) return;
      setState(() {
        _history = rows;
        _loadingHistory = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingHistory = false;
        _historyError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _confirmCancel() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        title: const Text('Cancel application?'),
        content: const Text(
          'This withdraws your loan application. Your guarantors will no longer be asked to approve it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep application'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFE74C3C),
            ),
            child: const Text('Yes, cancel'),
          ),
        ],
      ),
    );
    if (result != true) return;

    setState(() {
      _cancelling = true;
      _cancelError = null;
    });
    try {
      await _repo.cancelApplication(_loan.referenceId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Application cancelled')),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cancelling = false;
        _cancelError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          backgroundColor: Colors.grey.shade50,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: _cancelling ? null : () => context.pop(),
          ),
          title: Text(
            'Loan Details',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _loadHistory,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderCard(),
                  vSpace(16),
                  _buildMetadataCard(),
                  if (_loan.guarantors.isNotEmpty) ...[
                    vSpace(16),
                    _buildGuarantorsCard(),
                  ],
                  vSpace(16),
                  _buildHistoryCard(),
                  if (_loan.status == LoanStatus.pending) ...[
                    vSpace(24),
                    _buildCancelButton(),
                    if (_cancelError != null) ...[
                      vSpace(8),
                      Text(
                        _cancelError!,
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: const Color(0xFFE74C3C),
                        ),
                      ),
                    ],
                  ],
                  vSpace(32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    final isApproved = _loan.status == LoanStatus.approved;
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: const Color(0xFF7434FF),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _loan.loanCode.isNotEmpty ? _loan.loanCode : 'Loan',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text(
                  _loan.status.label,
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          vSpace(16),
          Text(
            isApproved ? 'Outstanding Balance' : 'Amount Requested',
            style: TextStyle(
              fontSize: 13.sp,
              color: Colors.white.withOpacity(0.85),
            ),
          ),
          vSpace(4),
          Text(
            isApproved ? _loan.balanceLabel : _loan.amountLabel,
            style: TextStyle(
              fontSize: 32.sp,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          if (isApproved) ...[
            vSpace(16),
            Stack(
              children: [
                Container(
                  height: 8.h,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: _loan.repaymentProgress,
                  child: Container(
                    height: 8.h,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                  ),
                ),
              ],
            ),
            vSpace(8),
            Text(
              '${_loan.progressLabel} repaid (${_loan.amountLabel} principal)',
              style: TextStyle(
                fontSize: 12.sp,
                color: Colors.white.withOpacity(0.85),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetadataCard() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Loan Details',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F1D40),
            ),
          ),
          vSpace(12),
          if (_loan.referenceId.isNotEmpty)
            _detailRow('Reference', _loan.referenceId),
          if (_loan.loanCode.isNotEmpty)
            _detailRow('Scheme', _loan.loanCode),
          _detailRow('Principal', _loan.amountLabel),
          if (_loan.status == LoanStatus.approved) ...[
            _detailRow('Repaid', Money(_loan.amountPaidMinor, _loan.currency).format()),
            _detailRow('Monthly Repayment', _loan.monthlyRepaymentLabel),
          ],
          if (_loan.interestMinor > 0)
            _detailRow('Interest', Money(_loan.interestMinor, _loan.currency).format()),
          _detailRow('Applied', _loan.createdAtLabel),
          if (_loan.dateApproved != null)
            _detailRow(
              'Approved',
              DateFormat('MMM dd, yyyy').format(_loan.dateApproved!),
            ),
          if (_loan.dueDateLabel != null)
            _detailRow('Due', _loan.dueDateLabel!),
          if (_loan.broughtForward)
            _detailRow('Origin', 'Brought forward'),
          if (_loan.reasonForLoan != null &&
              _loan.reasonForLoan!.trim().isNotEmpty)
            _detailRow('Purpose', _loan.reasonForLoan!),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style:
                  TextStyle(fontSize: 13.sp, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0F1D40),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuarantorsCard() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Guarantors (${_loan.guarantors.length})',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F1D40),
            ),
          ),
          vSpace(12),
          ..._loan.guarantors.map(
            (ledger) => Padding(
              padding: EdgeInsets.only(bottom: 8.h),
              child: Row(
                children: [
                  Icon(Icons.check_circle,
                      size: 18.sp, color: const Color(0xFF4CAF50)),
                  hSpace(8),
                  Expanded(
                    child: Text(
                      ledger,
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0F1D40),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Repayment History',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F1D40),
            ),
          ),
          vSpace(12),
          if (_loadingHistory && _history.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_historyError != null)
            Text(
              _historyError!,
              style: TextStyle(
                fontSize: 13.sp,
                color: const Color(0xFFE74C3C),
              ),
            )
          else if (_history.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 16.h),
              child: Text(
                _loan.status == LoanStatus.approved
                    ? 'No repayments yet. Your cooperative draws repayments from your obligations and wallet.'
                    : 'No payments recorded yet.',
                style:
                    TextStyle(fontSize: 13.sp, color: Colors.grey.shade600),
              ),
            )
          else
            ..._history.map(_historyRow),
        ],
      ),
    );
  }

  Widget _historyRow(Map<String, dynamic> row) {
    final amountMinor =
        int.tryParse(row['amount']?.toString() ?? '0') ?? 0;
    final date = DateTime.tryParse(row['created_at']?.toString() ?? '') ??
        DateTime.now();
    final mode = row['payment_mode']?.toString().trim() ?? '';
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Row(
        children: [
          Container(
            width: 36.w,
            height: 36.w,
            decoration: const BoxDecoration(
              color: Color(0xFFEDE7FA),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.south_west,
                size: 18.sp, color: const Color(0xFF7434FF)),
          ),
          hSpace(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Repayment',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0F1D40),
                  ),
                ),
                vSpace(2),
                Text(
                  mode.isEmpty
                      ? DateFormat('MMM dd, yyyy').format(date)
                      : '${DateFormat('MMM dd, yyyy').format(date)} • $mode',
                  style:
                      TextStyle(fontSize: 11.sp, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Text(
            Money(amountMinor, _loan.currency).format(),
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F1D40),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCancelButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: _cancelling ? null : _confirmCancel,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFE74C3C)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          padding: EdgeInsets.symmetric(vertical: 14.h),
        ),
        child: _cancelling
            ? SizedBox(
                width: 20.w,
                height: 20.w,
                child: const CircularProgressIndicator(
                  color: Color(0xFFE74C3C),
                  strokeWidth: 2,
                ),
              )
            : Text(
                'Cancel Application',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFE74C3C),
                ),
              ),
      ),
    );
  }
}
