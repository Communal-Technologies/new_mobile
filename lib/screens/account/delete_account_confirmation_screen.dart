import 'package:flutter/material.dart';
import 'package:communal_mobile/core/utils/system_ui_style.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/screens/account/widgets/account_to_delete_card.dart';
import 'package:communal_mobile/screens/account/widgets/balance_card.dart';
import 'package:communal_mobile/screens/account/widgets/outstanding_balance_warning.dart';
import 'package:communal_mobile/screens/account/widgets/delete_agreement_item.dart';

class DeleteAccountConfirmationScreen extends StatefulWidget {
  const DeleteAccountConfirmationScreen({super.key});

  @override
  State<DeleteAccountConfirmationScreen> createState() =>
      _DeleteAccountConfirmationScreenState();
}

class _DeleteAccountConfirmationScreenState
    extends State<DeleteAccountConfirmationScreen> {
  bool _agreement1 = false;
  bool _agreement2 = false;
  bool _agreement3 = false;
  bool _agreement4 = false;

  bool get _allAgreementsAccepted =>
      _agreement1 && _agreement2 && _agreement3 && _agreement4;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemOverlayForTheme(Theme.of(context)),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).cardColor,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          title: Text(
            'Delete Account',
            style: TextStyle(
              fontSize: 19.sp,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              vSpace(24),
              _buildWarningIcon(),
              vSpace(24),
              _buildConfirmationQuestion(),
              vSpace(24),
              const AccountToDeleteCard(
                name: 'Pado Lebari',
                email: 'pado.lebari@example.com',
                accountNumber: '7037334888',
                memberSince: 'January 2024',
                avatarInitials: 'PL',
              ),
              vSpace(16),
              BalanceCard(
                balance: 450000000000,
                // Account closure can't proceed while there's a balance.
                // Send the user into the in-app transfer flow so they
                // can move funds to another internal account or to an
                // external bank — *not* a withdrawal step that doesn't
                // exist.
                onWithdraw: () {
                  context.pushNamed('transfer');
                },
              ),
              vSpace(16),
              const OutstandingBalanceWarning(
                balance: 450000000000,
              ),
              vSpace(24),
              _buildAgreementSection(),
              vSpace(24),
              _buildDeleteButton(context),
              vSpace(32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWarningIcon() {
    return Center(
      child: Icon(
        Icons.delete_outline,
        color: Colors.red,
        size: 60.sp,
      ),
    );
  }

  Widget _buildConfirmationQuestion() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Text(
        'Are you sure you want to Delete your Account?',
        style: TextStyle(
          fontSize: 19.sp,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildAgreementSection() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Agree to continue',
            style: TextStyle(
              fontSize: 17.sp,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          vSpace(16),
          DeleteAgreementItem(
            text:
                'Once deleted, your account cannot be recovered or reactivated. You\'ll need to create a new account to use our services again.',
            value: _agreement1,
            onChanged: (value) => setState(() => _agreement1 = value),
          ),
          vSpace(12),
          DeleteAgreementItem(
            text:
                'Your transaction history, loan records, cooperative memberships, and all personal data will be permanently deleted within 30 days.',
            value: _agreement2,
            onChanged: (value) => setState(() => _agreement2 = value),
          ),
          vSpace(12),
          DeleteAgreementItem(
            text:
                'You\'ll be removed from all 2 cooperatives and lose access to shared funds, contributions, and benefits.',
            value: _agreement3,
            onChanged: (value) => setState(() => _agreement3 = value),
          ),
          vSpace(12),
          DeleteAgreementItem(
            text:
                'Any pending obligations, loans, or cooperative commitments must be settled before deletion. No refunds will be issued.',
            value: _agreement4,
            onChanged: (value) => setState(() => _agreement4 = value),
          ),
        ],
      ),
    );
  }

  Widget _buildDeleteButton(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _allAgreementsAccepted
              ? () {
                  _showFinalConfirmationDialog(context);
                }
              : null,
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith<Color>(
              (Set<WidgetState> states) {
                if (states.contains(WidgetState.disabled)) {
                  return Colors.grey.shade300;
                }
                return const Color(0xFFFFB3BA); // Light pink when enabled
              },
            ),
            foregroundColor: WidgetStateProperty.resolveWith<Color>(
              (Set<WidgetState> states) {
                if (states.contains(WidgetState.disabled)) {
                  return Colors.grey.shade600;
                }
                return Colors.white;
              },
            ),
            padding: WidgetStateProperty.all(
              EdgeInsets.symmetric(vertical: 16.h),
            ),
            shape: WidgetStateProperty.all(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
            elevation: WidgetStateProperty.all(0),
          ),
          child: Text(
            'I understand, Delete my Account',
            style: TextStyle(
              fontSize: 17.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  void _showFinalConfirmationDialog(BuildContext context) {
    context.pushNamed('delete-account-feedback');
  }
}

