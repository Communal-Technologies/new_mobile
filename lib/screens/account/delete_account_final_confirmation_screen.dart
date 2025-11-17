import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:communal_mobile/core/widgets/space.dart';
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

  void _handleDeleteAccount() {
    if (_canDelete) {
      // TODO: Implement final account deletion
      // Navigate to success screen
      context.pushReplacementNamed('delete-account-success');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
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
        body: SafeArea(
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
                  _buildDeleteButton(),
                  vSpace(32),
                ],
              ),
            ),
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
            color: const Color(0xFF0F1D40),
          ),
        ),
        vSpace(8),
        Text(
          'This is your last chance to cancel.',
          style: TextStyle(
            fontSize: 14.sp,
            color: Colors.grey.shade600,
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
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F1D40),
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
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF0F1D40),
            ),
            decoration: InputDecoration(
              hintText: 'Type DELETE in capital letters',
              hintStyle: TextStyle(
                fontSize: 14.sp,
                color: Colors.grey.shade500,
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
        onPressed: _canDelete ? _handleDeleteAccount : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: _canDelete
              ? const Color(0xFFFFB3BA) // Light pink
              : Colors.grey.shade300,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 16.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          elevation: 0,
          disabledBackgroundColor: Colors.grey.shade300,
          disabledForegroundColor: Colors.grey.shade600,
        ),
        child: Text(
          'Delete my Account permanently',
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

