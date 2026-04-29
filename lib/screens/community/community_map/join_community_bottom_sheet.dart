import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:communal_mobile/core/widgets/bottomsheet_handlebar.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/data/repositories/community_repository.dart';
import 'package:communal_mobile/injection.dart';
import 'package:communal_mobile/screens/community/data/sample_community_locations.dart';

/// Bottom sheet for the request-to-join flow (no invite code). Submits
/// to /members/join-requests and pops the resulting [CommunityJoinRequest]
/// so callers can route to the application-status screen. Pops `null` on
/// cancel/dismiss.
class JoinCommunityBottomSheet extends StatefulWidget {
  const JoinCommunityBottomSheet({super.key, required this.community});

  final CommunityLocation community;

  @override
  State<JoinCommunityBottomSheet> createState() =>
      _JoinCommunityBottomSheetState();
}

class _JoinCommunityBottomSheetState extends State<JoinCommunityBottomSheet> {
  late final TextEditingController _messageController;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      final result = await getIt<CommunityRepository>().requestToJoin(
        cooperativeId: widget.community.id,
        message: _messageController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.only(
                left: 24.w,
                right: 24.w,
                top: 12.h,
                bottom: 24.h,
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const BottomSheetHandlebar(),
                    _Header(communityName: widget.community.name),
                    vSpace(16),
                    _MessageField(controller: _messageController),
                    if (_errorMessage != null) ...[
                      vSpace(8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: const Color(0xFFE74C3C),
                          ),
                        ),
                      ),
                    ],
                    vSpace(16),
                    const _AlertCard(),
                    vSpace(16),
                    _Actions(
                      isSubmitting: _isSubmitting,
                      onCancel: () => Navigator.of(context).pop(),
                      onSubmit: _submit,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.communityName});
  final String communityName;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 64.w,
          width: 64.w,
          decoration: BoxDecoration(
            color: const Color(0xFFEDE5FF),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Icon(
            Icons.store_mall_directory_outlined,
            color: const Color(0xFF7434FF),
            size: 30.sp,
          ),
        ),
        vSpace(12),
        Text(
          'Join $communityName?',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 19.sp,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F1D40),
          ),
        ),
        vSpace(8),
        Text(
          'By joining, you agree to the community guidelines and contribution requirements.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15.sp, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}

class _MessageField extends StatelessWidget {
  const _MessageField({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Add a message (optional)',
          style: TextStyle(
            fontSize: 15.sp,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF0F1D40),
          ),
        ),
        vSpace(8),
        TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Hi, my name is ... I would like to join because...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: Color(0xFFE6E6F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: Color(0xFF7434FF)),
            ),
            filled: true,
            fillColor: const Color(0xFFF8F8FB),
          ),
        ),
      ],
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E9),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFFFD9B3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFEE7B00)),
          hSpace(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Application Review Required',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF9A4F00),
                  ),
                ),
                vSpace(4),
                Text(
                  'Your application will be reviewed by the community '
                  'coordinator. You’ll receive a response within 2-3 '
                  'business days.',
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: const Color(0xFF9A4F00),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.isSubmitting,
    required this.onCancel,
    required this.onSubmit,
  });

  final bool isSubmitting;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: onCancel,
            style: OutlinedButton.styleFrom(
              minimumSize: Size(double.infinity, 52.h),
              side: const BorderSide(color: Color(0xFFE0E0EC)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontSize: 17.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0F1D40),
              ),
            ),
          ),
        ),
        hSpace(12),
        Expanded(
          child: ElevatedButton(
            onPressed: isSubmitting ? null : onSubmit,
            style: ElevatedButton.styleFrom(
              minimumSize: Size(double.infinity, 52.h),
              backgroundColor: const Color(0xFF7434FF),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
            child: isSubmitting
                ? SizedBox(
                    height: 20.sp,
                    width: 20.sp,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : Text(
                    'Submit Request',
                    style: TextStyle(
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
