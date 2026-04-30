import 'package:flutter/material.dart';
import 'package:communal_mobile/core/utils/system_ui_style.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/screens/account/widgets/delete_reason_item.dart';
import 'package:communal_mobile/screens/account/widgets/feedback_info_box.dart';

class DeleteAccountFeedbackScreen extends StatefulWidget {
  const DeleteAccountFeedbackScreen({super.key});

  @override
  State<DeleteAccountFeedbackScreen> createState() =>
      _DeleteAccountFeedbackScreenState();
}

class _DeleteAccountFeedbackScreenState
    extends State<DeleteAccountFeedbackScreen> {
  String? _selectedReason;
  final TextEditingController _feedbackController = TextEditingController();

  final List<String> _reasons = [
    'Not using the app anymore',
    'Privacy concerns',
    'Switching to another service',
    'Too many notifications',
    'App is difficult to use',
    'High fees/charges',
    'Other reason',
  ];

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
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
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  vSpace(32),
                  _buildHeader(),
                  vSpace(32),
                  _buildReasonSection(),
                  vSpace(24),
                  _buildFeedbackSection(),
                  vSpace(24),
                  const FeedbackInfoBox(),
                  vSpace(32),
                  _buildContinueButton(context),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Help Us Improve',
          style: TextStyle(
            fontSize: 24.sp,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        vSpace(8),
        Text(
          'We\'d love to know why you\'re leaving.',
          style: TextStyle(
            fontSize: 17.sp,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
          'Why are you deleting your account?',
          style: TextStyle(
            fontSize: 19.sp,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        vSpace(16),
        ..._reasons.map((reason) => Padding(
              padding: EdgeInsets.only(bottom: 12.h),
              child: DeleteReasonItem(
                reason: reason,
                isSelected: _selectedReason == reason,
                onTap: () {
                  setState(() => _selectedReason = reason);
                },
              ),
            )),
      ],
    );
  }

  Widget _buildFeedbackSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Additional feedback (optional)',
          style: TextStyle(
            fontSize: 19.sp,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
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
            controller: _feedbackController,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: 'Tell us more about your experience...',
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

  Widget _buildContinueButton(BuildContext context) {
    final isEnabled = _selectedReason != null;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isEnabled
            ? () {
                // TODO: Submit feedback and proceed with deletion
                _submitFeedback(context);
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
          'Verify and Continue',
          style: TextStyle(
            fontSize: 19.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _submitFeedback(BuildContext context) {
    // TODO: Submit feedback to backend
    // Navigate to PIN verification screen
    context.pushNamed('delete-account-pin');
  }
}

