import 'package:flutter/material.dart';
import 'package:communal_mobile/core/utils/system_ui_style.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_state.dart';
import 'package:communal_mobile/core/utils/money.dart';
import 'package:communal_mobile/core/utils/tap_debouncer.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/data/models/loan_scheme.dart';
import 'package:communal_mobile/data/repositories/loan_repository.dart';
import 'package:communal_mobile/injection.dart';
import 'package:communal_mobile/screens/loans/data/loan_application_draft.dart';

/// Step 3 — review the draft and submit. The submit button is gated on
/// terms acceptance and disabled while the request is in flight.
class LoanApplicationStep3Screen extends StatefulWidget {
  const LoanApplicationStep3Screen({super.key, required this.draft});

  final LoanApplicationDraft draft;

  @override
  State<LoanApplicationStep3Screen> createState() =>
      _LoanApplicationStep3ScreenState();
}

class _LoanApplicationStep3ScreenState
    extends State<LoanApplicationStep3Screen> {
  final LoanRepository _repo = LoanRepository(getIt());
  final TapDebouncer _submitDebouncer = TapDebouncer();
  bool _agreedToTerms = false;
  bool _submitting = false;
  String? _error;

  int get _principalMinor =>
      (widget.draft.amountMajor * factorFor(widget.draft.currency)).round();

  int get _monthlyMinor => estimatedMonthlyRepaymentMinor(
        principalMinor: _principalMinor,
        scheme: widget.draft.scheme,
        interestType: widget.draft.interestType,
        currency: widget.draft.currency,
      );

  int get _interestMinor =>
      (_principalMinor * widget.draft.scheme.interestRate / 100).round();

  int get _totalMinor => widget.draft.interestType == '1'
      ? _principalMinor
      : _principalMinor + _interestMinor;

  Future<void> _submit() async {
    if (!_agreedToTerms || _submitting) return;
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final guarantorLedgers = widget.draft.guarantors
          .map((g) => g.ledgerNumber)
          .toList(growable: false);
      final response = await _repo.applyForLoan(
        user: auth.user,
        scheme: widget.draft.scheme,
        amountMajor: widget.draft.amountMajor,
        interestType: widget.draft.interestType,
        employmentStatus: widget.draft.employmentStatus,
        reasonForLoan: widget.draft.reasonForLoan,
        guarantorLedgers: guarantorLedgers,
        company: widget.draft.company,
        department: widget.draft.department,
        monthlySalary: widget.draft.monthlySalary,
        outstandingLoan: widget.draft.outstandingLoan,
        otherMonthlyRepayment: widget.draft.otherMonthlyRepayment,
      );
      if (!mounted) return;
      // The current store endpoint returns a generic success message
      // but no reference id; the latest pending application is the
      // one we just created, so the success screen pulls it via the
      // member's loan list rather than relying on the response body.
      final referenceId = response['reference_id']?.toString();
      context.pushReplacementNamed(
        'loan-application-success',
        extra: {
          'amountMinor': _principalMinor,
          'currency': widget.draft.currency,
          'referenceId': referenceId,
          'message': response['message']?.toString(),
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = widget.draft.scheme;
    final currency = widget.draft.currency;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemOverlayForTheme(Theme.of(context)),
      child: Scaffold(
        backgroundColor: Theme.of(context).cardColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).cardColor,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _submitting ? null : () => context.pop(),
          ),
          title: Text(
            'Loan Application',
            style: TextStyle(
              fontSize: 19.sp,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          centerTitle: true,
          actions: [
            Padding(
              padding: EdgeInsets.only(right: 16.w),
              child: Center(
                child: Text(
                  'Step 3 of 3',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF7434FF),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                    horizontal: 16.w, vertical: 16.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildProgressIndicator(),
                    vSpace(24),
                    _buildSummaryCard(scheme, currency),
                    vSpace(24),
                    _buildGuarantorsCard(),
                    vSpace(24),
                    _buildTermsCard(),
                    vSpace(24),
                    _buildNoticeCard(),
                    if (_error != null) ...[
                      vSpace(16),
                      Container(
                        padding: EdgeInsets.all(12.w),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDECEA),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Text(
                          _error!,
                          style: TextStyle(
                            fontSize: 15.sp,
                            color: const Color(0xFFE74C3C),
                          ),
                        ),
                      ),
                    ],
                    vSpace(24),
                  ],
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(child: _buildNavigationButtons()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Review & Submit',
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF7434FF),
            ),
          ),
        ),
        vSpace(8),
        Stack(
          children: [
            Container(
              height: 4.h,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            Container(
              height: 4.h,
              decoration: BoxDecoration(
                color: const Color(0xFF7434FF),
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCard(LoanScheme scheme, String currency) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Loan Summary',
            style: TextStyle(
              fontSize: 19.sp,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          vSpace(20),
          _row('Product',
              scheme.title.isNotEmpty ? scheme.title : scheme.loanCode),
          _row('Loan Amount', Money(_principalMinor, currency).format()),
          _row('Duration', scheme.durationLabel),
          _row('Interest Rate', scheme.interestRateLabel),
          _row(
            'Interest Treatment',
            widget.draft.interestType == '1'
                ? 'Deduct on disbursal'
                : 'Add to balance',
          ),
          _row('Monthly Repayment', Money(_monthlyMinor, currency).format()),
          _row('Total Repayment', Money(_totalMinor, currency).format()),
          _row('Purpose', widget.draft.reasonForLoan),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 14.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(fontSize: 15.sp, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 15.sp,
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
    final guarantors = widget.draft.guarantors;
    if (guarantors.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Guarantors',
            style: TextStyle(
              fontSize: 19.sp,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          vSpace(16),
          ...guarantors.map(
            (g) => Padding(
              padding: EdgeInsets.only(bottom: 12.h),
              child: Row(
                children: [
                  Icon(Icons.check_circle,
                      color: const Color(0xFF4CAF50), size: 22.sp),
                  hSpace(12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          g.name,
                          style: TextStyle(
                            fontSize: 17.sp,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        vSpace(2),
                        Text(
                          g.ledgerNumber,
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
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

  Widget _buildTermsCard() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: _submitting
                ? null
                : () => setState(() => _agreedToTerms = !_agreedToTerms),
            child: Container(
              width: 24.w,
              height: 24.w,
              decoration: BoxDecoration(
                color: _agreedToTerms
                    ? const Color(0xFF7434FF)
                    : Colors.transparent,
                border: Border.all(
                  color: _agreedToTerms
                      ? const Color(0xFF7434FF)
                      : Colors.grey.shade400,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(4.r),
              ),
              child: _agreedToTerms
                  ? Icon(Icons.check, color: Colors.white, size: 16.sp)
                  : null,
            ),
          ),
          hSpace(12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 15.sp,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  height: 1.5,
                ),
                children: [
                  const TextSpan(text: 'I agree to the '),
                  TextSpan(
                    text: 'terms and conditions',
                    style: TextStyle(
                      color: const Color(0xFF7434FF),
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  const TextSpan(
                    text:
                        ' of the loan agreement and understand that this is a legally binding commitment to repay the loan.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoticeCard() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9E6),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Important:',
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          vSpace(8),
          Text(
            'Your application will be reviewed by your cooperative. You will be notified of the decision in-app and via SMS.',
            style: TextStyle(
              fontSize: 14.sp,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Row(
      children: [
        SizedBox(
          width: 100.w,
          child: OutlinedButton(
            onPressed: _submitting ? null : () => context.pop(),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.grey.shade300),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
              padding: EdgeInsets.symmetric(vertical: 16.h),
            ),
            child: Text(
              'Back',
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ),
        hSpace(12),
        Expanded(
          child: ElevatedButton(
            onPressed: (_agreedToTerms && !_submitting)
                ? () => _submitDebouncer.run(_submit)
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7434FF),
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade300,
              disabledForegroundColor: Colors.grey.shade600,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
              padding: EdgeInsets.symmetric(vertical: 16.h),
            ),
            child: _submitting
                ? SizedBox(
                    width: 20.w,
                    height: 20.w,
                    child: const CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    'Submit Application',
                    style: TextStyle(
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
