import 'package:flutter/material.dart';
import 'package:communal_mobile/core/utils/system_ui_style.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_state.dart';
import 'package:communal_mobile/core/utils/app_currency.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/data/repositories/loan_repository.dart';
import 'package:communal_mobile/injection.dart';
import 'package:communal_mobile/screens/account/widgets/freeze_account_header.dart';
import 'package:communal_mobile/screens/account/widgets/account_to_freeze_card.dart';
import 'package:communal_mobile/screens/account/widgets/freeze_consequences_section.dart';
import 'package:communal_mobile/screens/account/widgets/freeze_action_buttons.dart';
import 'package:communal_mobile/screens/account/widgets/loan_owing_block_card.dart';

class FreezeAccountScreen extends StatefulWidget {
  const FreezeAccountScreen({super.key});

  @override
  State<FreezeAccountScreen> createState() => _FreezeAccountScreenState();
}

class _FreezeAccountScreenState extends State<FreezeAccountScreen> {
  // Mirror the gate from delete_account_screen — freezing while a loan
  // is outstanding would lock the cooperative's collateral path, so we
  // block both flows the same way.
  int _outstandingLoanMinor = 0;
  String _currency = 'NGN';
  bool _loanCheckLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadLoanBalance());
  }

  Future<void> _loadLoanBalance() async {
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) {
      if (mounted) setState(() => _loanCheckLoading = false);
      return;
    }
    final user = auth.user;
    final ledger = user.ledgerNumber?.trim() ?? '';
    if (ledger.isEmpty) {
      if (mounted) setState(() => _loanCheckLoading = false);
      return;
    }
    try {
      final repo = LoanRepository(getIt());
      final balance = await repo.fetchLoanBalanceMinor(ledger);
      if (!mounted) return;
      setState(() {
        _outstandingLoanMinor = balance;
        _currency = resolveCurrencyCode(user);
        _loanCheckLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loanCheckLoading = false);
    }
  }

  /// 1–2 letter initials from a display name. "Pado Lebari" → "PL",
  /// "Pado" → "P", empty → "•". Matches the avatar fallback used on
  /// the home / profile screens.
  String _initialsFor(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '•';
    final parts = trimmed
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '•';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final hasOutstandingLoan = _outstandingLoanMinor > 0;
    final auth = context.watch<AuthBloc>().state;
    final user = auth is AuthAuthenticated ? auth.user : null;
    final displayName = user?.name.trim().isNotEmpty == true
        ? user!.name.trim()
        : 'Your account';
    final contact = (user?.phone?.trim().isNotEmpty == true)
        ? user!.phone!.trim()
        : (user?.email?.trim() ?? '');

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemOverlayForTheme(Theme.of(context)),
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          title: Text(
            'Freeze Account',
            style: TextStyle(fontSize: 19.sp, fontWeight: FontWeight.w700),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: Column(
                      children: [
                        vSpace(24),
                        const FreezeAccountHeader(
                          icon: Icons.pause_circle_outline,
                          title:
                              'Are you sure you want to Freeze your Account?',
                          description:
                              'This will temporarily disable your account and block all transactions until you unfreeze it.',
                        ),
                        vSpace(32),
                        AccountToFreezeCard(
                          name: displayName,
                          contact: contact,
                          avatarInitials: _initialsFor(displayName),
                        ),
                        vSpace(32),
                        const FreezeConsequencesSection(),
                        vSpace(24),
                        if (hasOutstandingLoan) ...[
                          LoanOwingBlockCard(
                            outstandingMinor: _outstandingLoanMinor,
                            currency: _currency,
                          ),
                          vSpace(24),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              if (_loanCheckLoading)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: LinearProgressIndicator(minHeight: 2),
                )
              else if (!hasOutstandingLoan)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: const FreezeActionButtons(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
