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
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => context.pop(),
          ),
          title: Text(
            'Account limits',
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.w700,
              color: Colors.black,
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
                    style: TextStyle(fontSize: 16.sp, color: Colors.grey.shade700),
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
            final onResume =
                nextKey != null ? () => pushKycResumeRoute(context) : null;

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  vSpace(16),
                  KycCurrentTierCard(
                    current: tl.current,
                    nextTierKey: nextKey,
                    onContinueVerification: onResume,
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
                          fontSize: 15.sp,
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
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          vSpace(4),
          Text(
            'Higher verification unlocks higher daily transaction and balance limits.',
            style: TextStyle(
              fontSize: 15.sp,
              height: 1.4,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
