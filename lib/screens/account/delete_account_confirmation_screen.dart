import 'package:flutter/material.dart';
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
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => context.pop(),
          ),
          title: Text(
            'Delete Account',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: Colors.black,
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
                onWithdraw: () {
                  // TODO: Navigate to withdraw funds
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Navigate to withdraw funds')),
                  );
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
          fontSize: 18.sp,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF0F1D40),
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
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F1D40),
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
              fontSize: 16.sp,
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

