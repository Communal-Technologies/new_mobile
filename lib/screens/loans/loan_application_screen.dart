import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_state.dart';
import 'package:communal_mobile/core/utils/app_currency.dart';
import 'package:communal_mobile/core/utils/money.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/data/models/loan_scheme.dart';
import 'package:communal_mobile/data/repositories/loan_repository.dart';
import 'package:communal_mobile/injection.dart';
import 'package:communal_mobile/screens/loans/data/loan_application_draft.dart';

/// Step 1 of the loan apply flow — pick a scheme, enter amount + reason,
/// choose interest treatment when the scheme leaves it open. Schemes
/// (duration, interest rate, guarantor count) are loaded from the
/// backend; nothing here is hardcoded.
class LoanApplicationScreen extends StatefulWidget {
  const LoanApplicationScreen({
    super.key,
    this.preselectedScheme,
    this.initialAmount,
  });

  /// When the user taps "Apply Now" on a specific scheme card from the
  /// loans hub, the scheme is pre-selected and the picker is hidden.
  final LoanScheme? preselectedScheme;

  /// Optional initial amount in major currency units.
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

  /// `'1'` deduct-now, `'2'` add-to-principal. Default to deduct-now —
  /// matches the most common cooperative behavior. Locked when the
  /// scheme has a fixed `interest_type`.
  String _interestType = '1';

  @override
  void initState() {
    super.initState();
    _selectedScheme = widget.preselectedScheme;
    if (widget.initialAmount != null) {
      _amountController.text = _formatPlain(widget.initialAmount!);
    }
    if (widget.preselectedScheme?.interestType != null &&
        widget.preselectedScheme!.interestType!.isNotEmpty) {
      _interestType = widget.preselectedScheme!.interestType!;
    }
    if (widget.preselectedScheme == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadSchemes());
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadSchemes() async {
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
      final schemes = await _repo.fetchSchemes(coopId);
      if (!mounted) return;
      setState(() {
        _schemes = schemes;
        _selectedScheme ??= schemes.isNotEmpty ? schemes.first : null;
        if (_selectedScheme?.interestType != null &&
            _selectedScheme!.interestType!.isNotEmpty) {
          _interestType = _selectedScheme!.interestType!;
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

  String _formatPlain(double amount) =>
      amount.toStringAsFixed(amount.truncateToDouble() == amount ? 0 : 2);

  double? _parsedAmount() {
    final raw = _amountController.text.replaceAll(RegExp(r'[,\s]'), '').trim();
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }

  String? _validate() {
    if (_selectedScheme == null) return 'Pick a loan product to continue';
    final amount = _parsedAmount();
    if (amount == null || amount <= 0) {
      return 'Enter how much you want to borrow';
    }
    if (_reasonController.text.trim().isEmpty) {
      return 'Tell us why you need this loan';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    final user = auth is AuthAuthenticated ? auth.user : null;
    final currency = user != null ? resolveCurrencyCode(user) : 'NGN';

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
              fontSize: 18.sp,
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
                    _buildAmountSection(currency),
                    vSpace(20),
                    if (_selectedScheme != null) _buildEstimateCard(currency),
                    vSpace(24),
                    if ((_selectedScheme?.interestType?.isEmpty ?? true))
                      _buildInterestTypeSection(),
                    vSpace(24),
                    _buildReasonSection(),
                    if (_error != null) ...[
                      vSpace(16),
                      Text(
                        _error!,
                        style: TextStyle(
                          fontSize: 13.sp,
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
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF7434FF),
              ),
            ),
            Text(
              'Step 1 of 3',
              style: TextStyle(
                fontSize: 14.sp,
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
                fontSize: 14.sp,
                color: const Color(0xFF0F1D40),
              ),
            ),
            vSpace(4),
            Text(
              'Ask your cooperative admin to publish one.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.sp,
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
            fontSize: 14.sp,
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
              onChanged: (s) {
                setState(() {
                  _selectedScheme = s;
                  if (s?.interestType != null &&
                      s!.interestType!.isNotEmpty) {
                    _interestType = s.interestType!;
                  }
                });
              },
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
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F1D40),
            ),
          ),
          vSpace(8),
          Wrap(
            spacing: 12.w,
            runSpacing: 6.h,
            children: [
              _miniStat('${scheme.durationMonths} months'),
              _miniStat('${scheme.interestRateLabel} interest'),
              _miniStat('${scheme.numberOfGuarantors} guarantors'),
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
          fontSize: 12.sp,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF0F1D40),
        ),
      ),
    );
  }

  Widget _buildAmountSection(String currency) {
    final symbol = currencySymbolForCode(currency);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How much do you need?',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F1D40),
          ),
        ),
        vSpace(12),
        TextField(
          controller: _amountController,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
          ],
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24.sp,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF7434FF),
          ),
          decoration: InputDecoration(
            prefixText: '$symbol ',
            prefixStyle: TextStyle(
              fontSize: 24.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF7434FF),
            ),
            hintText: '0',
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
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  Widget _buildEstimateCard(String currency) {
    final amount = _parsedAmount();
    if (amount == null || amount <= 0) {
      return const SizedBox.shrink();
    }
    final scheme = _selectedScheme!;
    final principalMinor = (amount * factorFor(currency)).round();
    final monthlyMinor = estimatedMonthlyRepaymentMinor(
      principalMinor: principalMinor,
      scheme: scheme,
      interestType: _interestType,
      currency: currency,
    );
    final interestMinor =
        (principalMinor * scheme.interestRate / 100).round();
    final totalMinor = _interestType == '1'
        ? principalMinor
        : principalMinor + interestMinor;
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Estimated Repayment',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F1D40),
            ),
          ),
          vSpace(12),
          Row(
            children: [
              Expanded(
                child: _estimateColumn(
                  'Monthly',
                  Money(monthlyMinor, currency).format(),
                  highlight: true,
                ),
              ),
              Expanded(
                child: _estimateColumn(
                  'Total',
                  Money(totalMinor, currency).format(),
                ),
              ),
              Expanded(
                child: _estimateColumn(
                  'Interest',
                  Money(interestMinor, currency).format(),
                ),
              ),
            ],
          ),
          vSpace(8),
          Text(
            'Over ${scheme.durationMonths} month${scheme.durationMonths == 1 ? '' : 's'} at ${scheme.interestRateLabel}',
            style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _estimateColumn(String label, String value,
      {bool highlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600)),
        vSpace(4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w700,
            color: highlight
                ? const Color(0xFF7434FF)
                : const Color(0xFF0F1D40),
          ),
        ),
      ],
    );
  }

  Widget _buildInterestTypeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Interest treatment',
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF0F1D40),
          ),
        ),
        vSpace(8),
        Row(
          children: [
            Expanded(
              child: _interestOption(
                value: '1',
                label: 'Deduct now',
                hint: 'Receive principal − interest',
              ),
            ),
            hSpace(8),
            Expanded(
              child: _interestOption(
                value: '2',
                label: 'Add to balance',
                hint: 'Repay principal + interest',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _interestOption({
    required String value,
    required String label,
    required String hint,
  }) {
    final selected = _interestType == value;
    return InkWell(
      borderRadius: BorderRadius.circular(12.r),
      onTap: () => setState(() => _interestType = value),
      child: Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEEE5FF) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color:
                selected ? const Color(0xFF7434FF) : Colors.grey.shade200,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
                color: selected
                    ? const Color(0xFF7434FF)
                    : const Color(0xFF0F1D40),
              ),
            ),
            vSpace(4),
            Text(
              hint,
              style:
                  TextStyle(fontSize: 11.sp, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReasonSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What will you use this loan for?',
          style: TextStyle(
            fontSize: 18.sp,
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
                TextStyle(fontSize: 14.sp, color: Colors.grey.shade400),
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
          style: TextStyle(fontSize: 14.sp, color: const Color(0xFF0F1D40)),
        ),
      ],
    );
  }

  Widget _buildContinueButton(String currency) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          final err = _validate();
          if (err != null) {
            setState(() => _error = err);
            return;
          }
          final draft = LoanApplicationDraft(
            scheme: _selectedScheme!,
            amountMajor: _parsedAmount()!,
            currency: currency,
            interestType: _interestType,
            reasonForLoan: _reasonController.text.trim(),
          );
          context.pushNamed(
            'loan-application-step2',
            extra: {'draft': draft},
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF7434FF),
          foregroundColor: Colors.white,
          elevation: 0,
          padding: EdgeInsets.symmetric(vertical: 16.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
        ),
        child: Text(
          'Continue',
          style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
