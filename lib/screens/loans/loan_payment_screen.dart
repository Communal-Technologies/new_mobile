import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_state.dart';
import 'package:communal_mobile/cubits/connectivity/connectivity_cubit.dart';
import 'package:communal_mobile/core/utils/app_currency.dart';
import 'package:communal_mobile/core/utils/money.dart';
import 'package:communal_mobile/core/utils/system_ui_style.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/core/widgets/subscription_expired_banner.dart';
import 'package:communal_mobile/core/widgets/wallet_funding_required_banner.dart';
import 'package:communal_mobile/data/models/loan_application.dart';
import 'package:communal_mobile/data/models/obligation.dart';
import 'package:communal_mobile/data/repositories/member_obligations_repository.dart';
import 'package:communal_mobile/injection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

/// Source-of-funds picker on the loan-repayment screen. `wallet` rides
/// the existing transfer pipeline (Communal account → NIP → cooperative
/// bank → record loan repayment). `obligation` drains a non-equity
/// obligation balance directly into the loan (no NIP transfer); the
/// backend `pay-loan` endpoint with `gateway: 'obligation'` decrements
/// the source's `amount_paid` and credits the loan atomically.
enum _PayMethod { wallet, obligation }

/// Loan-area orange (matches LoanOfferCard / detail header / progress).
const Color _kLoanOrange = Color(0xFFE67E22);

class LoanPaymentScreen extends StatefulWidget {
  const LoanPaymentScreen({super.key, required this.loan});

  final LoanApplication loan;

  @override
  State<LoanPaymentScreen> createState() => _LoanPaymentScreenState();
}

class _LoanPaymentScreenState extends State<LoanPaymentScreen> {
  late final TextEditingController _amountController;
  final TextEditingController _noteController = TextEditingController();

  final MemberObligationsRepository _obligationsRepo =
      MemberObligationsRepository(getIt());
  List<CooperativeCashBankAccount> _cashRepos = const [];
  bool _loadingCashRepos = true;
  CooperativeCashBankAccount? _selectedCashRepo;
  String? _cashRepoError;

  _PayMethod _payMethod = _PayMethod.wallet;
  List<Obligation> _sourceObligations = const [];
  bool _loadingSourceObligations = false;
  String? _sourceObligationsError;
  Obligation? _selectedSourceObligation;

  static const int _noteLimit = 100;

  @override
  void initState() {
    super.initState();
    // Default to monthly repayment (in major units) so the input is
    // already a sane suggestion — the same pattern the obligation
    // payment screen uses with `perInstallmentMinor`.
    final suggested = widget.loan.monthlyRepaymentMinor > 0
        ? widget.loan.monthlyRepaymentMinor
        : widget.loan.balanceMinor;
    _amountController = TextEditingController(
      text: Money(suggested, widget.loan.currency).toMajorString(),
    );
    _noteController.addListener(() => setState(() {}));
    _loadCashRepos();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadSourceObligations();
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadSourceObligations() async {
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) {
      setState(() {
        _sourceObligationsError = 'Sign in again to load obligations.';
      });
      return;
    }
    setState(() {
      _loadingSourceObligations = true;
      _sourceObligationsError = null;
    });
    try {
      final all = await _obligationsRepo.fetchMemberObligations(auth.user);
      if (!mounted) return;
      // Filter rules:
      //   - Drop equities (product rule: equity can never repay a loan).
      //   - Drop obligations with no contributed balance to spend.
      final filtered = all.where((o) {
        if (o.category.toLowerCase() == 'equity') return false;
        final code = o.accountCode.trim();
        if (code.isEmpty) return false;
        return o.paidAmountMinor > 0;
      }).toList();
      setState(() {
        _sourceObligations = filtered;
        _selectedSourceObligation = filtered.length == 1
            ? filtered.first
            : null;
        _loadingSourceObligations = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sourceObligations = const [];
        _selectedSourceObligation = null;
        _loadingSourceObligations = false;
        _sourceObligationsError = e
            .toString()
            .replaceFirst(RegExp(r'^Exception:\s*'), '')
            .trim();
      });
    }
  }

  Future<void> _loadCashRepos() async {
    setState(() {
      _loadingCashRepos = true;
      _cashRepoError = null;
    });
    try {
      final rows = await _obligationsRepo.fetchCooperativeCashBankAccounts();
      if (!mounted) return;
      setState(() {
        _cashRepos = rows;
        _selectedCashRepo = rows.length == 1 ? rows.first : null;
        _loadingCashRepos = false;
      });
    } catch (e) {
      if (!mounted) return;
      var msg = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
      if (msg.isEmpty) {
        msg =
            'Unable to load cooperative bank accounts. '
            'Please try again or contact your cooperative administrator.';
      }
      setState(() {
        _cashRepos = const [];
        _selectedCashRepo = null;
        _loadingCashRepos = false;
        _cashRepoError = msg;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final outstanding = widget.loan.balanceLabel;

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, auth) {
        final isOnline = context.watch<ConnectivityCubit>().isConnected;
        final authUser = auth is AuthAuthenticated ? auth.user : null;
        final isSubscriptionActive = authUser?.isCooperativeSubscriptionActive ?? true;
        // Wallet-funded (NIP) requires a funded wallet; obligation-funded only
        // requires a configured transaction PIN.
        final canFundSelectedMethod = _payMethod == _PayMethod.wallet
            ? (authUser?.hasWalletBalance ?? false)
            : (authUser?.hasSecurityPin ?? false);
        final bankSubtitleExtra = _payMethod == _PayMethod.wallet
            ? (_loadingCashRepos
                  ? 'Loading cooperative accounts…'
                  : (_cashRepoError ?? ''))
            : '';

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: systemOverlayForTheme(Theme.of(context)),
          child: Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            appBar: AppBar(
              elevation: 0,
              backgroundColor: Theme.of(context).cardColor,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              title: Text(
                'Make Repayment',
                style: TextStyle(
                  fontSize: 19.sp,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              centerTitle: true,
            ),
            body: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isSubscriptionActive)
                    SubscriptionExpiredBanner(endDate: authUser?.subscriptionEndDate),
                  if (_payMethod == _PayMethod.wallet &&
                      !(authUser?.hasWalletBalance ?? false))
                    const WalletFundingRequiredBanner(),
                  if (_payMethod == _PayMethod.obligation &&
                      !(authUser?.hasSecurityPin ?? false))
                    const WalletFundingRequiredBanner(
                      title: 'Transaction PIN required',
                      message:
                          'Set up your transaction PIN to pay from an '
                          'obligation. Configure it in settings to continue.',
                    ),
                  _buildOverviewCard(outstanding, auth),
                  vSpace(24),
                  _buildAmountInput(),
                  vSpace(4),
                  Text(
                    'Suggested: ${widget.loan.monthlyRepaymentLabel}',
                    style: TextStyle(
                      fontSize: 17.sp,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  vSpace(24),
                  Text(
                    'Repayment Source',
                    style: TextStyle(
                      fontSize: 19.sp,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  if (bankSubtitleExtra.isNotEmpty) ...[
                    vSpace(6),
                    Text(
                      bankSubtitleExtra,
                      style: TextStyle(
                        fontSize: 16.sp,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                  vSpace(12),
                  _buildMethodSelector(),
                  vSpace(14),
                  if (_payMethod == _PayMethod.wallet) ...[
                    _buildNipTransferInfo(auth),
                    if (_cashRepos.length > 1) ...[
                      vSpace(12),
                      Text(
                        'Cooperative account',
                        style: TextStyle(
                          fontSize: 17.sp,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      vSpace(8),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12.w),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(14.r),
                          border: Border.all(
                            color: Theme.of(context).dividerColor,
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<CooperativeCashBankAccount>(
                            isExpanded: true,
                            value: _selectedCashRepo,
                            hint: const Text('Select account'),
                            items: _cashRepos
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(
                                      '${e.accountName} • ${e.accountNumber}',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _selectedCashRepo = v),
                          ),
                        ),
                      ),
                    ] else if (_cashRepos.length == 1) ...[
                      vSpace(10),
                      Text(
                        'Paying into: ${_cashRepos.first.accountName} • ${_cashRepos.first.accountNumber}',
                        style: TextStyle(
                          fontSize: 17.sp,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ] else ...[
                    _buildSourceObligationPicker(),
                  ],
                  vSpace(24),
                  Text(
                    'Narration (Optional)',
                    style: TextStyle(
                      fontSize: 19.sp,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  vSpace(10),
                  _buildNarrationField(),
                ],
              ),
            ),
            bottomNavigationBar: SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 16.h),
                child: ElevatedButton(
                  onPressed:
                      isOnline && isSubscriptionActive && canFundSelectedMethod
                      ? _onContinue
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kLoanOrange,
                    minimumSize: Size(double.infinity, 52.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18.r),
                    ),
                  ),
                  child: Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: 19.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOverviewCard(String outstanding, AuthState auth) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Repaying',
            style: TextStyle(fontSize: 17.sp, color: Colors.grey.shade500),
          ),
          vSpace(6),
          Text(
            widget.loan.displayLabel.isNotEmpty
                ? widget.loan.displayLabel
                : 'Loan',
            style: TextStyle(
              fontSize: 19.sp,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          if (widget.loan.referenceId.isNotEmpty)
            Text(
              'Ref: ${widget.loan.referenceId}',
              style: TextStyle(fontSize: 17.sp, color: Colors.grey.shade600),
            ),
          vSpace(16),
          Divider(color: Theme.of(context).dividerColor),
          vSpace(12),
          Row(
            children: [
              Expanded(
                child: _MetricBlock(
                  label: 'Monthly Repayment',
                  value: widget.loan.monthlyRepaymentLabel,
                ),
              ),
              Expanded(
                child: _MetricBlock(
                  label: 'Outstanding Balance',
                  value: outstanding,
                  alignRight: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAmountInput() {
    final currency = widget.loan.currency;
    final decimals = decimalsFor(currency);
    final allowDecimal = decimals > 0;
    final decimalSeparators = allowDecimal ? r'\.,' : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Amount to Repay',
          style: TextStyle(
            fontSize: 19.sp,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        vSpace(10),
        TextField(
          controller: _amountController,
          keyboardType: TextInputType.numberWithOptions(decimal: allowDecimal),
          inputFormatters: [
            FilteringTextInputFormatter.allow(
              RegExp('[0-9$decimalSeparators]'),
            ),
          ],
          decoration: InputDecoration(
            prefixText: '${currencySymbolForCode(currency)} ',
            hintText: Money(
              widget.loan.monthlyRepaymentMinor,
              currency,
            ).toMajorString(),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.r),
              borderSide: BorderSide(color: Theme.of(context).dividerColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.r),
              borderSide: const BorderSide(color: _kLoanOrange, width: 2),
            ),
          ),
          style: TextStyle(
            fontSize: 19.sp,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildMethodSelector() {
    return Row(
      children: [
        Expanded(
          child: _MethodChip(
            icon: Iconsax.wallet_3,
            iconColor: _kLoanOrange,
            label: 'Wallet',
            sublabel: 'NIP transfer',
            selected: _payMethod == _PayMethod.wallet,
            onTap: () => setState(() => _payMethod = _PayMethod.wallet),
          ),
        ),
        hSpace(10),
        Expanded(
          child: _MethodChip(
            icon: Iconsax.refresh_2,
            iconColor: const Color(0xFF16A34A),
            label: 'Obligation',
            sublabel: 'Use a non-equity balance',
            selected: _payMethod == _PayMethod.obligation,
            onTap: () => setState(() => _payMethod = _PayMethod.obligation),
          ),
        ),
      ],
    );
  }

  Widget _buildNipTransferInfo(AuthState auth) {
    final walletLine = auth is AuthAuthenticated
        ? Money(
            auth.user.walletBalanceKobo,
            resolveCurrencyCode(auth.user),
          ).format()
        : '—';
    final hasRepo = _cashRepos.isNotEmpty;
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: hasRepo ? Theme.of(context).cardColor : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: hasRepo ? _kLoanOrange : Colors.grey.shade300,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              color: const Color(0xFF5B8DFF).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(
              Iconsax.building,
              color: const Color(0xFF5B8DFF),
              size: 22.sp,
            ),
          ),
          hSpace(14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Transfer (NIP)',
                  style: TextStyle(
                    fontSize: 19.sp,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                vSpace(4),
                Text(
                  hasRepo
                      ? 'Repayment is sent from your Communal account to your cooperative\'s bank account. Anchor settles this as an outbound NIP transfer.'
                      : 'Your cooperative has not published an active bank account to receive this repayment yet.',
                  style: TextStyle(
                    fontSize: 17.sp,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                vSpace(6),
                Text(
                  'Available in Communal: $walletLine',
                  style: TextStyle(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceObligationPicker() {
    if (_loadingSourceObligations) {
      return _PickerCard.message(
        icon: Iconsax.refresh_2,
        title: 'Loading your obligations…',
        body: 'Pulling balances we can use to fund this repayment.',
        accent: _kLoanOrange,
      );
    }
    if (_sourceObligationsError != null) {
      return _PickerCard.message(
        icon: Iconsax.warning_2,
        title: 'Could not load obligations',
        body: _sourceObligationsError!,
        accent: Colors.red,
        action: TextButton(
          onPressed: _loadSourceObligations,
          child: const Text('Retry'),
        ),
      );
    }
    if (_sourceObligations.isEmpty) {
      return _PickerCard.message(
        icon: Iconsax.info_circle,
        title: 'No eligible obligations',
        body:
            'You need a non-equity obligation with a contributed '
            'balance to fund this repayment. Equity contributions cannot '
            'be used to repay a loan.',
        accent: Colors.grey.shade700,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: _kLoanOrange, width: 2),
      ),
      child: Column(
        children: [
          for (var i = 0; i < _sourceObligations.length; i++) ...[
            _SourceObligationTile(
              obligation: _sourceObligations[i],
              selected:
                  _selectedSourceObligation?.accountCode ==
                  _sourceObligations[i].accountCode,
              onTap: () => setState(
                () => _selectedSourceObligation = _sourceObligations[i],
              ),
            ),
            if (i < _sourceObligations.length - 1)
              Divider(height: 1, color: Theme.of(context).dividerColor),
          ],
        ],
      ),
    );
  }

  Widget _buildNarrationField() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _noteController,
            maxLines: 3,
            maxLength: _noteLimit,
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: 'Add a note for this repayment...',
              counterText: '',
            ),
            style: TextStyle(fontSize: 17.sp),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${_noteController.text.length}/$_noteLimit',
              style: TextStyle(fontSize: 16.sp, color: Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }

  void _onContinue() {
    final currency = widget.loan.currency;
    final parsed = Money.tryParseMajor(_amountController.text, currency);
    final amountMinor = parsed?.amountMinor ?? 0;
    if (amountMinor <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount to continue.')),
      );
      return;
    }
    if (amountMinor > widget.loan.balanceMinor + widget.loan.interestMinor) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Amount exceeds the outstanding loan balance '
            '(${widget.loan.balanceLabel}).',
          ),
        ),
      );
      return;
    }

    if (_payMethod == _PayMethod.obligation) {
      final source = _selectedSourceObligation;
      if (source == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select an obligation to repay from.')),
        );
        return;
      }
      // Defensive — equities are filtered out of the picker, but
      // re-check in case the list ever ships a stale entry.
      if (source.category.toLowerCase() == 'equity') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Equity contributions cannot be used to repay a loan.',
            ),
          ),
        );
        return;
      }
      if (source.paidAmountMinor < amountMinor) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${source.title} only has ${source.paidAmountLabel} '
              'available. Reduce the amount or pick another obligation.',
            ),
          ),
        );
        return;
      }
      context.pushNamed(
        'loan-confirm-payment',
        extra: {
          'loan': widget.loan,
          'amountMinor': amountMinor,
          'method': 'Obligation',
          'source_obligation_code': source.accountCode,
          'source_obligation_title': source.title,
        },
      );
      return;
    }

    if (_cashRepos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No cooperative bank account is available for this repayment.',
          ),
        ),
      );
      return;
    }

    final cash = _cashRepos.length == 1 ? _cashRepos.first : _selectedCashRepo;
    if (cash == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select the cooperative account to pay into.'),
        ),
      );
      return;
    }

    context.pushNamed(
      'loan-confirm-payment',
      extra: {
        'loan': widget.loan,
        'amountMinor': amountMinor,
        'method': 'NIP transfer',
        'cash_account': cash.toJson(),
        'cash_repository_id': cash.id,
      },
    );
  }
}

class _MethodChip extends StatelessWidget {
  const _MethodChip({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.sublabel,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String sublabel;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: selected ? _kLoanOrange : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36.w,
              height: 36.w,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Icon(icon, color: iconColor, size: 18.sp),
            ),
            hSpace(10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    sublabel,
                    style: TextStyle(
                      fontSize: 16.sp,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected ? _kLoanOrange : Colors.grey.shade400,
              size: 20.sp,
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceObligationTile extends StatelessWidget {
  const _SourceObligationTile({
    required this.obligation,
    required this.selected,
    required this.onTap,
  });

  final Obligation obligation;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = selected ? _kLoanOrange : Colors.grey.shade700;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14.r),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38.w,
              height: 38.w,
              decoration: BoxDecoration(
                color: const Color(0xFF16A34A).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Icon(
                Iconsax.coin,
                color: const Color(0xFF16A34A),
                size: 18.sp,
              ),
            ),
            hSpace(12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    obligation.title,
                    style: TextStyle(
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  vSpace(2),
                  Text(
                    '${obligation.category} • Available ${obligation.paidAmountLabel}',
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
            hSpace(8),
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: accent,
              size: 20.sp,
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerCard extends StatelessWidget {
  const _PickerCard.message({
    required this.icon,
    required this.title,
    required this.body,
    required this.accent,
    this.action,
  });

  final IconData icon;
  final String title;
  final String body;
  final Color accent;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38.w,
            height: 38.w,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(icon, color: accent, size: 18.sp),
          ),
          hSpace(12),
          Expanded(
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
                vSpace(4),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 16.sp,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                if (action != null) ...[vSpace(6), action!],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricBlock extends StatelessWidget {
  const _MetricBlock({
    required this.label,
    required this.value,
    this.alignRight = false,
  });

  final String label;
  final String value;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    final alignment = alignRight
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;
    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 17.sp, color: Colors.grey.shade600),
        ),
        vSpace(4),
        Text(
          value,
          style: TextStyle(
            fontSize: 19.sp,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
