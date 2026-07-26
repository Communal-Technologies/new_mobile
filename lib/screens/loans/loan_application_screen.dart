import 'package:flutter/material.dart';
import 'package:communal_mobile/core/utils/system_ui_style.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_state.dart';
import 'package:communal_mobile/core/utils/app_currency.dart';
import 'package:communal_mobile/core/utils/money.dart';
import 'package:communal_mobile/core/widgets/app_toast.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/core/widgets/subscription_expired_banner.dart';
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
  List<LoanScheme> _schemes = const [];
  LoanScheme? _selectedScheme;
  LoanEligibility? _eligibility;

  /// `'1'` (deduct now) or `'2'` (add to balance). Initialised to the
  /// cooperative's default once eligibility loads. When the cooperative
  /// has multiple treatments enabled the member can change it from the
  /// chooser; otherwise the value just stays on the single enabled
  /// option (read-only card).
  String? _selectedInterestType;

  double _loanAmount = 0;

  /// Member-picked duration within `_selectedScheme.[min..max]`. Snaps
  /// to the scheme's max on selection so the most-conservative
  /// (longest term, lowest monthly) is the visible default; member
  /// can drag down to shorten the term. Null until a scheme is
  /// chosen.
  int? _pickedDuration;

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
      AppToast.error('Cooperative not linked to your profile');
      return;
    }
    setState(() => _loading = true);
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
        // Pre-select the cooperative's default interest treatment;
        // member can flip it later when more than one is enabled.
        // Only set on first load — don't clobber a deliberate change
        // made before a re-fetch.
        _selectedInterestType ??= eligibility?.defaultInterestType?.value;
        // Pin amount to a sensible value within the eligibility band.
        if (eligibility != null) {
          final min =
              eligibility.minAmountMinor / factorFor(eligibility.currency);
          final max =
              eligibility.maxAmountMinor / factorFor(eligibility.currency);
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
      // All loan-application errors (backend + local validation) are
      // surfaced as toasts so the screen stays uncluttered.
      AppToast.error(e.toString().replaceFirst('Exception: ', ''));
      setState(() => _loading = false);
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
    final clamped = value.clamp(_minAmount, _maxAmount).toDouble();
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
    final isSubscriptionActive = user?.isCooperativeSubscriptionActive ?? true;
    // Prefer the cooperative's currency (from eligibility) over the
    // member's wallet currency — money limits are coop-side decisions.
    final currency =
        _eligibility?.currency ??
        (user != null ? resolveCurrencyCode(user) : 'NGN');
    final symbol = currencySymbolForCode(currency);

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
            'Loan Application',
            style: TextStyle(
              fontSize: 19.sp,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          centerTitle: true,
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isSubscriptionActive)
                      SubscriptionExpiredBanner(endDate: user?.subscriptionEndDate),
                    _buildProgressIndicator(),
                    vSpace(24),
                    if (widget.preselectedScheme == null)
                      _buildSchemePicker()
                    else
                      _buildSchemeSummary(_selectedScheme!),
                    vSpace(24),
                    _buildLoanAmountSection(symbol, currency),
                    vSpace(24),
                    // Interest treatment first — the member's pick (or
                    // the cooperative's default) drives the math
                    // rendered below it.
                    _buildInterestTypeSection(),
                    if (_selectedScheme != null &&
                        _selectedScheme!.memberCanPickDuration) ...[
                      vSpace(24),
                      _buildDurationSection(),
                    ],
                    vSpace(24),
                    if (_selectedScheme != null && _hasEligibility)
                      _buildRepaymentSummarySection(currency),
                    vSpace(24),
                    _buildReasonSection(),
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
              child: SafeArea(child: _buildContinueButton(currency, isSubscriptionActive)),
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
                fontSize: 17.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFE67E22),
              ),
            ),
            Text(
              'Step 1 of 3',
              style: TextStyle(
                fontSize: 17.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFE67E22),
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
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            FractionallySizedBox(
              widthFactor: 1 / 3,
              child: Container(
                height: 4.h,
                decoration: BoxDecoration(
                  color: const Color(0xFFE67E22),
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
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          children: [
            Icon(
              Icons.info_outline,
              size: 24.sp,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            vSpace(8),
            Text(
              'No loan products available right now',
              style: TextStyle(
                fontSize: 17.sp,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            vSpace(4),
            Text(
              'Ask your cooperative admin to publish one.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16.sp,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
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
            fontSize: 17.sp,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        vSpace(8),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: Theme.of(context).dividerColor),
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
              onChanged: (s) => setState(() {
                _selectedScheme = s;
                // On a member-choice scheme start at the minimum — that is
                // the cheapest rate, and every extra month the member adds
                // raises it. Otherwise snap to max, the conservative figure.
                _pickedDuration = s == null
                    ? null
                    : (s.memberCanPickDuration
                          ? s.effectiveMinDuration
                          : s.effectiveMaxDuration);
              }),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSchemeSummary(LoanScheme scheme) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const accent = Color(0xFFE67E22);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        // Make the loan-summary tile readable on dark mode by mixing
        // the orange accent with the surface (the previous fixed
        // 0xFFFFF4E9 cream washed out everywhere on dark, so the body
        // text inside became unreadable). Stretch full width so it
        // doesn't shrink to its content on the application step.
        color: isDark
            ? accent.withValues(alpha: 0.16)
            : const Color(0xFFFFF4E9),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            scheme.title.isNotEmpty ? scheme.title : scheme.loanCode,
            style: TextStyle(
              fontSize: 19.sp,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
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
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 16.sp,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurface,
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
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        vSpace(20),
        if (!_hasEligibility)
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Text(
              _loading
                  ? 'Loading your eligibility…'
                  : (_eligibility != null && _maxAmount <= _minAmount
                        ? 'You don\'t qualify for a loan yet — your EPC holdings are below your cooperative\'s minimum loan amount.'
                        : 'Loan limits unavailable. Pull to refresh.'),
              style: TextStyle(
                fontSize: 17.sp,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          )
        else ...[
          Row(
            children: [
              Text(
                '$symbol${_formatNoDecimals(_minAmount)}',
                style: TextStyle(fontSize: 17.sp, color: Colors.grey.shade600),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: const Color(0xFFE67E22),
                    inactiveTrackColor: Colors.grey.shade300,
                    thumbColor: const Color(0xFFE67E22),
                    thumbShape: RoundSliderThumbShape(enabledThumbRadius: 12.r),
                    overlayShape: RoundSliderOverlayShape(overlayRadius: 24.r),
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
                style: TextStyle(fontSize: 17.sp, color: Colors.grey.shade600),
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
              color: const Color(0xFFE67E22),
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d,]')),
            ],
            decoration: InputDecoration(
              prefixText: '$symbol ',
              prefixStyle: TextStyle(
                fontSize: 24.sp,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFE67E22),
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
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
                borderSide: const BorderSide(
                  color: Color(0xFFE67E22),
                  width: 2,
                ),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 20.w,
                vertical: 16.h,
              ),
            ),
            onChanged: (value) {
              final numeric = value.replaceAll(RegExp(r'[^\d]'), '');
              if (numeric.isEmpty) {
                setState(() => _loanAmount = _minAmount);
                return;
              }
              final parsed = double.tryParse(numeric);
              if (parsed == null) return;
              final clamped = parsed.clamp(_minAmount, _maxAmount).toDouble();
              setState(() => _loanAmount = clamped);
              if (clamped != parsed) {
                final formatted = _formatNoDecimals(clamped);
                _amountController.value = TextEditingValue(
                  text: formatted,
                  selection: TextSelection.collapsed(offset: formatted.length),
                );
              }
            },
          ),
          vSpace(8),
          Text(
            'Minimum: $symbol${_formatNoDecimals(_minAmount)} | Maximum: $symbol${_formatNoDecimals(_maxAmount)}',
            style: TextStyle(fontSize: 16.sp, color: Colors.grey.shade600),
          ),
          vSpace(4),
          Text(
            _eligibility?.maxExplanation ??
                'Your maximum is the sum of your EPC holdings with this cooperative.',
            style: TextStyle(fontSize: 16.sp, color: Colors.grey.shade500),
          ),
        ],
      ],
    );
  }

  /// Member-chosen repayment term. Only rendered when the cooperative
  /// opted the scheme in and the window is a real range. The rate rises
  /// with the term, and these loans are never re-granted.
  Widget _buildDurationSection() {
    final scheme = _selectedScheme!;
    final theme = Theme.of(context);
    final min = scheme.effectiveMinDuration;
    final max = scheme.effectiveMaxDuration;
    final picked = (_pickedDuration ?? min).clamp(min, max);
    final rateLabel = scheme.rateLabelForDuration(picked);
    final baseLabel = scheme.interestRateLabel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Choose Your Repayment Term',
              style: TextStyle(
                fontSize: 17.sp,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const Spacer(),
            Text(
              '$picked month${picked == 1 ? '' : 's'}',
              style: TextStyle(
                fontSize: 17.sp,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFE67E22),
              ),
            ),
          ],
        ),
        vSpace(8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: const Color(0xFFE67E22),
            inactiveTrackColor: theme.dividerColor,
            thumbColor: theme.colorScheme.surface,
            thumbShape: RoundSliderThumbShape(enabledThumbRadius: 10.r),
            overlayShape: RoundSliderOverlayShape(overlayRadius: 20.r),
            trackHeight: 4.h,
          ),
          child: Slider(
            value: picked.toDouble().clamp(min.toDouble(), max.toDouble()),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: (max - min).clamp(1, 120),
            onChanged: (v) => setState(() => _pickedDuration = v.round()),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$min months',
              style: TextStyle(
                fontSize: 13.sp,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            Text(
              '$max months',
              style: TextStyle(
                fontSize: 13.sp,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        vSpace(12),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: const Color(0xFF742CE7).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(
              color: const Color(0xFF742CE7).withValues(alpha: 0.25),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.percent, size: 16.sp, color: const Color(0xFF742CE7)),
                  hSpace(6),
                  Expanded(
                    child: Text(
                      picked == min
                          ? 'Interest rate: $rateLabel'
                          : 'Interest rate: $rateLabel (base $baseLabel + longer term)',
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF742CE7),
                      ),
                    ),
                  ),
                ],
              ),
              vSpace(6),
              Text(
                'A longer term raises your interest rate. You must clear this '
                'loan within the term you choose — it will not be re-granted, '
                'and anything left unpaid at the end becomes a debt you owe '
                'the cooperative.',
                style: TextStyle(
                  fontSize: 13.sp,
                  height: 1.4,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRepaymentSummarySection(String currency) {
    final scheme = _selectedScheme!;
    // Repayment math reflects the *selected* treatment, not the
    // cooperative's default — when the cooperative enables both, the
    // member's pick changes the per-month / total figures live.
    final interestType =
        _selectedInterestType ??
        _eligibility?.defaultInterestType?.value ??
        '1';
    final principalMinor = (_loanAmount * factorFor(currency)).round();
    final installments = scheme.memberCanPickDuration
        ? (_pickedDuration ?? scheme.effectiveMinDuration)
        : (_pickedDuration ?? scheme.effectiveMaxDuration);
    final appliedRate = scheme.rateForDuration(installments);
    final interestMinor = (principalMinor * appliedRate / 100).round();
    final monthlyMinor = estimatedMonthlyRepaymentMinor(
      principalMinor: principalMinor,
      scheme: scheme,
      interestType: interestType,
      currency: currency,
      durationMonths: installments,
    );
    // Repayment + disbursement per interest treatment:
    //  • '1' deduct now  → receive principal − interest; repay the principal.
    //  • '2' add to bal. → receive the principal; repay principal + interest.
    final totalMinor = interestType == '1'
        ? principalMinor
        : principalMinor + interestMinor;
    final disbursedMinor = interestType == '1'
        ? principalMinor - interestMinor
        : principalMinor;

    final theme = Theme.of(context);
    final installmentLabel = installments == 1 ? 'installment' : 'installments';

    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        // Use cardColor + a hairline border instead of dividerColor as a
        // fill; the previous version painted the outer card and the
        // inner Total Interest pill with the SAME dividerColor, so the
        // pill became invisible and the whole card looked off-key.
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Repayment Summary',
            style: TextStyle(
              fontSize: 19.sp,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          vSpace(16),
          // Headline: monthly repayment, big and orange. Subtitle pins
          // the cadence + interest rate in one quiet line so the card
          // reads top-down instead of needing the eye to ping-pong
          // between two equal-weight columns.
          Text(
            Money(monthlyMinor, currency).format(),
            style: TextStyle(
              fontSize: 26.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFFE67E22),
            ),
          ),
          vSpace(4),
          Text(
            'monthly · $installments $installmentLabel · ${scheme.rateLabelForDuration(installments)} interest',
            style: TextStyle(
              fontSize: 16.sp,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          vSpace(16),
          Divider(height: 1, color: theme.dividerColor),
          vSpace(12),
          _summaryRow(
            label: 'Principal',
            value: Money(principalMinor, currency).format(),
          ),
          vSpace(8),
          _summaryRow(
            label: 'Total Interest',
            value: Money(interestMinor, currency).format(),
          ),
          vSpace(8),
          // What actually hits the member's wallet — the headline number they
          // care about, made explicit so "deduct now" isn't mistaken for
          // receiving the full principal.
          _summaryRow(
            label: interestType == '1'
                ? "You'll Receive (interest deducted)"
                : "You'll Receive",
            value: Money(disbursedMinor, currency).format(),
            emphasised: true,
          ),
          vSpace(8),
          _summaryRow(
            label: 'Total Repayment (incl. interest)',
            value: Money(totalMinor, currency).format(),
            emphasised: true,
          ),
        ],
      ),
    );
  }

  Widget _summaryRow({
    required String label,
    required String value,
    bool emphasised = false,
  }) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16.sp,
              color: theme.colorScheme.onSurface.withValues(
                alpha: emphasised ? 0.85 : 0.65,
              ),
              fontWeight: emphasised ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
        hSpace(12),
        Text(
          value,
          style: TextStyle(
            fontSize: emphasised ? 18.sp : 16.sp,
            fontWeight: emphasised ? FontWeight.w800 : FontWeight.w600,
            color: emphasised
                ? const Color(0xFFE67E22)
                : theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  /// Friendly member-facing labels for the interest-treatment value
  /// codes the cooperative dashboard stores. These were the original
  /// mobile copy ("Deduct now" / "Add to balance") that got
  /// accidentally replaced with the dashboard's raw `title`/`note`
  /// jargon. Member-facing UI should not surface accountant terms.
  static const Map<String, ({String title, String note})>
  _interestTreatmentLabels = {
    '1': (
      title: 'Deduct now',
      note: 'Receive principal − interest at disbursement.',
    ),
    '2': (
      title: 'Add to balance',
      note: 'Repay principal + interest over the loan duration.',
    ),
  };

  /// Render the cooperative's interest-treatment configuration. When
  /// only one option is enabled it stays read-only (lock icon, the
  /// original behaviour). When two or more are enabled, the member can
  /// pick between them — pre-selected to the cooperative's default.
  Widget _buildInterestTypeSection() {
    final theme = Theme.of(context);
    final enabled = _eligibility?.enabledInterestTypes ?? const [];

    if (enabled.length > 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Interest treatment',
            style: TextStyle(
              fontSize: 17.sp,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          vSpace(4),
          Text(
            'Your cooperative offers more than one option — pick the one you want.',
            style: TextStyle(
              fontSize: 15.sp,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          vSpace(8),
          for (var i = 0; i < enabled.length; i++) ...[
            _buildInterestTypeChoice(enabled[i]),
            if (i != enabled.length - 1) vSpace(10),
          ],
        ],
      );
    }
    return _buildInterestTypeReadOnly(enabled.isEmpty ? null : enabled.first);
  }

  Widget _buildInterestTypeChoice(InterestTypeOption option) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final friendly = _interestTreatmentLabels[option.value];
    final title =
        friendly?.title ??
        (option.title.isNotEmpty ? option.title : 'Interest treatment');
    final note = friendly?.note ?? (option.note.isNotEmpty ? option.note : '');
    final selected = _selectedInterestType == option.value;
    return InkWell(
      borderRadius: BorderRadius.circular(12.r),
      onTap: () => setState(() => _selectedInterestType = option.value),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: selected
              ? (isDark
                    ? const Color(0xFFE67E22).withValues(alpha: 0.16)
                    : const Color(0xFFFFF4E9))
              : theme.cardColor,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: selected ? const Color(0xFFE67E22) : theme.dividerColor,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 20.sp,
              color: selected
                  ? const Color(0xFFE67E22)
                  : theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            hSpace(10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? const Color(0xFFE67E22)
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  if (note.isNotEmpty) ...[
                    vSpace(4),
                    Text(
                      note,
                      style: TextStyle(
                        fontSize: 16.sp,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.75,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInterestTypeReadOnly(InterestTypeOption? onlyEnabled) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final friendly = onlyEnabled == null
        ? null
        : _interestTreatmentLabels[onlyEnabled.value];
    final title =
        friendly?.title ??
        (onlyEnabled?.title.isNotEmpty == true
            ? onlyEnabled!.title
            : (_loading ? 'Loading…' : 'Not configured'));
    final note =
        friendly?.note ??
        (onlyEnabled?.note.isNotEmpty == true
            ? onlyEnabled!.note
            : 'Set by your cooperative — not member-selectable.');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Interest treatment',
          style: TextStyle(
            fontSize: 17.sp,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        vSpace(8),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFFE67E22).withValues(alpha: 0.16)
                : const Color(0xFFFFF4E9),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: const Color(0xFFE67E22), width: 1.5),
          ),
          child: Row(
            children: [
              Icon(
                Icons.lock_outline,
                size: 18.sp,
                color: const Color(0xFFE67E22),
              ),
              hSpace(10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 17.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFE67E22),
                      ),
                    ),
                    vSpace(4),
                    Text(
                      note,
                      style: TextStyle(
                        fontSize: 16.sp,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.75,
                        ),
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
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        vSpace(12),
        TextField(
          controller: _reasonController,
          maxLines: 3,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            hintText: 'e.g., upgrade my business, buy equipment',
            hintStyle: TextStyle(fontSize: 17.sp, color: Colors.grey.shade400),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(color: Theme.of(context).dividerColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(color: Theme.of(context).dividerColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: Color(0xFFE67E22), width: 2),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16.w,
              vertical: 16.h,
            ),
          ),
          style: TextStyle(
            fontSize: 17.sp,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildContinueButton(String currency, bool isSubscriptionActive) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _hasEligibility && isSubscriptionActive
            ? () {
                final err = _validate();
                if (err != null) {
                  AppToast.error(err);
                  return;
                }
                final draft = LoanApplicationDraft(
                  scheme: _selectedScheme!,
                  amountMajor: _loanAmount,
                  currency: currency,
                  interestType:
                      _selectedInterestType ??
                      _eligibility!.defaultInterestType!.value,
                  reasonForLoan: _reasonController.text.trim(),
                  pickedDurationMonths: _pickedDuration,
                );
                context.pushNamed(
                  'loan-application-step2',
                  extra: {'draft': draft},
                );
              }
            : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE67E22),
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
          style: TextStyle(fontSize: 19.sp, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
