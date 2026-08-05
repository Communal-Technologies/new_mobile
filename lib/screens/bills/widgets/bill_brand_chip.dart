import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Custom selection chip used across the bill-payment form screens.
/// Lifted into its own widget so the airtime, data, electricity, and
/// television screens render identical, brand-coloured pickers.
///
/// Selected state pops in the brand purple; unselected sits flat
/// against the card background. Falls back gracefully on dark mode
/// because all colours are theme-aware.
class BillBrandChip extends StatelessWidget {
  const BillBrandChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.accent = const Color(0xFF7434FF),
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected ? accent.withValues(alpha: 0.12) : theme.cardColor,
      borderRadius: BorderRadius.circular(20.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20.r),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(
              color: selected
                  ? accent
                  : theme.dividerColor.withValues(alpha: 0.7),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? accent : theme.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
