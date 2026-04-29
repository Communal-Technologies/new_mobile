import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:communal_mobile/core/widgets/bottomsheet_handlebar.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/data/repositories/community_repository.dart';
import 'package:communal_mobile/injection.dart';

class JoinCommunityInviteSheet extends StatefulWidget {
  const JoinCommunityInviteSheet({super.key});

  @override
  State<JoinCommunityInviteSheet> createState() =>
      _JoinCommunityInviteSheetState();
}

class _JoinCommunityInviteSheetState extends State<JoinCommunityInviteSheet> {
  final TextEditingController _codeController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final raw = _codeController.text.trim();
    if (raw.isEmpty) {
      setState(() => _errorMessage = 'Please enter your invite code.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final result = await getIt<CommunityRepository>().redeemInviteCode(raw);
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
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const BottomSheetHandlebar(),
                    vSpace(8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Join Cooperative',
                        style: TextStyle(
                          fontSize: 22.sp,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F1D40),
                        ),
                      ),
                    ),
                    vSpace(6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Enter the invite code provided by your community administrator to join their cooperative.',
                        style: TextStyle(
                          fontSize: 15.sp,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                    vSpace(20),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Enter Invite Code',
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF0F1D40),
                        ),
                      ),
                    ),
                    vSpace(8),
                    TextField(
                      controller: _codeController,
                      textCapitalization: TextCapitalization.characters,
                      enabled: !_isSubmitting,
                      onChanged: (_) {
                        if (_errorMessage != null) {
                          setState(() => _errorMessage = null);
                        }
                      },
                      decoration: InputDecoration(
                        hintText: 'E.G. COOP-XXXX-XXXX',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16.r),
                          borderSide: const BorderSide(
                            color: Color(0xFFE1E1EB),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16.r),
                          borderSide: BorderSide(
                            color: _errorMessage == null
                                ? const Color(0xFF7434FF)
                                : const Color(0xFFE74C3C),
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16.r),
                          borderSide: const BorderSide(
                            color: Color(0xFFE74C3C),
                          ),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF7F7FB),
                      ),
                    ),
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
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 14.h,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3E9FF),
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(color: const Color(0xFFE2D2FF)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 24.w,
                            height: 24.w,
                            decoration: const BoxDecoration(
                              color: Color(0xFF5C45FF),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                          hSpace(12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'How to get an invite code?',
                                  style: TextStyle(
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF3F2B8F),
                                  ),
                                ),
                                vSpace(4),
                                Text(
                                  'Contact your cooperative admin to get an invite code. Each code is unique and can only be used once.',
                                  style: TextStyle(
                                    fontSize: 13.sp,
                                    color: const Color(0xFF4D3C8A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    vSpace(20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              minimumSize: Size(double.infinity, 52.h),
                              side: const BorderSide(color: Color(0xFFE0E0EC)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16.r),
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
                            onPressed: _isSubmitting ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              minimumSize: Size(double.infinity, 52.h),
                              backgroundColor: const Color(0xFF7434FF),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16.r),
                              ),
                            ),
                            child: _isSubmitting
                                ? SizedBox(
                                    width: 20.sp,
                                    height: 20.sp,
                                    child: const CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor: AlwaysStoppedAnimation(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : Text(
                                    'Join Community',
                                    style: TextStyle(
                                      fontSize: 17.sp,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),
                      ],
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
