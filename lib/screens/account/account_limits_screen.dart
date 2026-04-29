import 'package:flutter/material.dart';
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

  static bool _isTier2PendingStatus(String? value) {
    final s = _norm(value);
    return s == 'tier2_submitted' ||
        s == 'awaitingdocument' ||
        s == 'pending_review' ||
        s == 'pending.manual.review' ||
        s == 'pending';
  }

  static String _effectiveTier2Status({
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

  static bool _isTier2RejectedStatus(String? value) {
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
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).cardColor,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
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
                    style: TextStyle(fontSize: 17.sp, color: Colors.grey.shade700),
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
            final tier2Status = _effectiveTier2Status(
              profileKycStatus: u.kycStatus,
              workflowStatus: u.kycWorkflowStatus,
              step3Submitted: u.kycStep3Submitted,
            );
            final tier2Pending =
                _isTier2PendingStatus(tier2Status);
            final tier2Rejected =
                _isTier2RejectedStatus(tier2Status);
            final onResume =
                (nextKey != null && !tier2Pending)
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
                    disableUpgrade: tier2Pending,
                    upgradeButtonLabel:
                        tier2Pending ? 'Submitted - pending review' : null,
                    statusBadgeLabel: tier2Pending
                        ? 'Pending'
                        : (tier2Rejected ? 'Rejected' : null),
                    statusBadgeBgColor: tier2Pending
                        ? const Color(0xFF3E267F)
                        : (tier2Rejected ? const Color(0xFF7A1E1E) : null),
                    statusBadgeColor: Colors.white,
                  ),
                  vSpace(24),
                  _buildKycBenefitSection(),
                  vSpace(16),
                  if (catalog.isEmpty)
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      child: Text(
                        'Tier limits will appear here after your profile syncs with the server.',
                        style: TextStyle(
                          fontSize: 17.sp,
                          color: Colors.grey.shade600,
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
                          statusBadgeLabel: e.tierKey == 'tier_2'
                              ? (tier2Pending
                                  ? 'Pending'
                                  : (tier2Rejected ? 'Rejected' : null))
                              : null,
                          statusBadgeBgColor: e.tierKey == 'tier_2'
                              ? (tier2Pending
                                  ? const Color(0xFF3E267F)
                                  : (tier2Rejected
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

  Widget _buildKycBenefitSection() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Verification levels',
            style: TextStyle(
              fontSize: 17.sp,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          vSpace(4),
          Text(
            'Higher verification unlocks higher daily transaction and balance limits.',
            style: TextStyle(
              fontSize: 17.sp,
              height: 1.4,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
