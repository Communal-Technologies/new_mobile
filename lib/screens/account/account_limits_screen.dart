import 'package:flutter/material.dart';
import 'package:communal_mobile/core/utils/system_ui_style.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_state.dart';
import 'package:communal_mobile/core/navigation/kyc_resume.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/data/models/tier_limits_model.dart';
import 'package:communal_mobile/screens/account/widgets/kyc_current_tier_card.dart';
import 'package:communal_mobile/screens/account/widgets/kyc_tier_info_card.dart';

class AccountLimitsScreen extends StatelessWidget {
  const AccountLimitsScreen({super.key});

  static String _norm(String? value) => value?.trim().toLowerCase() ?? '';

  /// A submission is with the verification provider and awaiting a decision.
  ///
  /// Bare `pending` is deliberately absent: the KYC record is created with that
  /// status the moment profile information is registered, long before anything
  /// has been submitted for review. Treating it as "pending review" showed
  /// members a Pending badge against a tier they had not started.
  static bool _isAwaitingReviewStatus(String? value) {
    final s = _norm(value);
    return s == 'tier2_submitted' ||
        s == 'awaitingdocument' ||
        s == 'awaiting_document' ||
        s == 'pending_review' ||
        s == 'pending.manual.review';
  }

  static String _effectiveKycStatus({
    required String? profileKycStatus,
    required String? workflowStatus,
    required bool step3Submitted,
  }) {
    final workflow = _norm(workflowStatus);
    if (workflow.isNotEmpty) return workflow;
    final profile = _norm(profileKycStatus);
    if (profile.isNotEmpty) return profile;
    if (step3Submitted) return 'tier2_submitted';
    return '';
  }

  static bool _isRejectedStatus(String? value) {
    final s = _norm(value);
    return s == 'rejected' || s == 'reenter_information' || s == 'error';
  }

  /// Fallback if API omits `requirements` (older clients).
  static List<String> _requirementsFallback(String tierKey) {
    switch (tierKey) {
      case 'tier_1':
        return [
          'Complete profile and bank details',
          'BVN verification',
        ];
      case 'tier_2':
        return [
          'Government-issued ID (NIN, passport, driver\'s license, etc.)',
        ];
      default:
        return [];
    }
  }

  static int _tierNum(String tierKey) {
    final m = RegExp(r'^tier_(\d+)$').firstMatch(tierKey);
    if (m != null) {
      return int.tryParse(m.group(1)!) ?? 0;
    }
    return 0;
  }

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
            'Account limits',
            style: TextStyle(
              fontSize: 22.sp,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          centerTitle: true,
        ),
        body: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            if (state is! AuthAuthenticated) {
              return Center(
                child: Padding(
                  padding: EdgeInsets.all(24.w),
                  child: Text(
                    'Sign in to view your account limits and verification status.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 19.sp, color: Colors.grey.shade700),
                  ),
                ),
              );
            }

            final u = state.user;
            final tl = u.tierLimits ??
                TierLimitsSnapshot(
                  catalog: const [],
                  current: TierCurrent.fallback(),
                );

            final catalog = List<TierCatalogEntry>.from(tl.catalog)
              ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

            final nextKey = tl.nextTierKey;
            final kycStatus = _effectiveKycStatus(
              profileKycStatus: u.kycStatus,
              workflowStatus: u.kycWorkflowStatus,
              step3Submitted: u.kycStep3Submitted,
            );
            final awaitingReview = _isAwaitingReviewStatus(kycStatus);
            final rejected = _isRejectedStatus(kycStatus);
            // A pending or rejected submission belongs to the tier the member is
            // being assessed for, which is whichever tier comes next — not
            // always tier 2.
            final statusTierKey = awaitingReview || rejected ? nextKey : null;
            final onResume = (nextKey != null && !awaitingReview)
                ? () => pushKycResumeRoute(context)
                : null;

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  vSpace(16),
                  KycCurrentTierCard(
                    current: tl.current,
                    nextTierKey: nextKey,
                    onContinueVerification: onResume,
                    disableUpgrade: awaitingReview,
                    upgradeButtonLabel:
                        awaitingReview ? 'Submitted - pending review' : null,
                  ),
                  if (rejected) ...[
                    vSpace(16),
                    _buildRejectionNotice(
                      context,
                      reason: u.kycRejectionMessage,
                      onResubmit: onResume,
                    ),
                  ],
                  vSpace(24),
                  _buildKycBenefitSection(context),
                  vSpace(16),
                  if (catalog.isEmpty)
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      child: Text(
                        'Tier limits will appear here after your profile syncs with the server.',
                        style: TextStyle(
                          fontSize: 19.sp,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    )
                  else
                    ...catalog.map((e) {
                      final n = _tierNum(e.tierKey);
                      if (n == 0) return const SizedBox.shrink();
                      final req = e.requirements.isNotEmpty
                          ? e.requirements
                          : _requirementsFallback(e.tierKey);
                      return Padding(
                        padding: EdgeInsets.only(bottom: 12.h),
                        child: KycTierInfoCard(
                          tier: n,
                          dailyLimitKobo: e.dailyTransactionLimitKobo,
                          maxBalanceKobo: e.maxBalanceKobo,
                          requirements: req,
                          isCurrent: e.tierKey == tl.current.tierKey,
                          statusBadgeLabel: e.tierKey == statusTierKey
                              ? (awaitingReview
                                  ? 'Pending'
                                  : (rejected ? 'Rejected' : null))
                              : null,
                          statusBadgeBgColor: e.tierKey == statusTierKey
                              ? (awaitingReview
                                  ? const Color(0xFF3E267F)
                                  : (rejected
                                      ? const Color(0xFF7A1E1E)
                                      : null))
                              : null,
                          statusBadgeColor: Colors.white,
                        ),
                      );
                    }),
                  vSpace(32),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Shown when the last submission was turned down, with the provider's own
  /// wording where it gave one. Without this the member sees only a tier badge
  /// and has no way to learn what to correct.
  Widget _buildRejectionNotice(
    BuildContext context, {
    required String? reason,
    required VoidCallback? onResubmit,
  }) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: const Color(0xFF7A1E1E).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: const Color(0xFF7A1E1E).withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline, size: 20.sp, color: const Color(0xFF7A1E1E)),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    'Your verification was not approved',
                    style: TextStyle(
                      fontSize: 19.sp,
                      fontWeight: FontWeight.w600,
                      color: onSurface,
                    ),
                  ),
                ),
              ],
            ),
            vSpace(8),
            Text(
              reason ??
                  'Please review the details you submitted and try again. Your name, '
                      'date of birth and phone number must match your BVN records exactly.',
              style: TextStyle(
                fontSize: 18.sp,
                height: 1.4,
                color: onSurface.withValues(alpha: 0.75),
              ),
            ),
            if (onResubmit != null) ...[
              vSpace(12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: onResubmit,
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFF742CE7),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                  ),
                  child: Text(
                    'Update my details',
                    style: TextStyle(fontSize: 19.sp, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildKycBenefitSection(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Verification levels',
            style: TextStyle(
              fontSize: 19.sp,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          vSpace(4),
          Text(
            'Higher verification unlocks higher daily transaction and balance limits.',
            style: TextStyle(
              fontSize: 19.sp,
              height: 1.4,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
