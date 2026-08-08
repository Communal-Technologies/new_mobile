import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/data/models/bills/bill_customer.dart';

/// Tint used for a resolved meter/smartcard, matching the verified-recipient
/// card on the external transfer screen.
const Color _verifiedGreen = Color(0xFF0FAA50);

/// Shared text-field decoration used across the bill-payment form
/// screens. Lives here so the dark-mode fix (theme-aware fill +
/// borders) doesn't need to be re-applied in 4 places when the design
/// shifts.
InputDecoration billInputDecoration(BuildContext context, String hint) {
  final theme = Theme.of(context);
  return InputDecoration(
    hintText: hint,
    filled: true,
    // Theme-aware: stays light grey on light, sits on the surface
    // container in dark mode instead of glowing white.
    fillColor: theme.colorScheme.surfaceContainerHighest,
    hintStyle: TextStyle(
      color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
    ),
    contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14.r),
      borderSide: BorderSide(color: theme.dividerColor),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14.r),
      borderSide: BorderSide(color: theme.dividerColor),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14.r),
      borderSide: const BorderSide(color: Color(0xFF7434FF), width: 1.5),
    ),
  );
}

/// The resolved customer shown under a meter/smartcard field once Anchor
/// validates it.
///
/// A fixed `Colors.green.shade50` fill was near-white, so in dark mode the
/// `onSurface` name on top of it was white-on-white and the whole card read as
/// blank. The green is applied as a translucent tint instead, which keeps the
/// contrast in both modes.
Widget billCustomerCard(BuildContext context, BillCustomer customer) {
  final theme = Theme.of(context);
  return Container(
    width: double.infinity,
    padding: EdgeInsets.all(14.w),
    decoration: BoxDecoration(
      color: _verifiedGreen.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12.r),
      border: Border.all(color: _verifiedGreen.withValues(alpha: 0.35)),
    ),
    child: Row(
      children: [
        Icon(Icons.check_circle_outline, color: _verifiedGreen, size: 20.sp),
        hSpace(10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                customer.customerName,
                style: TextStyle(
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              if (customer.address != null && customer.address!.isNotEmpty) ...[
                vSpace(2),
                Text(
                  customer.address!,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}
