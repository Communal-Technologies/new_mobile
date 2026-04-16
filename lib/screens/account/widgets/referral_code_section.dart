import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:communal_mobile/core/widgets/space.dart';

class ReferralCodeSection extends StatelessWidget {
  const ReferralCodeSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Referral Code',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F1D40),
            ),
          ),
          vSpace(12),
          Container(
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Column(
              children: [
                _ReferralItem(
                  label: 'Referral Code',
                  value: 'PADO2025XYZ',
                  valueColor: const Color(0xFF0F1D40),
                  onCopy: () {
                    Clipboard.setData(const ClipboardData(text: 'PADO2025XYZ'));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Referral code copied to clipboard'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
                vSpace(16),
                Divider(height: 1, color: Colors.grey.shade200),
                vSpace(16),
                _ReferralItem(
                  label: 'Referral Link',
                  value: 'https://bullioncrib.com/ref/PADO2025XYZ',
                  valueColor: const Color(0xFF7434FF),
                  onCopy: () {
                    Clipboard.setData(const ClipboardData(
                      text: 'https://bullioncrib.com/ref/PADO2025XYZ',
                    ));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Referral link copied to clipboard'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReferralItem extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  final VoidCallback onCopy;

  const _ReferralItem({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Colors.grey.shade600,
                ),
              ),
              vSpace(4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                  color: valueColor,
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: onCopy,
          child: Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              color: valueColor == const Color(0xFF7434FF)
                  ? Colors.grey.shade100
                  : const Color(0xFFE3F2FD),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(
              Icons.copy,
              color: valueColor == const Color(0xFF7434FF)
                  ? Colors.grey.shade600
                  : const Color(0xFF2196F3),
              size: 20.sp,
            ),
          ),
        ),
      ],
    );
  }
}





