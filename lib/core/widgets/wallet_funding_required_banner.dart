import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:iconsax/iconsax.dart';

/// A persistent amber banner shown on wallet-funded action screens (transfers,
/// bill payments, and the wallet/NIP option on loan/obligation/fine payments)
/// when the member does not yet have a provisioned wallet with a spendable
/// balance. The banner blocks the action button below while still letting the
/// member read the screen. Obligation-funded payments are unaffected.
class WalletFundingRequiredBanner extends StatelessWidget {
  const WalletFundingRequiredBanner({super.key, this.title, this.message});

  /// Optional override for the heading (e.g. to state a different blocker
  /// such as a missing transaction PIN).
  final String? title;

  /// Optional override for the body text (e.g. to tailor per screen).
  final String? message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF3D2600) : const Color(0xFFFFF3CD),
        border: Border.all(
          color: isDark ? const Color(0xFF7D4E00) : const Color(0xFFFFD466),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Iconsax.wallet_minus, size: 20.w, color: const Color(0xFFD97706)),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title ?? 'Wallet not funded',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? const Color(0xFFFFD466)
                        : const Color(0xFF92400E),
                  ),
                ),
                SizedBox(height: 3.h),
                Text(
                  message ??
                      'You need a funded Communal wallet to make this payment. '
                          'Fund your wallet to continue.',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: isDark
                        ? const Color(0xFFFFD466).withValues(alpha: 0.85)
                        : const Color(0xFF78350F),
                    height: 1.4,
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
