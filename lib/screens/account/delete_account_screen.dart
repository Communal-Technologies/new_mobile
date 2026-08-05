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
import 'package:communal_mobile/screens/account/widgets/data_loss_item.dart';
import 'package:communal_mobile/screens/account/widgets/freeze_suggestion_box.dart';
import 'package:communal_mobile/screens/account/widgets/delete_account_warning_section.dart';
import 'package:communal_mobile/screens/account/widgets/delete_account_action_buttons.dart';
import 'package:communal_mobile/screens/account/widgets/loan_owing_block_card.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  // Outstanding-loan gate: closure (delete or freeze) is disabled while
  // the member still owes the cooperative on an active loan. We fetch
  // the balance up front so we can swap the action footer for a blocker
  // before the user taps anything irreversible.
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

  @override
  Widget build(BuildContext context) {
    final hasOutstandingLoan = _outstandingLoanMinor > 0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemOverlayForTheme(Theme.of(context)),
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          title: Text(
            'Delete Account',
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
                        vSpace(32),
                        const DeleteAccountWarningSection(),
                        vSpace(32),
                        const _DataLossSection(),
                        vSpace(24),
                        if (hasOutstandingLoan) ...[
                          LoanOwingBlockCard(
                            outstandingMinor: _outstandingLoanMinor,
                            currency: _currency,
                          ),
                          vSpace(24),
                        ] else ...[
                          const FreezeSuggestionBox(),
                          vSpace(32),
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
                const DeleteAccountActionButtons(),
            ],
          ),
        ),
      ),
    );
  }
}

class _DataLossSection extends StatelessWidget {
  const _DataLossSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Here\'s what you\'ll lose',
          style: TextStyle(
            fontSize: 19.sp,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        vSpace(16),
        const DataLossItem(
          icon: Icons.people,
          title: 'Cooperative Memberships',
          description:
              'Every cooperative you belong to will lose you as a member',
          iconColor: Color(0xFFBA68C8), // Purple
        ),
        vSpace(12),
        const DataLossItem(
          icon: Icons.description,
          title: 'Transaction History',
          description:
              'Your full transaction history will be permanently deleted',
          iconColor: Color(0xFF42A5F5), // Blue
        ),
        vSpace(12),
        const DataLossItem(
          icon: Icons.trending_up,
          title: 'Loan Records',
          description:
              'All loan applications and repayment history will be erased',
          iconColor: Color(0xFF66BB6A), // Green
        ),
        vSpace(12),
        const DataLossItem(
          icon: Icons.shield_outlined,
          title: 'Account Balance',
          description:
              'Any balance must be transferred to another account before deletion',
          iconColor: Colors.red,
        ),
      ],
    );
  }
}
