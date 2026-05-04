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

  /// Same family as KYC transactional callouts — clearly “pending”, not error (red).
  static const Color _cardBg = Color(0xFFFBF0C9);

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
      constraints: BoxConstraints(minHeight: 132.h),
      padding: EdgeInsets.fromLTRB(18.w, 22.h, 18.w, 24.h),
      decoration: BoxDecoration(
        color: KycPendingApprovalCard._cardBg,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFE6D9A8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 30.w,
                height: 30.w,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(6.r),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.error_outline,
                  color: Colors.white,
                  size: 17.sp,
                ),
              ),
              hSpace(12),
              Expanded(
                child: Text(
                  'KYC PENDING APPROVAL',
                  style: TextStyle(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A1A1A),
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
          vSpace(14),
          Text(
            'Thanks, we\'ve received your documents. Our team will review them '
            'and update your account shortly. Expected review time: 1–3 business days.',
            textAlign: TextAlign.start,
            style: TextStyle(
              fontSize: 19.sp,
              color: const Color(0xFF1A1A1A).withValues(alpha: 0.7),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
