import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_state.dart';
import 'package:communal_mobile/core/navigation/kyc_resume.dart';
import 'package:communal_mobile/core/utils/currency_formatter.dart';
import 'package:communal_mobile/data/local/home_wallet_prefs.dart';
import 'package:communal_mobile/data/models/user_model.dart';
import 'package:communal_mobile/injection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:communal_mobile/core/widgets/member_avatar.dart';
import 'package:communal_mobile/core/widgets/space.dart';

class ProfileCard extends StatefulWidget {
  const ProfileCard({super.key});

  @override
  State<ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<ProfileCard> {
  // Visibility lives in the shared HomeWalletPrefs singleton (a ChangeNotifier)
  // so toggling here propagates to the home dashboard card and any other surface
  // that listens to the same notifier.

  /// Tier at a glance — "Tier 1", "Verification pending" or "Not verified".
  String _tierStatusLabel(UserModel u) {
    final tl = u.tierLimits?.current;
    if (tl != null) {
      if (tl.tierKey == 'tier_1' || tl.tierKey == 'tier_2') {
        return tl.displayTierTitle;
      }
      final lab = tl.label.trim();
      if (lab.isNotEmpty) return lab;
    }
    final t = u.communalTier?.trim().toLowerCase();
    if (t == 'tier_1') return 'Tier 1';
    if (t == 'tier_2') return 'Tier 2';
    if (u.kycStep1Submitted) return 'Verification pending';
    return 'Not verified';
  }

  /// Action pill: "Verify account" before Tier 1, "Upgrade account" for Tier 1 → 2.
  String _upgradeLabel(UserModel u) {
    final tl = u.tierLimits?.current;
    final tier = tl?.tierKey ?? u.communalTier?.trim().toLowerCase();
    return tier == 'tier_1' ? 'Upgrade account' : 'Verify account';
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      buildWhen: (prev, next) {
        if (next is! AuthAuthenticated) {
          return next is AuthUnauthenticated && prev is AuthAuthenticated;
        }
        if (prev is! AuthAuthenticated) return true;
        return prev.user != next.user ||
            prev.sessionGeneration != next.sessionGeneration;
      },
      builder: (context, authState) {
        if (authState is! AuthAuthenticated) {
          return SizedBox(height: 120.h);
        }
        final user = authState.user;
        final prefs = getIt<HomeWalletPrefs>();

        final tierStr = user.communalTier?.trim().toLowerCase();
        final isRealTier = tierStr == 'tier_1' || tierStr == 'tier_2';
        final kycPending = !isRealTier && user.kycStep1Submitted;
        // The action pill shows only when there is something to do and KYC is not
        // already in review (which would read as two conflicting states).
        final showUpgrade =
            !kycPending && user.tierLimits?.isFullyVerified != true;

        final displayName =
            user.name.trim().isNotEmpty ? user.name.trim() : 'Member';
        final balanceText = CurrencyFormatter.formatNairaFromKoboWithDecimals(
            user.walletBalanceKobo);

        return GestureDetector(
          onTap: () => context.pushNamed('my-profile'),
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 16.w),
            padding: EdgeInsets.all(18.w),
            decoration: BoxDecoration(
              color: const Color(0xFF7434FF),
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Identity row: avatar, name + "View profile" affordance, tier ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    MemberAvatar(
                      url: user.avatar,
                      radius: 22.r,
                      name: displayName,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                    ),
                    hSpace(12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _FittedName(
                            fullName: displayName,
                            style: TextStyle(
                              fontSize: 20.sp,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          vSpace(2),
                          // Makes the whole card's tap target legible: this card
                          // opens the profile, which the old design did not signal.
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'View profile',
                                style: TextStyle(
                                  fontSize: 15.sp,
                                  color: Colors.white.withValues(alpha: 0.85),
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                size: 16.sp,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    hSpace(8),
                    _TierChip(label: _tierStatusLabel(user)),
                  ],
                ),

                vSpace(18),

                // ── Balance ──────────────────────────────────────────────────
                AnimatedBuilder(
                  animation: prefs,
                  builder: (context, _) {
                    final visible = prefs.isBalanceVisible(user.id);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Total Balance',
                              style: TextStyle(
                                fontSize: 16.sp,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            ),
                            hSpace(8),
                            GestureDetector(
                              onTap: () =>
                                  prefs.setBalanceVisible(user.id, !visible),
                              child: Icon(
                                visible
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
                          visible ? balanceText : '••••••',
                          style: TextStyle(
                            fontSize: 26.sp,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    );
                  },
                ),

                // ── Verify / upgrade action (separate tap from the card) ─────
                if (showUpgrade) ...[
                  vSpace(14),
                  GestureDetector(
                    onTap: () => pushKycResumeRoute(context),
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: 10.h),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(10.r),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        _upgradeLabel(user),
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The member's name on one line. When the full name would not fit, the middle
/// name(s) collapse to an initial and a dot ("John M. Doe") rather than wrapping;
/// ellipsis is the last resort when even that overflows.
class _FittedName extends StatelessWidget {
  const _FittedName({required this.fullName, required this.style});

  final String fullName;
  final TextStyle style;

  String _compact(String full) {
    final parts = full.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length < 3) return full;
    final middles = parts
        .sublist(1, parts.length - 1)
        .where((m) => m.isNotEmpty)
        .map((m) => '${m.substring(0, 1).toUpperCase()}.')
        .join(' ');
    return '${parts.first} $middles ${parts.last}';
  }

  bool _fits(String text, double maxWidth, TextScaler scaler) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout();
    return tp.width <= maxWidth;
  }

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final text = _fits(fullName, constraints.maxWidth, scaler)
            ? fullName
            : _compact(fullName);
        return Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style,
        );
      },
    );
  }
}

class _TierChip extends StatelessWidget {
  const _TierChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13.sp,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}
