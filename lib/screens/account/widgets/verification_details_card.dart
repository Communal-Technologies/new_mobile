import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_state.dart';
import 'package:communal_mobile/core/widgets/space.dart';

/// Verification details card on My Profile.
///
/// Status — not numbers — is what we render. The backend stores BVN/NIN
/// at Anchor (the BaaS provider); the local `kycs` table only carries
/// `anchor_customer_id` + workflow status, no masked digits. So this
/// card derives "Verified" / "Not verified" per identifier from the
/// member's KYC progress on auth state:
///
///   - BVN row → step 1 submitted OR communal tier reached tier_1/tier_2
///   - NIN row → step 2 submitted OR communal tier reached tier_2
///
/// Earlier this widget hardcoded `'68*********'` / `'22*********'` and
/// the explanatory note even claimed it was "the last 2 digits" while
/// actually masking the trailing digits — a double bug. Status badges
/// avoid both problems.
class VerificationDetailsCard extends StatelessWidget {
  const VerificationDetailsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        final user = authState is AuthAuthenticated ? authState.user : null;

        // Tier 1 in this product = BVN-verified; tier 2 = ID-verified
        // (Communal `tier_2` corresponds to Anchor TIER_3, which adds
        // government-ID NIN + selfie on top of BVN). Either step
        // submission OR the corresponding tier is enough to show as
        // verified — covers the gap where webhook re-confirmation is
        // pending but the user already submitted.
        final tier = (user?.communalTier ?? '').toLowerCase();
        final bvnVerified = (user?.kycStep1Submitted ?? false)
            || tier == 'tier_1'
            || tier == 'tier_2';
        final ninVerified = (user?.kycStep2Submitted ?? false)
            || tier == 'tier_2';

        return Container(
          margin: EdgeInsets.symmetric(horizontal: 16.w),
          padding: EdgeInsets.all(20.w),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.verified_user,
                    color: const Color(0xFF7434FF),
                    size: 20.sp,
                  ),
                  hSpace(8),
                  Text(
                    'Verification Details',
                    style: TextStyle(
                      fontSize: 19.sp,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              vSpace(20),
              _StatusRow(
                label: 'BVN (Bank Verification Number)',
                verified: bvnVerified,
              ),
              vSpace(16),
              _StatusRow(
                label: 'NIN (National Identification Number)',
                verified: ninVerified,
              ),
              vSpace(16),
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16.sp,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    hSpace(8),
                    Expanded(
                      child: Text(
                        'For your security, identifier numbers are not displayed. Verification status is shown instead.',
                        style: TextStyle(
                          fontSize: 16.sp,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final bool verified;

  const _StatusRow({
    required this.label,
    required this.verified,
  });

  @override
  Widget build(BuildContext context) {
    final color = verified ? const Color(0xFF27AE60) : const Color(0xFFE67E22);
    final text = verified ? 'Verified' : 'Not verified';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 17.sp,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                verified ? Icons.check_circle : Icons.error_outline,
                size: 14.sp,
                color: color,
              ),
              hSpace(4),
              Text(
                text,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
