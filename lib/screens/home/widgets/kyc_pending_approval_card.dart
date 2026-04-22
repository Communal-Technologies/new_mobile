import 'dart:async';

import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:communal_mobile/core/widgets/space.dart';

/// Shown on home when Tier 1+ is applied but the virtual wallet account number
/// is not yet available (Anchor webhooks / provisioning in progress).
///
/// Periodically refreshes the logged-in user so the UI can switch to the wallet
/// card as soon as the backend has provisioned the account.
class KycPendingApprovalCard extends StatefulWidget {
  const KycPendingApprovalCard({super.key});

  static const Color _messageBg = Color(0xFFFBF0C9);

  @override
  State<KycPendingApprovalCard> createState() => _KycPendingApprovalCardState();
}

class _KycPendingApprovalCardState extends State<KycPendingApprovalCard> {
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AuthBloc>().add(AuthRefreshUserRequested());
    });
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted) return;
      context.read<AuthBloc>().add(AuthRefreshUserRequested());
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0F5),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44.w,
                height: 44.w,
                decoration: const BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.error_outline,
                  color: Colors.white,
                  size: 26.sp,
                ),
              ),
              hSpace(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'KYC PENDING APPROVAL',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          vSpace(12),
          DecoratedBox(
            decoration: BoxDecoration(
              color: KycPendingApprovalCard._messageBg,
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 12.h),
              child: Text(
                'Thanks, we\'ve received your documents. Our team will review them '
                'and update your account shortly. Expected review time: 1–3 business days.',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: Colors.black87,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
