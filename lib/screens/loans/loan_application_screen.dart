import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_state.dart';
import 'package:communal_mobile/core/utils/app_currency.dart';
import 'package:communal_mobile/core/utils/money.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/data/models/loan_eligibility.dart';
import 'package:communal_mobile/data/models/loan_scheme.dart';
import 'package:communal_mobile/data/repositories/loan_repository.dart';
import 'package:communal_mobile/injection.dart';
import 'package:communal_mobile/screens/loans/data/loan_application_draft.dart';

/// Step 1 of the apply flow. The slider's min and max bounds, plus the
/// interest treatment that gets stamped on the application, all come
/// from the cooperative — the member is *not* the source of truth for
/// any of these:
///
/// - **Min**: cooperative's `loan_min_amount` setting.
/// - **Max**: sum of the member's holdings across the obligation
///   categories the cooperative configured for loan eligibility
///   (`loan_access_obligations` — typically Equity + Patronage +
///   Custom). Computed server-side.
/// - **Interest treatment**: locked to the cooperative's enabled +
///   default interest type. Shown read-only.
class LoanApplicationScreen extends StatefulWidget {
  const LoanApplicationScreen({
    super.key,
    this.preselectedScheme,
    this.initialAmount,
  });

  final LoanScheme? preselectedScheme;
  final double? initialAmount;

  @override
  State<LoanApplicationScreen> createState() => _LoanApplicationScreenState();
}

class _LoanApplicationScreenState extends State<LoanApplicationScreen> {
  final LoanRepository _repo = LoanRepository(getIt());
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();

  bool _loading = false;
  String? _error;
  List<LoanScheme> _schemes = const [];
  LoanScheme? _selectedScheme;
  LoanEligibility? _eligibility;

  double _loanAmount = 0;

  @override
  void initState() {
    super.initState();
    _selectedScheme = widget.preselectedScheme;
    if (widget.initialAmount != null) {
      _loanAmount = widget.initialAmount!;
      _amountController.text = _formatNoDecimals(_loanAmount);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAll());
  }

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) return;
    final coopId = auth.user.cooperativeId?.trim();
    if (coopId == null || coopId.isEmpty) {
      setState(() => _error = 'Cooperative not linked to your profile');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Schemes only when no scheme was preselected from the loans hub.
      // Eligibility is always needed — drives slider bounds + interest
      // treatment.
      final results = await Future.wait([
        if (widget.preselectedScheme == null)
          _repo.fetchSchemes(coopId)
        else
          Future.value(<LoanScheme>[]),
        _repo.fetchEligibility(coopId),
      ]);
      if (!mounted) return;
      final schemes = results[0] as List<LoanScheme>;
      final eligibility = results[1] as LoanEligibility?;
      setState(() {
        _schemes = schemes;
        _eligibility = eligibility;
        _selectedScheme ??= schemes.isNotEmpty ? schemes.first : null;
        // Pin amount to a sensible value within the eligibility band.
        if (eligibility != null) {
          final min = eligibility.minAmountMinor / factorFor(eligibility.currency);
          final max = eligibility.maxAmountMinor / factorFor(eligibility.currency);
          if (_loanAmount <= 0 || _loanAmount < min || _loanAmount > max) {
            // Default to the midpoint when nothing was carried in;
            // clamp into range when something was.
            if (_loanAmount <= 0) {
              _loanAmount = max <= min ? min : (min + max) / 2;
            } else {
              _loanAmount = _loanAmount.clamp(min, max).toDouble();
            }
            _amountController.text = _formatNoDecimals(_loanAmount);
          }
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  String _formatNoDecimals(double amount) =>
      NumberFormat('#,##0', 'en_NG').format(amount.round());

  double get _minAmount {
    final el = _eligibility;
    if (el == null) return 0;
    return el.minAmountMinor / factorFor(el.currency);
  }

  double get _maxAmount {
    final el = _eligibility;
    if (el == null) return 0;
    return el.maxAmountMinor / factorFor(el.currency);
  }

  bool get _hasEligibility => _eligibility != null && _maxAmount > _minAmount;

  void _setAmount(double value) {
    if (!_hasEligibility) return;
    final clamped =
        value.clamp(_minAmount, _maxAmount).toDouble();
    setState(() => _loanAmount = clamped);
    _amountController.value = TextEditingValue(
      text: _formatNoDecimals(clamped),
      selection: TextSelection.collapsed(
        offset: _formatNoDecimals(clamped).length,
      ),
    );
  }

  String? _validate() {
    if (_selectedScheme == null) return 'Pick a loan product to continue';
    if (_eligibility == null) return 'Loan limits not loaded yet';
    if (_loanAmount < _minAmount) {
      return 'Minimum loan amount is ${_eligibility!.minLabel}';
    }
    if (_loanAmount > _maxAmount) {
      return 'You can borrow at most ${_eligibility!.maxLabel} based on your holdings';
    }
    if (_reasonController.text.trim().isEmpty) {
      return 'Tell us why you need this loan';
    }
    if (_eligibility!.defaultInterestType == null) {
      return 'Your cooperative has not configured loan interest treatments yet';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    final user = auth is AuthAuthenticated ? auth.user : null;
    // Prefer the cooperative's currency (from eligibility) over the
    // member's wallet currency — money limits are coop-side decisions.
    final currency = _eligibility?.currency ??
        (user != null ? resolveCurrencyCode(user) : 'NGN');
    final symbol = currencySymbolForCode(currency);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => context.pop(),
          ),
          title: Text(
            'Loan Application',
            style: TextStyle(
              fontSize: 19.sp,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          centerTitle: true,
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding:
                    EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildProgressIndicator(),
                    vSpace(24),
                    if (widget.preselectedScheme == null)
                      _buildSchemePicker()
                    else
                      _buildSchemeSummary(_selectedScheme!),
                    vSpace(24),
                    _buildLoanAmountSection(symbol, currency),
                    vSpace(24),
                    if (_selectedScheme != null && _hasEligibility)
                      _buildRepaymentSummarySection(currency),
                    vSpace(24),
                    _buildInterestTypeReadOnly(),
                    vSpace(24),
                    _buildReasonSection(),
                    if (_error != null) ...[
                      vSpace(16),
                      Text(
                        _error!,
                        style: TextStyle(
                          fontSize: 15.sp,
                          color: const Color(0xFFE74C3C),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(child: _buildContinueButton(currency)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Loan Details',
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF7434FF),
              ),
            ),
            Text(
              'Step 1 of 3',
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF7434FF),
              ),
            ),
          ],
        ),
        vSpace(8),
        Stack(
          children: [
            Container(
              height: 4.h,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            FractionallySizedBox(
              widthFactor: 1 / 3,
              child: Container(
                height: 4.h,
                decoration: BoxDecoration(
                  color: const Color(0xFF7434FF),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSchemePicker() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_schemes.isEmpty) {
      return Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(Icons.info_outline,
                size: 24.sp, color: Colors.grey.shade500),
            vSpace(8),
            Text(
              'No loan products available right now',
              style: TextStyle(
                fontSize: 15.sp,
                color: const Color(0xFF0F1D40),
              ),
            ),
            vSpace(4),
            Text(
              'Ask your cooperative admin to publish one.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.sp,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Loan Product',
          style: TextStyle(
            fontSize: 15.sp,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF0F1D40),
          ),
        ),
        vSpace(8),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<LoanScheme>(
              isExpanded: true,
              value: _selectedScheme,
              items: _schemes
                  .map(
                    (s) => DropdownMenuItem<LoanScheme>(
                      value: s,
                      child: Text(
                        s.title.isNotEmpty
                            ? '${s.title} • ${s.durationLabel} @ ${s.interestRateLabel}'
                            : s.loanCode,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (s) => setState(() => _selectedScheme = s),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSchemeSummary(LoanScheme scheme) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E9),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            scheme.title.isNotEmpty ? scheme.title : scheme.loanCode,
            style: TextStyle(
              fontSize: 17.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F1D40),
            ),
          ),
          vSpace(8),
          Wrap(
            spacing: 12.w,
            runSpacing: 6.h,
            children: [
              _miniStat(scheme.durationLabel),
              _miniStat('${scheme.interestRateLabel} interest'),
              _miniStat(
                '${scheme.numberOfGuarantors} guarantor${scheme.numberOfGuarantors == 1 ? '' : 's'}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13.sp,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF0F1D40),
        ),
      ),
    );
  }

  Widget _buildLoanAmountSection(String symbol, String currency) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How much do you need?',
          style: TextStyle(
            fontSize: 19.sp,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F1D40),
          ),
        ),
        vSpace(20),
        if (!_hasEligibility)
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Text(
              _loading
                  ? 'Loading your eligibility…'
                  : (_eligibility != null && _maxAmount <= _minAmount
                      ? 'You don\'t qualify for a loan yet — your EPC holdings are below your cooperative\'s minimum loan amount.'
                      : 'Loan limits unavailable. Pull to refresh.'),
              style: TextStyle(
                fontSize: 15.sp,
                color: Colors.grey.shade700,
              ),
            ),
          )
        else ...[
          Row(
            children: [
              Text(
                '$symbol${_formatNoDecimals(_minAmount)}',
                style:
                    TextStyle(fontSize: 15.sp, color: Colors.grey.shade600),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: const Color(0xFF7434FF),
                    inactiveTrackColor: Colors.grey.shade300,
                    thumbColor: const Color(0xFF7434FF),
                    thumbShape:
                        RoundSliderThumbShape(enabledThumbRadius: 12.r),
                    overlayShape:
                        RoundSliderOverlayShape(overlayRadius: 24.r),
                    trackHeight: 4.h,
                  ),
                  child: Slider(
                    value: _loanAmount.clamp(_minAmount, _maxAmount).toDouble(),
                    min: _minAmount,
                    max: _maxAmount,
                    onChanged: _setAmount,
                  ),
                ),
              ),
              Text(
                '$symbol${_formatNoDecimals(_maxAmount)}',
                style:
                    TextStyle(fontSize: 15.sp, color: Colors.grey.shade600),
              ),
            ],
          ),
          vSpace(16),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF7434FF),
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d,]')),
            ],
            decoration: InputDecoration(
              prefixText: '$symbol ',
              prefixStyle: TextStyle(
                fontSize: 24.sp,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF7434FF),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide:
                    const BorderSide(color: Color(0xFF7434FF), width: 2),
              ),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
            ),
            onChanged: (value) {
              final numeric = value.replaceAll(RegExp(r'[^\d]'), '');
              if (numeric.isEmpty) {
                setState(() => _loanAmount = _minAmount);
                return;
              }
              final parsed = double.tryParse(numeric);
              if (parsed == null) return;
              final clamped =
                  parsed.clamp(_minAmount, _maxAmount).toDouble();
              setState(() => _loanAmount = clamped);
              if (clamped != parsed) {
                final formatted = _formatNoDecimals(clamped);
                _amountController.value = TextEditingValue(
                  text: formatted,
                  selection:
                      TextSelection.collapsed(offset: formatted.length),
                );
              }
            },
          ),
          vSpace(8),
          Text(
            'Minimum: $symbol${_formatNoDecimals(_minAmount)} | Maximum: $symbol${_formatNoDecimals(_maxAmount)}',
            style:
                TextStyle(fontSize: 13.sp, color: Colors.grey.shade600),
          ),
          vSpace(4),
          Text(
            _eligibility?.maxExplanation ??
                'Your maximum is the sum of your EPC holdings with this cooperative.',
            style: TextStyle(
                fontSize: 13.sp, color: Colors.grey.shade500),
          ),
        ],
      ],
    );
  }

  Widget _buildRepaymentSummarySection(String currency) {
    final scheme = _selectedScheme!;
    final interestType =
        _eligibility?.defaultInterestType?.value ?? '1';
    final principalMinor =
        (_loanAmount * factorFor(currency)).round();
    final interestMinor =
        (principalMinor * scheme.interestRate / 100).round();
    final monthlyMinor = estimatedMonthlyRepaymentMinor(
      principalMinor: principalMinor,
      scheme: scheme,
      interestType: interestType,
      currency: currency,
    );
    final totalMinor = interestType == '1'
        ? principalMinor
        : principalMinor + interestMinor;

    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Repayment Summary',
            style: TextStyle(
              fontSize: 17.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F1D40),
            ),
          ),
          vSpace(20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Money(monthlyMinor, currency).format(),
                      style: TextStyle(
                        fontSize: 22.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF7434FF),
                      ),
                    ),
                    vSpace(4),
                    Text(
                      'monthly in ${scheme.durationMonths} installment${scheme.durationMonths == 1 ? '' : 's'}',
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      Money(totalMinor, currency).format(),
                      style: TextStyle(
                        fontSize: 22.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF7434FF),
                      ),
                    ),
                    vSpace(4),
                    Text(
                      'Total Repayment',
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          vSpace(16),
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Interest',
                  style: TextStyle(
                    fontSize: 15.sp,
                    color: Colors.grey.shade700,
                  ),
                ),
                Text(
                  Money(interestMinor, currency).format(),
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0F1D40),
                  ),
                ),
              ],
            ),
          ),
          vSpace(12),
          Text(
            'At ${scheme.interestRateLabel} interest rate',
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFE67E22),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInterestTypeReadOnly() {
    final defaultType = _eligibility?.defaultInterestType;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Interest treatment',
          style: TextStyle(
            fontSize: 15.sp,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF0F1D40),
          ),
        ),
        vSpace(8),
        Container(
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: const Color(0xFFEEE5FF),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: const Color(0xFF7434FF), width: 1.5),
          ),
          child: Row(
            children: [
              Icon(Icons.lock_outline,
                  size: 18.sp, color: const Color(0xFF7434FF)),
              hSpace(10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      defaultType?.title.isNotEmpty == true
                          ? defaultType!.title
                          : (_loading
                              ? 'Loading…'
                              : 'Not configured'),
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF7434FF),
                      ),
                    ),
                    vSpace(4),
                    Text(
                      defaultType?.note.isNotEmpty == true
                          ? defaultType!.note
                          : 'Set by your cooperative — not member-selectable.',
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
        ),
      ],
    );
  }

  Widget _buildReasonSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What will you use this loan for?',
          style: TextStyle(
            fontSize: 19.sp,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F1D40),
          ),
        ),
        vSpace(12),
        TextField(
          controller: _reasonController,
          maxLines: 3,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            hintText: 'e.g., upgrade my business, buy equipment',
            hintStyle:
                TextStyle(fontSize: 15.sp, color: Colors.grey.shade400),
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide:
                  const BorderSide(color: Color(0xFF7434FF), width: 2),
            ),
            contentPadding:
                EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
          ),
          style: TextStyle(fontSize: 15.sp, color: const Color(0xFF0F1D40)),
        ),
      ],
    );
  }

  Widget _buildContinueButton(String currency) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _hasEligibility
            ? () {
                final err = _validate();
                if (err != null) {
                  setState(() => _error = err);
                  return;
                }
                final draft = LoanApplicationDraft(
                  scheme: _selectedScheme!,
                  amountMajor: _loanAmount,
                  currency: currency,
                  interestType:
                      _eligibility!.defaultInterestType!.value,
                  reasonForLoan: _reasonController.text.trim(),
                );
                context.pushNamed(
                  'loan-application-step2',
                  extra: {'draft': draft},
                );
              }
            : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF7434FF),
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
          disabledForegroundColor: Colors.grey.shade600,
          elevation: 0,
          padding: EdgeInsets.symmetric(vertical: 16.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
        ),
        child: Text(
          'Continue',
          style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
