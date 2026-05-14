import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_state.dart';
import 'package:communal_mobile/cubits/connectivity/connectivity_cubit.dart';
import 'package:communal_mobile/core/utils/app_currency.dart';
import 'package:communal_mobile/core/utils/money.dart';
import 'package:communal_mobile/core/widgets/app_toast.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/data/models/obligation.dart';
import 'package:communal_mobile/data/repositories/member_obligations_repository.dart';
import 'package:communal_mobile/injection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

class ObligationPaymentScreen extends StatefulWidget {
  const ObligationPaymentScreen({super.key, required this.obligation});

  final Obligation obligation;

  @override
  State<ObligationPaymentScreen> createState() =>
      _ObligationPaymentScreenState();
}

/// Source-of-funds picker on the obligation-payment screen. `wallet` keeps
/// the existing path (Communal account → NIP transfer to the cooperative
/// bank → record payment). `obligation` uses one of the member's existing
/// obligation balances to pay this one — backend gateway `'obligation'`,
/// no NIP transfer.
enum _PayMethod { wallet, obligation }

class _ObligationPaymentScreenState extends State<ObligationPaymentScreen> {
  late final TextEditingController _amountController;
  final TextEditingController _noteController = TextEditingController();

  final MemberObligationsRepository _obligationsRepo =
      MemberObligationsRepository(getIt());
  List<CooperativeCashBankAccount> _cashRepos = const [];
  bool _loadingCashRepos = true;
  CooperativeCashBankAccount? _selectedCashRepo;
  String? _cashRepoError;

  // Source-obligation flow. Loaded post-frame because the AuthBloc user
  // is only available via context.
  _PayMethod _payMethod = _PayMethod.wallet;
  List<Obligation> _sourceObligations = const [];
  bool _loadingSourceObligations = false;
  String? _sourceObligationsError;
  Obligation? _selectedSourceObligation;

  static const int _noteLimit = 100;

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
        color: hasRepo ? Colors.white : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: hasRepo ? const Color(0xFF7434FF) : Colors.grey.shade300,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
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
              color: const Color(0xFF5B8DFF).withOpacity(0.15),
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
                      ? 'Payment is sent from your Communal account to your cooperative’s bank account. Anchor settles this as an outbound NIP transfer.'
                      : 'Your cooperative has not published an active bank account to receive this payment yet.',
                  style: TextStyle(
                    fontSize: 17.sp,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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

  @override
  void initState() {
    super.initState();
    // Default the amount input to the per-installment in major units —
    // formatted with the right number of decimals for the obligation's
    // currency (e.g. "5000.00" for NGN, "5000" for JPY) so the input
    // already parses cleanly via Money.tryParseMajor on submit.
    _amountController = TextEditingController(
      text: Money(
        widget.obligation.perInstallmentMinor,
        widget.obligation.currency,
      ).toMajorString(),
    );
    _noteController.addListener(() => setState(() {}));
    _loadCashRepos();
    // Source obligations need the AuthBloc user — available via context
    // only after the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadSourceObligations();
    });
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
      //   - Drop equities (product rule: equity can never be a source).
      //   - Drop the obligation being paid (no self-payment).
      //   - Drop ones with no contributed balance to spend
      //     (`paidAmountMinor` is what the backend will decrement from).
      final filtered = all.where((o) {
        if (o.category.toLowerCase() == 'equity') return false;
        final code = o.accountCode.trim();
        if (code.isNotEmpty && code == widget.obligation.accountCode.trim()) {
          return false;
        }
        if (code.isEmpty) return false; // can't reference it on the API
        return o.paidAmountMinor > 0;
      }).toList();
      setState(() {
        _sourceObligations = filtered;
        _selectedSourceObligation = filtered.length == 1 ? filtered.first : null;
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
            'Unable to load cooperative bank accounts. Please try again or contact your cooperative administrator.';
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
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final outstanding = widget.obligation.balanceLabel;

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, auth) {
        final isOnline = context.watch<ConnectivityCubit>().isConnected;
        final bankSubtitleExtra = _payMethod == _PayMethod.wallet
            ? (_loadingCashRepos
                ? 'Loading cooperative accounts…'
                : (_cashRepoError ?? ''))
            : '';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
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
            'Make Payment',
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
              _buildOverviewCard(outstanding, auth),
              vSpace(24),
              _buildAmountInput(),
              vSpace(4),
              Text(
                'Suggested: ${widget.obligation.perInstallmentLabel}',
                style: TextStyle(fontSize: 17.sp, color: Colors.grey.shade600),
              ),
              vSpace(24),
              Text(
                'Payment Method',
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
                  style: TextStyle(fontSize: 16.sp, color: Colors.grey.shade600),
                ),
              ],
              vSpace(12),
              _buildMethodSelector(auth),
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
                      border: Border.all(color: Theme.of(context).dividerColor),
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
                        onChanged: (v) => setState(() => _selectedCashRepo = v),
                      ),
                    ),
                  ),
                ] else if (_cashRepos.length == 1) ...[
                  vSpace(10),
                  Text(
                    'Paying into: ${_cashRepos.first.accountName} • ${_cashRepos.first.accountNumber}',
                    style: TextStyle(fontSize: 17.sp, color: Colors.grey.shade700),
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
              onPressed: isOnline ? _onContinue : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7434FF),
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
                  color: Theme.of(context).cardColor,
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

  String _cooperativeSubtitle(AuthState auth) {
    if (auth is AuthAuthenticated) {
      final line = auth.user.cooperativeDisplayName.trim();
      if (line.isNotEmpty && line != '—') return line;
    }
    final id = widget.obligation.cooperativeId.trim();
    if (id.isNotEmpty) return id;
    return 'Cooperative';
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
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Paying for',
            style: TextStyle(fontSize: 17.sp, color: Colors.grey.shade500),
          ),
          vSpace(6),
          Text(
            widget.obligation.title,
            style: TextStyle(
              fontSize: 19.sp,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          Text(
            _cooperativeSubtitle(auth),
            style: TextStyle(fontSize: 17.sp, color: Colors.grey.shade600),
          ),
          vSpace(16),
          Divider(color: Theme.of(context).dividerColor),
          vSpace(12),
          Row(
            children: [
              Expanded(
                child: _MetricBlock(
                  label: 'Installment Amount',
                  value: widget.obligation.perInstallmentLabel,
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
    final currency = widget.obligation.currency;
    final decimals = decimalsFor(currency);
    final allowDecimal = decimals > 0;
    final decimalSeparators = allowDecimal ? r'\.,' : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Amount to Pay',
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
              widget.obligation.perInstallmentMinor,
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
              borderSide: const BorderSide(color: Color(0xFF7434FF), width: 2),
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

  Widget _buildMethodSelector(AuthState auth) {
    return Row(
      children: [
        Expanded(
          child: _MethodChip(
            icon: Iconsax.wallet_3,
            iconColor: const Color(0xFF7434FF),
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
            sublabel: 'Use another balance',
            selected: _payMethod == _PayMethod.obligation,
            onTap: () => setState(() => _payMethod = _PayMethod.obligation),
          ),
        ),
      ],
    );
  }

  Widget _buildSourceObligationPicker() {
    if (_loadingSourceObligations) {
      return _PickerCard.message(
        icon: Iconsax.refresh_2,
        title: 'Loading your obligations…',
        body: 'Pulling balances we can use to fund this payment.',
        accent: const Color(0xFF7434FF),
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
            'You need a non-equity obligation with a contributed balance to '
            'fund this payment. Equity contributions cannot be used.',
        accent: Colors.grey.shade700,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFF7434FF), width: 2),
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
              hintText: 'Add a note for this payment...',
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
    final currency = widget.obligation.currency;
    final parsed = Money.tryParseMajor(_amountController.text, currency);
    final amountMinor =
        parsed?.amountMinor ?? widget.obligation.perInstallmentMinor;
    if (amountMinor <= 0) {
      AppToast.error('Enter a valid amount to continue.');
      return;
    }

    if (widget.obligation.category == 'Equity') {
      final maxPayMinor = widget.obligation.balanceMinor;
      if (amountMinor > maxPayMinor) {
        AppToast.error(
          'Equity payments cannot exceed your remaining cap '
          '(${widget.obligation.balanceLabel}).',
        );
        return;
      }
    }

    if (_payMethod == _PayMethod.obligation) {
      final source = _selectedSourceObligation;
      if (source == null) {
        AppToast.error('Select an obligation to pay from.');
        return;
      }
      // Defensive: equities are filtered out of the picker, but re-check
      // here in case the list ever ships a stale entry.
      if (source.category.toLowerCase() == 'equity') {
        AppToast.error('Equity contributions cannot be used to pay other obligations.');
        return;
      }
      if (source.paidAmountMinor < amountMinor) {
        AppToast.error(
          '${source.title} only has ${source.paidAmountLabel} '
          'available. Reduce the amount or pick another obligation.',
        );
        return;
      }
      context.pushNamed(
        'obligation-confirm-payment',
        extra: {
          'obligation': widget.obligation,
          'amountMinor': amountMinor,
          'method': 'Obligation',
          'source_obligation_code': source.accountCode,
          'source_obligation_title': source.title,
        },
      );
      return;
    }

    if (_cashRepos.isEmpty) {
      AppToast.error('No cooperative bank account is available for this payment.');
      return;
    }

    final CooperativeCashBankAccount? cash =
        _cashRepos.length == 1 ? _cashRepos.first : _selectedCashRepo;
    if (cash == null) {
      AppToast.error('Select the cooperative account to pay into.');
      return;
    }

    context.pushNamed(
      'obligation-confirm-payment',
      extra: {
        'obligation': widget.obligation,
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
            color: selected ? const Color(0xFF7434FF) : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36.w,
              height: 36.w,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
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
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
              color: selected
                  ? const Color(0xFF7434FF)
                  : Colors.grey.shade400,
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
    final accent = selected ? const Color(0xFF7434FF) : Colors.grey.shade700;
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
                color: const Color(0xFF16A34A).withOpacity(0.10),
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
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
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
              color: accent.withOpacity(0.12),
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
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                if (action != null) ...[
                  vSpace(6),
                  action!,
                ],
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
