import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_state.dart';
import 'package:communal_mobile/core/navigation/kyc_resume.dart';
import 'package:communal_mobile/core/utils/currency_formatter.dart';
import 'package:communal_mobile/data/models/user_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:communal_mobile/core/widgets/space.dart';

class ProfileCard extends StatefulWidget {
  const ProfileCard({super.key});

  @override
  State<ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<ProfileCard> {
  bool _isBalanceVisible = true;

  String _tierChipLabel(UserModel u) {
    final tl = u.tierLimits?.current;
    if (tl != null) {
      return tl.displayTierTitle;
    }
    final t = u.communalTier?.trim().toLowerCase();
    if (t == 'tier_1') return 'Tier 1';
    if (t == 'tier_2') return 'Tier 2';
    return 'Verification';
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      buildWhen: (prev, next) {
        final pu = prev is AuthAuthenticated ? prev.user : null;
        final nu = next is AuthAuthenticated ? next.user : null;
        return pu != nu;
      },
      builder: (context, authState) {
        if (authState is! AuthAuthenticated) {
          return SizedBox(height: 120.h);
        }
        final user = authState.user;
        final showUpgradeChip = user.tierLimits?.isFullyVerified != true;
        final displayName =
            user.name.trim().isNotEmpty ? user.name.trim() : 'Member';
        final balanceText =
            CurrencyFormatter.formatNairaFromKobo(user.walletBalanceKobo);
        final avatar = user.avatar;
        final ImageProvider<Object> avatarImage = (avatar != null &&
                (avatar.startsWith('http://') || avatar.startsWith('https://')))
            ? NetworkImage(avatar)
            : const AssetImage('assets/images/demo_user.png');

        return GestureDetector(
          onTap: () {
            context.pushNamed('my-profile');
          },
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 16.w),
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              color: const Color(0xFF7434FF),
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30.r,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  backgroundImage: avatarImage,
                ),
                hSpace(16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: TextStyle(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      vSpace(8),
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 10.w, vertical: 4.h),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            child: Text(
                              _tierChipLabel(user),
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          if (showUpgradeChip) ...[
                            hSpace(8),
                            GestureDetector(
                              onTap: () {
                                pushKycResumeRoute(context);
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 10.w, vertical: 4.h),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                child: Text(
                                  'Upgrade account',
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      vSpace(12),
                      Row(
                        children: [
                          Text(
                            'Total Balance',
                            style: TextStyle(
                              fontSize: 15.sp,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                          hSpace(8),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _isBalanceVisible = !_isBalanceVisible;
                              });
                            },
                            child: Icon(
                              _isBalanceVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: Colors.white,
                              size: 20.sp,
                            ),
                          ),
                        ],
                      ),
                      vSpace(4),
                      Text(
                        _isBalanceVisible ? balanceText : '••••••',
                        style: TextStyle(
                          fontSize: 26.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                hSpace(12),
                Column(
                  children: [
                    Container(
                      width: 50.w,
                      height: 50.w,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.shield_outlined,
                        color: Colors.white,
                        size: 26.sp,
                      ),
                    ),
                    vSpace(8),
                    Icon(
                      Icons.chevron_right,
                      color: Colors.white,
                      size: 22.sp,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
