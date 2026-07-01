import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:communal_mobile/core/utils/money.dart';
import 'package:communal_mobile/core/utils/system_ui_style.dart';
import 'package:communal_mobile/core/widgets/app_toast.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/data/models/guarantor_request.dart';
import 'package:communal_mobile/data/repositories/loan_repository.dart';
import 'package:communal_mobile/injection.dart';

/// Full review surface a guarantor sees before they accept or decline
/// the invitation. The inbox card on the previous screen routes here
/// rather than acting inline so the member sees the full loan picture
/// + the risk disclosure before committing.
///
/// "Accept" is gated behind an acknowledgement checkbox. The literal
/// "if X defaults, you and the other guarantors are jointly liable
/// for the outstanding balance" text isn't a flourish — it's the
/// disclosure the user explicitly asked for.
class GuarantorRequestDetailScreen extends StatefulWidget {
  const GuarantorRequestDetailScreen({super.key, required this.request});

  final GuarantorRequest request;

  @override
  State<GuarantorRequestDetailScreen> createState() =>
      _GuarantorRequestDetailScreenState();
}

class _GuarantorRequestDetailScreenState
    extends State<GuarantorRequestDetailScreen> {
  final LoanRepository _repo = LoanRepository(getIt());
  bool _acknowledged = false;
  bool _processing = false;

  Future<void> _respond(bool accept) async {
    if (_processing) return;
    if (accept && !_acknowledged) return;
    setState(() => _processing = true);
    try {
      await _repo.respondToGuarantorRequest(
        loanRef: widget.request.loanRef,
        guarantorLedger: widget.request.guarantorLedger,
        accept: accept,
      );
      if (!mounted) return;
      AppToast.success(accept ? 'Request accepted' : 'Request declined');
      // Pop back to the inbox; that screen refreshes its own list on
      // resume so the row picks up the new status.
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      AppToast.error(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    String money(num? value) => value == null
        ? '—'
        : Money(_asMinor(value), r.currency).format();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemOverlayForTheme(Theme.of(context)),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          title: Text(
            'Guarantor Request',
            style: TextStyle(
              fontSize: 19.sp,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 16.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _applicantHeader(r),
                      vSpace(20),
                      _section('Loan details', [
                        _kv('Amount requested', r.amountLabel, emphasised: true),
                        if (r.schemeTitle != null && r.schemeTitle!.isNotEmpty)
                          _kv('Loan product', r.schemeTitle!),
                        if (r.schemeDurationMonths != null)
                          _kv('Duration',
                              '${r.schemeDurationMonths} month${r.schemeDurationMonths == 1 ? '' : 's'}'),
                        if (r.schemeInterestRate != null)
                          _kv('Interest rate',
                              '${r.schemeInterestRate!.toStringAsFixed(r.schemeInterestRate! % 1 == 0 ? 0 : 2)}%'),
                        if (r.monthlyRepayment != null)
                          _kv('Monthly repayment', money(r.monthlyRepayment)),
                        if (r.interestType != null && r.interestType!.isNotEmpty)
                          _kv(
                            'Interest treatment',
                            r.interestType == '1'
                                ? 'Deducted on disbursal'
                                : 'Added to balance',
                          ),
                      ]),
                      if (r.reasonForLoan != null && r.reasonForLoan!.trim().isNotEmpty) ...[
                        vSpace(16),
                        _section('Reason for loan', [
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 6.h),
                            child: Text(
                              r.reasonForLoan!,
                              style: TextStyle(
                                fontSize: 17.sp,
                                color: Theme.of(context).colorScheme.onSurface,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ]),
                      ],
                      vSpace(16),
                      _riskDisclosure(r),
                      if (r.isPending) ...[
                        vSpace(16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Checkbox(
                              value: _acknowledged,
                              onChanged: !_processing
                                  ? (v) => setState(() => _acknowledged = v ?? false)
                                  : null,
                              activeColor: const Color(0xFF7434FF),
                            ),
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(top: 12.h),
                                child: Text(
                                  'I understand the obligations of standing as a guarantor and agree to the joint liability above.',
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.85),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (r.isPending)
                Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 16.h),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _processing ? null : () => _respond(false),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFE74C3C)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                            padding: EdgeInsets.symmetric(vertical: 14.h),
                          ),
                          child: Text(
                            'Decline',
                            style: TextStyle(
                              fontSize: 17.sp,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFE74C3C),
                            ),
                          ),
                        ),
                      ),
                      hSpace(12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: (_processing || !_acknowledged)
                              ? null
                              : () => _respond(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7434FF),
                            foregroundColor: Colors.white,
                            // Keep the label legible while disabled: a faded
                            // brand fill with white text instead of grey-on-grey.
                            disabledBackgroundColor:
                                const Color(0xFF7434FF).withValues(alpha: 0.4),
                            disabledForegroundColor:
                                Colors.white.withValues(alpha: 0.9),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                            padding: EdgeInsets.symmetric(vertical: 14.h),
                          ),
                          child: _processing
                              ? SizedBox(
                                  width: 18.w,
                                  height: 18.w,
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  'Accept',
                                  style: TextStyle(
                                    fontSize: 17.sp,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _applicantHeader(GuarantorRequest r) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFFEEE5FF),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24.r,
            backgroundColor: Colors.white,
            child: Icon(Icons.person, color: const Color(0xFF7434FF), size: 26.sp),
          ),
          hSpace(14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.applicantName.isNotEmpty ? r.applicantName : 'Member',
                  style: TextStyle(
                    fontSize: 19.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A1A1A),
                  ),
                ),
                vSpace(2),
                Text(
                  'Asked to guarantee • ${DateFormat('MMM dd, yyyy').format(r.createdAt)}',
                  style: TextStyle(
                    fontSize: 16.sp,
                    color: const Color(0xFF1A1A1A).withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Container(
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
            title,
            style: TextStyle(
              fontSize: 17.sp,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          vSpace(8),
          ...children,
        ],
      ),
    );
  }

  Widget _kv(String label, String value, {bool emphasised = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 16.sp,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: emphasised ? 19.sp : 17.sp,
              fontWeight: emphasised ? FontWeight.w800 : FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _riskDisclosure(GuarantorRequest r) {
    final applicant = r.applicantName.isNotEmpty ? r.applicantName : 'the applicant';
    final coCount = r.coGuarantorsRemaining;
    // "with N other guarantors" / "as the only guarantor" depending on
    // what the loan currently has alongside this invitee.
    final companions = coCount == null
        ? 'and any other guarantors'
        : (coCount == 0
            ? 'as the only guarantor'
            : 'along with $coCount other guarantor${coCount == 1 ? '' : 's'}');
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        // Pinned light red background — this is a hazard notice, the
        // colour signal needs to land in both light and dark mode.
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE74C3C).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: const Color(0xFFE74C3C), size: 20.sp),
              hSpace(8),
              Text(
                r.isPending
                    ? 'What you\'re agreeing to'
                    : (r.isDeclined ? 'What you declined' : 'What you agreed to'),
                style: TextStyle(
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFB71C1C),
                ),
              ),
            ],
          ),
          vSpace(8),
          Text(
            r.isDeclined
                ? 'You declined this request, so you are not liable for '
                    '$applicant\'s loan. No deductions or recovery apply to you '
                    'for it.'
                : 'If $applicant defaults on this loan, you '
                    '$companions are jointly liable for the outstanding balance. '
                    'Your cooperative may deduct the unpaid amount from your savings, '
                    'restrict your future loans, and pursue recovery against your '
                    'guarantor holdings until the balance is settled.',
            style: TextStyle(
              fontSize: 16.sp,
              height: 1.5,
              color: const Color(0xFF1A1A1A).withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }

  static int _asMinor(num v) {
    if (v is int) return v;
    return v.toInt();
  }
}
