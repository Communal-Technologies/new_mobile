import 'dart:math' as math;
import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_state.dart';
import 'package:communal_mobile/core/utils/system_ui_style.dart';
import 'package:communal_mobile/core/widgets/loader_overlay.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/data/models/loan_scheme.dart';
import 'package:communal_mobile/data/repositories/loan_repository.dart';
import 'package:communal_mobile/injection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Loan-area orange (matches LoanOfferCard / detail header / progress).
const Color _kLoanOrange = Color(0xFFE67E22);

/// Static fallback range / defaults used when the cooperative has no
/// loan schemes configured (e.g. during onboarding). The calculator
/// must still work in that window — the cooperative gets to refine
/// these ranges by adding loan products.
const double _kFallbackMinAmount = 50000;
const double _kFallbackMaxAmount = 2000000;
const int _kFallbackMinDuration = 3;
const int _kFallbackMaxDuration = 36;
const double _kFallbackInterestRate = 12.0;

class LoanCalculatorScreen extends StatefulWidget {
  const LoanCalculatorScreen({super.key});

  @override
  State<LoanCalculatorScreen> createState() => _LoanCalculatorScreenState();
}

class _LoanCalculatorScreenState extends State<LoanCalculatorScreen> {
  final LoanRepository _repo = LoanRepository(getIt());

  /// Cooperative-defined products. When non-empty the calculator's
  /// interest rate, duration, and service charge come from the
  /// selected scheme; when empty we fall back to the static defaults
  /// at the top of the file.
  List<LoanScheme> _schemes = const [];
  LoanScheme? _selectedScheme;
  bool _loadingSchemes = true;
  String? _schemesError;

  // User-controllable inputs.
  double _loanAmount = 500000;
  int _loanDuration = 12;

  // Active calibration values (derived from `_selectedScheme` if set,
  // otherwise the static fallbacks).
  double get _interestRate =>
      _selectedScheme?.rateForDuration(_loanDuration) ??
      _kFallbackInterestRate;
  // Service charge from the backend is a flat fee in *minor units*
  // (kobo for NGN). It's added to the principal-derived interest as
  // a one-off cost — same shape as `LoanApplicationController`'s
  // `interest = principal*rate% + service_charge`.
  double get _serviceChargeMinor => _selectedScheme?.serviceCharge ?? 0;
  // For the calculator we work in major units (₦) to match the
  // amount/duration sliders. `serviceCharge` is divided by 100 for
  // NGN (the only currency we expose ranges for here).
  double get _serviceChargeMajor => _serviceChargeMinor / 100.0;

  double get _minAmount => _kFallbackMinAmount;
  double get _maxAmount => _kFallbackMaxAmount;

  int get _minDuration {
    final scheme = _selectedScheme;
    if (scheme != null && scheme.effectiveMinDuration > 0) {
      return scheme.effectiveMinDuration;
    }
    return _kFallbackMinDuration;
  }

  int get _maxDuration {
    final scheme = _selectedScheme;
    if (scheme != null && scheme.effectiveMaxDuration > 0) {
      return scheme.effectiveMaxDuration;
    }
    return _kFallbackMaxDuration;
  }

  /// The slider only moves on schemes where the cooperative let members
  /// choose their own term; otherwise the term is fixed by the admin.
  bool get _durationLocked {
    final scheme = _selectedScheme;
    if (scheme == null) return false;
    return !scheme.memberCanPickDuration;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadSchemes();
    });
  }

  Future<void> _loadSchemes() async {
    final auth = context.read<AuthBloc>().state;
    final coopId = auth is AuthAuthenticated
        ? (auth.user.cooperativeId?.trim() ?? '')
        : '';
    if (coopId.isEmpty) {
      // No cooperative context; the calculator still works on
      // fallback values, so don't surface an error.
      if (!mounted) return;
      setState(() {
        _loadingSchemes = false;
        _schemes = const [];
        _selectedScheme = null;
      });
      return;
    }

    try {
      final rows = await _repo.fetchSchemes(coopId);
      if (!mounted) return;
      setState(() {
        _schemes = rows;
        if (rows.isNotEmpty) {
          _selectedScheme = rows.first;
          final picked = rows.first.memberCanPickDuration
              ? rows.first.effectiveMinDuration
              : rows.first.effectiveMaxDuration;
          if (picked > 0) {
            _loanDuration = picked;
          }
        } else {
          _selectedScheme = null;
        }
        _loadingSchemes = false;
        _schemesError = null;
      });
    } catch (e) {
      if (!mounted) return;
      // Calculator stays usable on fallback. Surface the error in a
      // small inline note — don't block the screen.
      setState(() {
        _loadingSchemes = false;
        _schemesError = e
            .toString()
            .replaceFirst(RegExp(r'^Exception:\s*'), '')
            .trim();
      });
    }
  }

  /// Standard amortizing-loan monthly payment for `_loanAmount` at
  /// the active interest rate over `_loanDuration` months. Service
  /// charge is treated as an up-front flat addition to total cost
  /// (mirrors backend math), not amortized into the monthly figure.
  double get _monthlyPayment {
    if (_loanDuration == 0) return 0;
    final monthlyRate = _interestRate / 100 / 12;
    if (monthlyRate == 0) return _loanAmount / _loanDuration;
    final numerator =
        _loanAmount * monthlyRate * math.pow(1 + monthlyRate, _loanDuration);
    final denominator = math.pow(1 + monthlyRate, _loanDuration) - 1;
    return numerator / denominator;
  }

  double get _totalRepayment =>
      _monthlyPayment * _loanDuration + _serviceChargeMajor;
  double get _totalInterest => _totalRepayment - _loanAmount;
  int get _numberOfInstallments => _loanDuration;

  DateTime get _firstPaymentDate => DateTime.now().add(const Duration(days: 7));
  DateTime get _finalPaymentDate {
    final firstDate = _firstPaymentDate;
    return DateTime(
      firstDate.year,
      firstDate.month + _loanDuration,
      firstDate.day,
    );
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat('#,##0', 'en_NG');
    return '₦${formatter.format(amount.round())}';
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemOverlayForTheme(Theme.of(context)),
      child: Scaffold(
        backgroundColor: Theme.of(context).cardColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).cardColor,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          title: Text(
            'Loan Calculator',
            style: TextStyle(
              fontSize: 19.sp,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          centerTitle: true,
        ),
        body: _loadingSchemes
            ? const LoaderOverlay()
            : SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoBox(),
                    if (_schemes.isNotEmpty) ...[
                      vSpace(20),
                      _buildSchemePicker(),
                    ] else if (_schemesError != null) ...[
                      vSpace(12),
                      _buildSchemesErrorNote(),
                    ] else ...[
                      vSpace(12),
                      _buildFallbackNote(),
                    ],
                    vSpace(24),
                    _buildLoanAmountSection(),
                    vSpace(24),
                    _buildQuickAmountsSection(),
                    vSpace(24),
                    _buildLoanDurationSection(),
                    vSpace(24),
                    _buildInterestRateSection(),
                    if (_serviceChargeMajor > 0) ...[
                      vSpace(12),
                      _buildServiceChargeRow(),
                    ],
                    vSpace(24),
                    _buildRepaymentSummaryCard(),
                    vSpace(24),
                    _buildPaymentBreakdownSection(),
                    vSpace(24),
                    _buildProceedButton(),
                    vSpace(16),
                    _buildNoteSection(),
                    vSpace(32),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildInfoBox() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const accent = Color(0xFF1976D2);
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDark
            ? accent.withValues(alpha: 0.16)
            : const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: const Color(0xFF1976D2), size: 24.sp),
          hSpace(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Calculate Your Loan',
                  style: TextStyle(
                    fontSize: 19.sp,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                vSpace(4),
                Text(
                  _schemes.isNotEmpty
                      ? 'Pick one of your cooperative\'s loan products and adjust the amount to see your estimated repayment.'
                      : 'Adjust the loan amount and duration to see your estimated monthly payments and total repayment.',
                  style: TextStyle(
                    fontSize: 17.sp,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSchemePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Loan Product',
          style: TextStyle(
            fontSize: 19.sp,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        vSpace(10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final scheme in _schemes) ...[
                _SchemeChip(
                  scheme: scheme,
                  selected: _selectedScheme?.loanCode == scheme.loanCode,
                  onTap: () {
                    setState(() {
                      _selectedScheme = scheme;
                      final picked = scheme.memberCanPickDuration
                          ? scheme.effectiveMinDuration
                          : scheme.effectiveMaxDuration;
                      if (picked > 0) {
                        _loanDuration = picked;
                      }
                    });
                  },
                ),
                hSpace(10),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFallbackNote() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: isDark
            ? _kLoanOrange.withValues(alpha: 0.12)
            : const Color(0xFFFFF4E9),
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: _kLoanOrange, size: 18.sp),
          hSpace(8),
          Expanded(
            child: Text(
              'Your cooperative hasn\'t configured loan products yet. '
              'These are sample ranges — your actual rate and limits '
              'will come from your cooperative.',
              style: TextStyle(
                fontSize: 16.sp,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.75),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSchemesErrorNote() {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: const Color(0xFFFDECEA),
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: const Color(0xFFE74C3C),
            size: 18.sp,
          ),
          hSpace(8),
          Expanded(
            child: Text(
              'Could not load loan products. Showing sample ranges. '
              '${_schemesError ?? ''}',
              style: TextStyle(fontSize: 16.sp, color: const Color(0xFFE74C3C)),
            ),
          ),
          TextButton(onPressed: _loadSchemes, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildLoanAmountSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Loan Amount',
          style: TextStyle(
            fontSize: 19.sp,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        vSpace(12),
        Row(
          children: [
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: _kLoanOrange,
                  inactiveTrackColor: Theme.of(context).dividerColor,
                  thumbColor: Theme.of(context).colorScheme.surface,
                  thumbShape: RoundSliderThumbShape(enabledThumbRadius: 10.r),
                  overlayShape: RoundSliderOverlayShape(overlayRadius: 20.r),
                  trackHeight: 4.h,
                ),
                child: Slider(
                  value: _loanAmount.clamp(_minAmount, _maxAmount),
                  min: _minAmount,
                  max: _maxAmount,
                  divisions: ((_maxAmount - _minAmount) / 50000).round(),
                  onChanged: (value) {
                    setState(() {
                      _loanAmount = value;
                    });
                  },
                ),
              ),
            ),
            hSpace(16),
            Text(
              _formatCurrency(_loanAmount),
              style: TextStyle(
                fontSize: 19.sp,
                fontWeight: FontWeight.w700,
                color: _kLoanOrange,
              ),
            ),
          ],
        ),
        vSpace(8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _formatCurrency(_minAmount),
              style: TextStyle(
                fontSize: 16.sp,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            Text(
              _formatCurrency(_maxAmount),
              style: TextStyle(
                fontSize: 16.sp,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLoanDurationSection() {
    final locked = _durationLocked;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Loan Duration',
              style: TextStyle(
                fontSize: 19.sp,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            if (locked) ...[
              hSpace(8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: _kLoanOrange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  'Set by product',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: _kLoanOrange,
                  ),
                ),
              ),
            ] else if (_selectedScheme != null) ...[
              hSpace(8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: _kLoanOrange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  '${_selectedScheme!.effectiveMinDuration}–${_selectedScheme!.effectiveMaxDuration} months',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: _kLoanOrange,
                  ),
                ),
              ),
            ],
          ],
        ),
        vSpace(12),
        Row(
          children: [
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: _kLoanOrange,
                  inactiveTrackColor: Theme.of(context).dividerColor,
                  thumbColor: Theme.of(context).colorScheme.surface,
                  thumbShape: RoundSliderThumbShape(enabledThumbRadius: 10.r),
                  overlayShape: RoundSliderOverlayShape(overlayRadius: 20.r),
                  trackHeight: 4.h,
                ),
                child: Slider(
                  value: _loanDuration.toDouble().clamp(
                    _minDuration.toDouble(),
                    _maxDuration.toDouble(),
                  ),
                  min: _minDuration.toDouble(),
                  max: _maxDuration.toDouble(),
                  divisions: math.max(1, _maxDuration - _minDuration),
                  onChanged: locked
                      ? null
                      : (value) {
                          setState(() {
                            _loanDuration = value.round();
                          });
                        },
                ),
              ),
            ),
            hSpace(16),
            Text(
              '$_loanDuration months',
              style: TextStyle(
                fontSize: 19.sp,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
        vSpace(8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$_minDuration months',
              style: TextStyle(
                fontSize: 16.sp,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            Text(
              '$_maxDuration months',
              style: TextStyle(
                fontSize: 16.sp,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInterestRateSection() {
    final scheme = _selectedScheme;
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Theme.of(context).dividerColor,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: [
          Icon(Icons.trending_up, color: _kLoanOrange, size: 24.sp),
          hSpace(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Interest Rate',
                  style: TextStyle(
                    fontSize: 17.sp,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                vSpace(4),
                Text(
                  _formatRate(_interestRate),
                  style: TextStyle(
                    fontSize: 19.sp,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                vSpace(4),
                Text(
                  scheme != null
                      ? 'From "${scheme.title.isNotEmpty ? scheme.title : scheme.loanCode}"'
                      : 'Sample rate — your cooperative\'s actual rate may differ',
                  style: TextStyle(
                    fontSize: 16.sp,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceChargeRow() {
    return Row(
      children: [
        Icon(
          Icons.receipt_long_outlined,
          size: 18.sp,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
        ),
        hSpace(8),
        Expanded(
          child: Text(
            'Service charge: ${_formatCurrency(_serviceChargeMajor)} (one-off, added to total)',
            style: TextStyle(
              fontSize: 16.sp,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.75),
            ),
          ),
        ),
      ],
    );
  }

  String _formatRate(double rate) {
    final isWhole = rate.truncateToDouble() == rate;
    return '${rate.toStringAsFixed(isWhole ? 0 : 2)}% per annum';
  }

  Widget _buildRepaymentSummaryCard() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: _kLoanOrange,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calculate_outlined, color: Colors.white, size: 24.sp),
              hSpace(8),
              Text(
                'Repayment Summary',
                style: TextStyle(
                  fontSize: 19.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          vSpace(20),
          Text(
            _formatCurrency(_monthlyPayment),
            style: TextStyle(
              fontSize: 32.sp,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          vSpace(4),
          Text(
            'in $_numberOfInstallments installments',
            style: TextStyle(
              fontSize: 17.sp,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          vSpace(20),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.3)),
          vSpace(16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Repayment',
                      style: TextStyle(
                        fontSize: 17.sp,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    vSpace(4),
                    Text(
                      _formatCurrency(_totalRepayment),
                      style: TextStyle(
                        fontSize: 19.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
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
                      'Total Interest',
                      style: TextStyle(
                        fontSize: 17.sp,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    vSpace(4),
                    Text(
                      _formatCurrency(_totalInterest),
                      style: TextStyle(
                        fontSize: 19.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentBreakdownSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Payment Breakdown',
          style: TextStyle(
            fontSize: 19.sp,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        vSpace(16),
        _buildBreakdownRow(
          'Number of Payments',
          '$_numberOfInstallments months',
        ),
        vSpace(12),
        _buildBreakdownRow('Payment Frequency', 'Monthly'),
        vSpace(12),
        _buildBreakdownRow(
          'First Payment Date',
          DateFormat('MMM dd, yyyy').format(_firstPaymentDate),
        ),
        vSpace(12),
        _buildBreakdownRow(
          'Final Payment Date',
          DateFormat('MMM dd, yyyy').format(_finalPaymentDate),
        ),
      ],
    );
  }

  Widget _buildBreakdownRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 17.sp,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 17.sp,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickAmountsSection() {
    final amounts = [
      100000,
      250000,
      500000,
      750000,
      1000000,
      1500000,
    ].where((a) => a >= _minAmount && a <= _maxAmount).toList();
    if (amounts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Amounts',
          style: TextStyle(
            fontSize: 19.sp,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        vSpace(12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 2.2,
            crossAxisSpacing: 10.w,
            mainAxisSpacing: 10.h,
          ),
          itemCount: amounts.length,
          itemBuilder: (context, index) {
            final amount = amounts[index];
            final isSelected = (_loanAmount - amount).abs() < 1000;
            return InkWell(
              onTap: () {
                setState(() {
                  _loanAmount = amount.toDouble();
                });
              },
              borderRadius: BorderRadius.circular(12.r),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? _kLoanOrange
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: isSelected
                        ? _kLoanOrange
                        : Theme.of(context).dividerColor,
                  ),
                ),
                child: Center(
                  child: Text(
                    _formatCurrency(amount.toDouble()),
                    style: TextStyle(
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildProceedButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          context.pushNamed(
            'loan-application',
            extra: {
              'amount': _loanAmount,
              'duration': _loanDuration,
              if (_selectedScheme != null) 'scheme': _selectedScheme,
            },
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: _kLoanOrange,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: EdgeInsets.symmetric(vertical: 16.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Proceed to Application',
              style: TextStyle(fontSize: 19.sp, fontWeight: FontWeight.w700),
            ),
            hSpace(8),
            const Icon(Icons.arrow_forward, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildNoteSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const accent = Color(0xFFE6B800);
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDark
            ? accent.withValues(alpha: 0.16)
            : const Color(0xFFFFF9E6),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Note:',
            style: TextStyle(
              fontSize: 17.sp,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          vSpace(8),
          Text(
            'This is an estimated calculation. Final loan terms will be determined by your cooperative and may vary based on your eligibility score and membership history.',
            style: TextStyle(
              fontSize: 16.sp,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.7),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _SchemeChip extends StatelessWidget {
  const _SchemeChip({
    required this.scheme,
    required this.selected,
    required this.onTap,
  });

  final LoanScheme scheme;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: selected
              ? _kLoanOrange
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: selected ? _kLoanOrange : theme.dividerColor,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              scheme.title.isNotEmpty ? scheme.title : scheme.loanCode,
              style: TextStyle(
                fontSize: 17.sp,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : theme.colorScheme.onSurface,
              ),
            ),
            vSpace(2),
            Text(
              '${scheme.interestRateLabel} • ${scheme.durationLabel}',
              style: TextStyle(
                fontSize: 15.sp,
                color: selected
                    ? Colors.white.withValues(alpha: 0.9)
                    : theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
