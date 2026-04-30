import 'package:flutter/material.dart';
import 'package:communal_mobile/core/utils/system_ui_style.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_state.dart';
import 'package:communal_mobile/core/utils/money.dart';
import 'package:communal_mobile/core/widgets/app_toast.dart';
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

    setState(() => _cancelling = true);
    try {
      await _repo.cancelApplication(_loan.referenceId);
      if (!mounted) return;
      AppToast.success('Application cancelled');
      context.pop();
    } catch (e) {
      if (!mounted) return;
      AppToast.error(e.toString().replaceFirst('Exception: ', ''));
      setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemOverlayForTheme(Theme.of(context)),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _cancelling ? null : () => context.pop(),
          ),
          title: Text(
            'Loan Details',
            style: TextStyle(
              fontSize: 19.sp,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
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
                  _buildHistoryOrDeclineCard(),
                  if (_loan.status == LoanStatus.approved &&
                      _loan.balanceMinor > 0) ...[
                    vSpace(24),
                    _buildRepayButton(),
                  ],
                  if (_loan.status == LoanStatus.pending) ...[
                    vSpace(24),
                    _buildCancelButton(),
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
    // Loans use the orange brand accent (matches LoanOfferCard +
    // ActiveLoanCard chrome). The detail header used to inherit the
    // app's purple primary, which made the loan area read as two
    // different products as the user moved from list → detail.
    const loanOrange = Color(0xFFE67E22);
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: loanOrange,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                // Prefer the scheme title (e.g. "Welfare Loan") over the
                // raw loan_code so the header is recognisable at a
                // glance. displayLabel falls back to the code, then the
                // reference id, when no title is available.
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _loan.displayLabel,
                      style: TextStyle(
                        fontSize: 19.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    if (_loan.loanTitle.trim().isNotEmpty &&
                        _loan.loanCode.trim().isNotEmpty) ...[
                      vSpace(2),
                      Text(
                        _loan.loanCode,
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: Colors.white.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text(
                  _loan.status.label,
                  style: TextStyle(
                    fontSize: 16.sp,
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
              fontSize: 17.sp,
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
                      color: Theme.of(context).cardColor,
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
                fontSize: 16.sp,
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
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Loan Details',
            style: TextStyle(
              fontSize: 19.sp,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          vSpace(12),
          if (_loan.referenceId.isNotEmpty)
            _detailRow('Reference', _loan.referenceId),
          // Surface the scheme title up front so members recognise the
          // loan; keep the bare code below as a separate Scheme code
          // row for cross-referencing with admin tooling. When no title
          // came back from the backend, fall through to the code only.
          if (_loan.loanTitle.trim().isNotEmpty)
            _detailRow('Scheme', _loan.loanTitle.trim()),
          if (_loan.loanCode.trim().isNotEmpty)
            _detailRow(
              _loan.loanTitle.trim().isNotEmpty ? 'Scheme code' : 'Scheme',
              _loan.loanCode.trim(),
            ),
          _detailRow('Principal', _loan.amountLabel),
          if (_loan.status == LoanStatus.approved) ...[
            _detailRow(
              'Repaid',
              Money(_loan.amountPaidMinor, _loan.currency).format(),
            ),
            _detailRow('Monthly Repayment', _loan.monthlyRepaymentLabel),
          ],
          if (_loan.interestMinor > 0)
            _detailRow(
              'Interest',
              Money(_loan.interestMinor, _loan.currency).format(),
            ),
          _detailRow('Applied', _loan.createdAtLabel),
          if (_loan.dateApproved != null)
            _detailRow(
              'Approved',
              DateFormat('MMM dd, yyyy').format(_loan.dateApproved!),
            ),
          if (_loan.dueDateLabel != null)
            _detailRow('Due', _loan.dueDateLabel!),
          if (_loan.broughtForward) _detailRow('Origin', 'Brought forward'),
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
              style: TextStyle(
                fontSize: 17.sp,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 17.sp,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuarantorsCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Guarantors (${_loan.guarantors.length})',
            style: TextStyle(
              fontSize: 19.sp,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          vSpace(12),
          ..._loan.guarantors.map(
            (ledger) => Padding(
              padding: EdgeInsets.only(bottom: 8.h),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 18.sp,
                    color: const Color(0xFF4CAF50),
                  ),
                  hSpace(8),
                  Expanded(
                    child: Text(
                      ledger,
                      style: TextStyle(
                        fontSize: 17.sp,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
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

  /// Declined loans never had repayments and never will, so the
  /// admin's reason is the only history that matters here. Anything
  /// else (approved / pending / cancelled / closed / unknown) falls
  /// through to the actual repayment history list.
  Widget _buildHistoryOrDeclineCard() {
    if (_loan.status == LoanStatus.declined) {
      return _buildDeclineReasonCard();
    }
    return _buildHistoryCard();
  }

  Widget _buildDeclineReasonCard() {
    final theme = Theme.of(context);
    final reason = _loan.declineNote?.trim() ?? '';
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: const Color(0xFFE74C3C).withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.cancel_outlined,
                size: 20.sp,
                color: const Color(0xFFE74C3C),
              ),
              hSpace(8),
              Text(
                'Reason for decline',
                style: TextStyle(
                  fontSize: 19.sp,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          vSpace(12),
          Text(
            reason.isEmpty
                ? 'Your cooperative declined this application but did not record a reason. Reach out to your admin for more context.'
                : reason,
            style: TextStyle(
              fontSize: 17.sp,
              height: 1.45,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Repayment History',
            style: TextStyle(
              fontSize: 19.sp,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
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
              style: TextStyle(fontSize: 17.sp, color: const Color(0xFFE74C3C)),
            )
          else if (_history.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 16.h),
              child: Text(
                _loan.status == LoanStatus.approved
                    ? 'No repayments yet. Tap "Make Repayment" below to pay from your wallet or a non-equity obligation.'
                    : 'No payments recorded yet.',
                style: TextStyle(
                  fontSize: 17.sp,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            )
          else
            ..._history.map(_historyRow),
        ],
      ),
    );
  }

  Widget _historyRow(Map<String, dynamic> row) {
    // Backend can serialise the kobo amount as either an int string
    // ("500000") or a numeric-string with a decimal ("500000.00") —
    // the latter happens whenever the underlying column is or was a
    // DECIMAL, or when an intermediate cast emits a float. int.tryParse
    // returns null on the second form and the row rendered as ₦0 even
    // though the repo's filter (num.tryParse > 0) had let it through.
    // num.tryParse + .round handles both shapes.
    final amountMinor = (num.tryParse(row['amount']?.toString() ?? '0') ?? 0).round();
    final date =
        DateTime.tryParse(row['created_at']?.toString() ?? '') ??
        DateTime.now();
    final mode = row['payment_mode']?.toString().trim() ?? '';
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Row(
        children: [
          Container(
            width: 36.w,
            height: 36.w,
            decoration: BoxDecoration(
              // Soft orange tint to match the loan area's orange chrome.
              color: const Color(0xFFFFF4E9),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.south_west,
              size: 18.sp,
              color: const Color(0xFFE67E22),
            ),
          ),
          hSpace(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Repayment',
                  style: TextStyle(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                vSpace(2),
                Text(
                  mode.isEmpty
                      ? DateFormat('MMM dd, yyyy').format(date)
                      : '${DateFormat('MMM dd, yyyy').format(date)} • $mode',
                  style: TextStyle(
                    fontSize: 16.sp,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          Text(
            Money(amountMinor, _loan.currency).format(),
            style: TextStyle(
              fontSize: 17.sp,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRepayButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => context.pushNamed('loan-payment', extra: _loan),
        icon: const Icon(Icons.payments_outlined),
        label: Text(
          'Make Repayment',
          style: TextStyle(fontSize: 19.sp, fontWeight: FontWeight.w700),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE67E22),
          foregroundColor: Colors.white,
          minimumSize: Size(double.infinity, 52.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18.r),
          ),
        ),
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
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFE74C3C),
                ),
              ),
      ),
    );
  }
}
