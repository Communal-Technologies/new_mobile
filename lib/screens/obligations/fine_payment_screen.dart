import 'dart:async';

import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_state.dart';
import 'package:communal_mobile/cubits/connectivity/connectivity_cubit.dart';
import 'package:communal_mobile/core/utils/app_currency.dart';
import 'package:communal_mobile/core/utils/money.dart';
import 'package:communal_mobile/core/widgets/animated_logo_loader.dart';
import 'package:communal_mobile/core/widgets/app_toast.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/core/widgets/subscription_expired_banner.dart';
import 'package:communal_mobile/data/models/obligation.dart';
import 'package:communal_mobile/data/repositories/member_obligations_repository.dart';
import 'package:communal_mobile/injection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

enum _PayMethod { wallet, obligation }

class FinePaymentScreen extends StatefulWidget {
  const FinePaymentScreen({super.key, required this.fine, required this.cooperativeId});

  final FineRecord fine;
  final String cooperativeId;

  @override
  State<FinePaymentScreen> createState() => _FinePaymentScreenState();
}

class _FinePaymentScreenState extends State<FinePaymentScreen> {
  late final TextEditingController _amountController;
  final TextEditingController _noteController = TextEditingController();

  final MemberObligationsRepository _repo = MemberObligationsRepository(getIt());

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
    _amountController = TextEditingController(
      text: Money(widget.fine.outstandingMinor, widget.fine.currency).toMajorString(),
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

  Future<void> _loadCashRepos() async {
    setState(() {
      _loadingCashRepos = true;
      _cashRepoError = null;
    });
    try {
      final rows = await _repo.fetchCooperativeCashBankAccounts();
      if (!mounted) return;
      setState(() {
        _cashRepos = rows;
        _selectedCashRepo = rows.length == 1 ? rows.first : null;
        _loadingCashRepos = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cashRepos = const [];
        _selectedCashRepo = null;
        _loadingCashRepos = false;
        _cashRepoError = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
      });
    }
  }

  Future<void> _loadSourceObligations() async {
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) return;
    setState(() {
      _loadingSourceObligations = true;
      _sourceObligationsError = null;
    });
    try {
      final all = await _repo.fetchMemberObligations(auth.user);
      if (!mounted) return;
      final filtered = all.where((o) {
        if (o.category.toLowerCase() == 'equity') return false;
        if (o.accountCode.trim().isEmpty) return false;
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
        _sourceObligationsError =
            e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
      });
    }
  }

  void _onContinue() {
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) {
      AppToast.error('Please sign in again.');
      return;
    }

    final parsed = Money.tryParseMajor(
      _amountController.text.trim(),
      widget.fine.currency,
    );
    final amountMinor = parsed?.amountMinor ?? 0;
    if (amountMinor <= 0) {
      AppToast.error('Enter a valid amount.');
      return;
    }
    if (amountMinor > widget.fine.outstandingMinor) {
      AppToast.error(
        'Amount exceeds the outstanding fine balance (${widget.fine.outstandingLabel}).',
      );
      return;
    }

    if (_payMethod == _PayMethod.wallet) {
      CooperativeCashBankAccount? cash = _selectedCashRepo;
      if (_cashRepos.length == 1) cash = _cashRepos.first;
      if (cash == null) {
        AppToast.error('Select a cooperative bank account to continue.');
        return;
      }
      context.pushNamed('fine-confirm-payment', extra: {
        'fine': widget.fine,
        'cooperativeId': widget.cooperativeId,
        'amountMinor': amountMinor,
        'method': 'NIP transfer',
        'cash_account': cash.toJson(),
        'cash_repository_id': cash.id,
      });
    } else {
      final source = _selectedSourceObligation;
      if (source == null) {
        AppToast.error('Select a source obligation to continue.');
        return;
      }
      if (source.paidAmountMinor < amountMinor) {
        AppToast.error(
          'Insufficient balance in ${source.title} (${source.paidAmountLabel} available).',
        );
        return;
      }
      context.pushNamed('fine-confirm-payment', extra: {
        'fine': widget.fine,
        'cooperativeId': widget.cooperativeId,
        'amountMinor': amountMinor,
        'method': 'Obligation',
        'source_obligation_code': source.accountCode,
        'source_obligation_title': source.title,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, auth) {
        final isOnline = context.watch<ConnectivityCubit>().isConnected;
        final authUser = auth is AuthAuthenticated ? auth.user : null;
        final isSubscriptionActive = authUser?.isCooperativeSubscriptionActive ?? true;
        final bankSubtitleExtra = _payMethod == _PayMethod.wallet
            ? (_loadingCashRepos ? 'Loading cooperative accounts…' : (_cashRepoError ?? ''))
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
                'Pay Fine',
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
                  _buildOverviewCard(auth),
                  vSpace(24),
                  _buildAmountInput(),
                  vSpace(4),
                  Text(
                    'Outstanding: ${widget.fine.outstandingLabel}',
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
                                .map((e) => DropdownMenuItem(
                                      value: e,
                                      child: Text(
                                        [
                                          if (e.bankName.isNotEmpty) e.bankName,
                                          e.accountName,
                                          e.accountNumber,
                                        ].join(' • '),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ))
                                .toList(),
                            onChanged: (v) => setState(() => _selectedCashRepo = v),
                          ),
                        ),
                      ),
                    ] else if (_cashRepos.length == 1) ...[
                      vSpace(10),
                      Text(
                        'Paying into: ${[
                          if (_cashRepos.first.bankName.isNotEmpty) _cashRepos.first.bankName,
                          _cashRepos.first.accountName,
                          _cashRepos.first.accountNumber,
                        ].join(' • ')}',
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
                  onPressed: isOnline && isSubscriptionActive ? _onContinue : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD7263D),
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

  Widget _buildOverviewCard(AuthState auth) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const accent = Color(0xFFD7263D);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: isDark ? accent.withValues(alpha: 0.16) : const Color(0xFFFFEEF0),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: isDark ? accent.withValues(alpha: 0.3) : const Color(0xFFFFCDD3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, color: accent, size: 20.sp),
              hSpace(8),
              Text(
                widget.fine.type,
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: accent,
                ),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  widget.fine.status,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          vSpace(10),
          Text(
            widget.fine.outstandingLabel,
            style: TextStyle(
              fontSize: 26.sp,
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),
          vSpace(4),
          Text(
            widget.fine.description,
            style: TextStyle(
              fontSize: 17.sp,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          vSpace(4),
          Text(
            widget.fine.dateLabel,
            style: TextStyle(fontSize: 15.sp, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountInput() {
    final symbol = currencySymbolForCode(widget.fine.currency);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          Text(
            symbol,
            style: TextStyle(
              fontSize: 22.sp,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          hSpace(8),
          Expanded(
            child: TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(
                fontSize: 22.sp,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              decoration: InputDecoration.collapsed(
                hintText: '0.00',
                hintStyle: TextStyle(
                  fontSize: 22.sp,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMethodSelector(AuthState auth) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(child: _buildMethodChip(_PayMethod.wallet, 'Wallet (NIP)', Iconsax.bank, theme)),
        hSpace(12),
        Expanded(child: _buildMethodChip(_PayMethod.obligation, 'Obligation', Iconsax.convert, theme)),
      ],
    );
  }

  Widget _buildMethodChip(_PayMethod method, String label, IconData icon, ThemeData theme) {
    final selected = _payMethod == method;
    return GestureDetector(
      onTap: () => setState(() => _payMethod = method),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFD7263D) : theme.cardColor,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: selected ? const Color(0xFFD7263D) : theme.dividerColor,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: selected ? Colors.white : theme.colorScheme.onSurface, size: 18.sp),
            hSpace(8),
            Text(
              label,
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNipTransferInfo(AuthState auth) {
    final theme = Theme.of(context);
    final walletLine = auth is AuthAuthenticated
        ? Money(auth.user.walletBalanceKobo, resolveCurrencyCode(auth.user)).format()
        : '—';
    final hasRepo = _cashRepos.isNotEmpty;
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: hasRepo ? const Color(0xFFD7263D) : theme.dividerColor,
          width: 2,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              color: const Color(0xFFD7263D).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(Iconsax.building, color: const Color(0xFFD7263D), size: 22.sp),
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
                      ? 'Payment is sent from your Communal account to your cooperative\'s bank account via NIP.'
                      : 'Your cooperative has not published an active bank account yet.',
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

  Widget _buildSourceObligationPicker() {
    if (_loadingSourceObligations) {
      return const Center(child: AnimatedLogoLoader());
    }
    if (_sourceObligationsError != null) {
      return Container(
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: Text(
          _sourceObligationsError!,
          style: TextStyle(fontSize: 17.sp, color: Colors.red.shade700),
        ),
      );
    }
    if (_sourceObligations.isEmpty) {
      return Text(
        'No obligations with available balance to use as source.',
        style: TextStyle(fontSize: 17.sp, color: Colors.grey.shade600),
      );
    }
    // Bounded + scrollable so a long list (e.g. 20+ obligations) doesn't push
    // the rest of the form far down the page.
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: 320.h),
      child: SingleChildScrollView(
        child: Column(
      children: _sourceObligations.map((o) {
        final selected = _selectedSourceObligation?.accountCode == o.accountCode;
        return GestureDetector(
          onTap: () => setState(() => _selectedSourceObligation = o),
          child: Container(
            margin: EdgeInsets.only(bottom: 10.h),
            padding: EdgeInsets.all(14.w),
            decoration: BoxDecoration(
              color: selected
                  ? const Color(0xFFD7263D).withValues(alpha: 0.08)
                  : Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(
                color: selected ? const Color(0xFFD7263D) : Theme.of(context).dividerColor,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Radio<String>(
                  value: o.accountCode,
                  groupValue: _selectedSourceObligation?.accountCode,
                  onChanged: (_) => setState(() => _selectedSourceObligation = o),
                  activeColor: const Color(0xFFD7263D),
                ),
                hSpace(8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        o.title,
                        style: TextStyle(
                          fontSize: 17.sp,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        'Available: ${o.paidAmountLabel}',
                        style: TextStyle(fontSize: 15.sp, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
        ),
      ),
    );
  }

  Widget _buildNarrationField() {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        children: [
          TextField(
            controller: _noteController,
            maxLines: 3,
            maxLength: _noteLimit,
            style: TextStyle(fontSize: 17.sp, color: Theme.of(context).colorScheme.onSurface),
            decoration: InputDecoration.collapsed(
              hintText: 'Add a note…',
              hintStyle: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                fontSize: 17.sp,
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${_noteController.text.length}/$_noteLimit',
              style: TextStyle(fontSize: 14.sp, color: Colors.grey.shade500),
            ),
          ),
        ],
      ),
    );
  }
}

/// Returns the currency symbol for a given ISO code.
String currencySymbolForCode(String code) {
  switch (code.toUpperCase()) {
    case 'NGN':
      return '₦';
    case 'USD':
      return '\$';
    case 'GBP':
      return '£';
    case 'EUR':
      return '€';
    default:
      return code;
  }
}
