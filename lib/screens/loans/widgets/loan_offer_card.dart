import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/data/models/loan_scheme.dart';

class LoanOfferCard extends StatelessWidget {
  const LoanOfferCard({
    super.key,
    required this.scheme,
    this.onApply,
  });

  final LoanScheme scheme;
  final VoidCallback? onApply;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E9),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: const Color(0xFFFFD2B0).withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  scheme.title.isNotEmpty ? scheme.title : scheme.loanCode,
                  style: TextStyle(
                    fontSize: 19.sp,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              if (scheme.category.isNotEmpty)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE67E22),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Text(
                    scheme.category,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          vSpace(8),
          Text(
            scheme.numberOfGuarantors > 0
                ? 'Needs ${scheme.numberOfGuarantors} guarantor${scheme.numberOfGuarantors == 1 ? '' : 's'}'
                : 'No guarantors required',
            style: TextStyle(
              fontSize: 15.sp,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          vSpace(16),
          Wrap(
            spacing: 16.w,
            runSpacing: 8.h,
            children: [
              _miniStat(context,Icons.trending_up, scheme.interestRateLabel),
              _miniStat(context,Icons.access_time, scheme.durationLabel),
              if (scheme.serviceCharge > 0)
                _miniStat(context,
                  Icons.percent,
                  '${scheme.serviceCharge.toStringAsFixed(scheme.serviceCharge.truncateToDouble() == scheme.serviceCharge ? 0 : 2)}% service',
                ),
            ],
          ),
          vSpace(16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onApply,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE67E22),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
                padding: EdgeInsets.symmetric(vertical: 14.h),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Apply Now',
                    style: TextStyle(
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  hSpace(8),
                  Icon(Icons.arrow_forward, size: 18.sp),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(BuildContext context, IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16.sp, color: const Color(0xFFE67E22)),
        hSpace(6),
        Text(
          label,
          style: TextStyle(
            fontSize: 15.sp,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
