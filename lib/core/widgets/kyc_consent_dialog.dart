import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class KycConsentDialog extends StatelessWidget {
  const KycConsentDialog({
    super.key,
    required this.onAgree,
    required this.onDecline,
  });

  final VoidCallback onAgree;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: theme.colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      insetPadding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 40.h),
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Identity data sharing consent',
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
            SizedBox(height: 12.h),
            Text(
              'To verify your identity, Communal will share the following personal '
              'data with Anchor — a CBN-licensed Payment Service Provider (PSP) and '
              'International Money Transfer Operator (IMTO):\n\n'
              '• Bank Verification Number (BVN)\n'
              '• Date of birth\n'
              '• Gender\n'
              '• Government-issued identity document\n\n'
              'Anchor uses this data solely to verify your identity and comply with '
              'Central Bank of Nigeria (CBN) Know Your Customer (KYC) requirements. '
              'Your data is processed in Nigeria under Anchor\'s CBN licence and the '
              'Nigerian Data Protection Act 2023.',
              style: TextStyle(
                fontSize: 15.sp,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                height: 1.5,
              ),
            ),
            SizedBox(height: 24.h),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onDecline,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.onSurface,
                      side: BorderSide(
                        color: isDark
                            ? theme.colorScheme.outline
                            : theme.colorScheme.outline.withValues(alpha: 0.5),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                    ),
                    child: Text(
                      'Decline',
                      style: TextStyle(fontSize: 16.sp),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: onAgree,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                    ),
                    child: Text(
                      'I Agree',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
