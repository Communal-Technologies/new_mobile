import 'package:flutter/material.dart';
import 'package:communal_mobile/core/utils/system_ui_style.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_state.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/data/repositories/account_actions_repository.dart';
import 'package:communal_mobile/injection.dart';
import 'package:communal_mobile/screens/account/widgets/final_warning_box.dart';
import 'package:communal_mobile/screens/account/widgets/cancel_deletion_box.dart';

class DeleteAccountFinalConfirmationScreen extends StatefulWidget {
  const DeleteAccountFinalConfirmationScreen({super.key});

  @override
  State<DeleteAccountFinalConfirmationScreen> createState() =>
      _DeleteAccountFinalConfirmationScreenState();
}

class _DeleteAccountFinalConfirmationScreenState
    extends State<DeleteAccountFinalConfirmationScreen> {
  final TextEditingController _deleteController = TextEditingController();
  bool _canDelete = false;

  @override
  void initState() {
    super.initState();
    _deleteController.addListener(_checkDeleteInput);
  }

  @override
  void dispose() {
    _deleteController.removeListener(_checkDeleteInput);
    _deleteController.dispose();
    super.dispose();
  }

  void _checkDeleteInput() {
    final value = _deleteController.text.trim();
    setState(() {
      _canDelete = value == 'DELETE';
    });
  }

  bool _submitting = false;

  Future<void> _handleDeleteAccount() async {
    if (!_canDelete || _submitting) return;
    final auth = context.read<AuthBloc>().state;
    final cooperativeId = auth is AuthAuthenticated
        ? (auth.user.cooperativeId?.trim() ?? '')
        : '';
    if (cooperativeId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No cooperative selected.'),
          backgroundColor: Color(0xFFD32F2F),
        ),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      // Account closure isn't instant — submitting creates a pending
      // request that the cooperative admin reviews. The backend
      // snapshots the user's debts/EPC at submit time so an admin
      // approving later still sees the values the member saw.
      await getIt<AccountActionsRepository>()
          .submitAccountClosure(cooperativeId: cooperativeId);
      if (!mounted) return;
      context.pushReplacementNamed('delete-account-success');
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: const Color(0xFFD32F2F),
        ),
      );
    }
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
            'Delete Account',
            style: TextStyle(
              fontSize: 19.sp,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
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
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        vSpace(32),
                        _buildHeader(),
                        vSpace(32),
                        const FinalWarningBox(),
                        vSpace(24),
                        _buildDeleteInputSection(),
                        vSpace(24),
                        const CancelDeletionBox(),
                        vSpace(32),
                      ],
                    ),
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
                child: _buildDeleteButton(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 80.w,
          height: 80.w,
          decoration: BoxDecoration(
            color: const Color(0xFFD32F2F), // Red
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: const Icon(
            Icons.delete_outline,
            color: Colors.white,
            size: 50,
          ),
        ),
        vSpace(24),
        Text(
          'Final Confirmation',
          style: TextStyle(
            fontSize: 24.sp,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        vSpace(8),
        Text(
          'This is your last chance to cancel.',
          style: TextStyle(
            fontSize: 17.sp,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildDeleteInputSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: 19.sp,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            children: [
              const TextSpan(text: 'Type '),
              TextSpan(
                text: 'DELETE',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const TextSpan(text: ' to confirm'),
            ],
          ),
        ),
        vSpace(12),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: TextField(
            controller: _deleteController,
            textCapitalization: TextCapitalization.characters,
            style: TextStyle(
              fontSize: 19.sp,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            decoration: InputDecoration(
              hintText: 'Type DELETE in capital letters',
              hintStyle: TextStyle(
                fontSize: 17.sp,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(16.w),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDeleteButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: (_canDelete && !_submitting) ? _handleDeleteAccount : null,
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
        child: _submitting
            ? SizedBox(
                height: 18.sp,
                width: 18.sp,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : Text(
                'Delete my Account permanently',
                style: TextStyle(
                  fontSize: 19.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}

