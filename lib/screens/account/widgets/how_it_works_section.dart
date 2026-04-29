import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:communal_mobile/core/widgets/space.dart';

class HowItWorksSection extends StatelessWidget {
  const HowItWorksSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How It Works',
            style: TextStyle(
              fontSize: 17.sp,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          vSpace(16),
          Container(
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Column(
              children: [
                _StepItem(
                  stepNumber: 1,
                  title: 'Share your code',
                  description: 'Send your unique referral code to friends.',
                ),
                vSpace(20),
                _StepItem(
                  stepNumber: 2,
                  title: 'Friend signs up',
                  description: 'They create an account using your code.',
                ),
                vSpace(20),
                _StepItem(
                  stepNumber: 3,
                  title: 'Get rewarded',
                  description: 'Earn ₦5,000 when they complete their first transaction.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepItem extends StatelessWidget {
  final int stepNumber;
  final String title;
  final String description;

  const _StepItem({
    required this.stepNumber,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32.w,
          height: 32.w,
          decoration: BoxDecoration(
            color: const Color(0xFF7434FF),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$stepNumber',
              style: TextStyle(
                fontSize: 17.sp,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
        hSpace(16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              vSpace(4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 15.sp,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}





