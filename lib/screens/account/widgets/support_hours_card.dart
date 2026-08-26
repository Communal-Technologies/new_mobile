import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/data/models/support_models.dart';

/// When the desk is staffed.
///
/// The rows come from the `support_hours` setting the admin console owns, so a
/// change to the roster does not need an app release. The times used to be
/// hardcoded here, which meant the card kept promising Saturday cover after the
/// desk stopped offering it. When nothing is configured the card falls back to
/// the window below and says only what it can stand behind.
class SupportHoursCard extends StatelessWidget {
  const SupportHoursCard({super.key, this.config});

  final SupportConfig? config;

  static const List<SupportHours> _fallback = [
    SupportHours(day: 'Monday - Friday', hours: '8:00 AM - 8:00 PM WAT'),
    SupportHours(day: 'Saturday', hours: '9:00 AM - 5:00 PM WAT'),
    SupportHours(day: 'Sunday', hours: 'Closed'),
  ];

  @override
  Widget build(BuildContext context) {
    final hours = config?.hours.isNotEmpty == true ? config!.hours : _fallback;
    final freeText = config?.hoursText;
    final sla = config?.firstResponseSlaMinutes ?? 0;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: const Color(0xFF7434FF),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Support Hours',
                  style: TextStyle(
                    fontSize: 19.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              if (config?.operatorsOnline == true)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 7.w,
                        height: 7.w,
                        decoration: const BoxDecoration(
                          color: Colors.greenAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      hSpace(5),
                      Text(
                        'Online now',
                        style: TextStyle(fontSize: 15.sp, color: Colors.white),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          vSpace(16),
          if (freeText != null)
            Text(
              freeText,
              style: TextStyle(
                fontSize: 17.sp,
                height: 1.5,
                color: Colors.white.withValues(alpha: 0.95),
              ),
            )
          else
            for (int i = 0; i < hours.length; i++) ...[
              if (i > 0) vSpace(12),
              _buildHoursRow(hours[i].day, hours[i].hours),
            ],
          vSpace(16),
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  color: Colors.white,
                  size: 16.sp,
                ),
                hSpace(8),
                Expanded(
                  child: Text(
                    sla > 0
                        ? 'The assistant answers any time. A person usually '
                            'replies within ${_sla(sla)}.'
                        : 'The assistant answers any time, and hands anything '
                            'it cannot answer to a person.',
                    style: TextStyle(
                      fontSize: 16.sp,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _sla(int minutes) {
    if (minutes < 60) return '$minutes minutes';
    final hours = minutes ~/ 60;
    if (minutes % 60 == 0) return hours == 1 ? 'an hour' : '$hours hours';
    return '$hours h ${minutes % 60} m';
  }

  Widget _buildHoursRow(String day, String time) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            day,
            style: TextStyle(
              fontSize: 17.sp,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
        Text(
          time,
          style: TextStyle(
            fontSize: 17.sp,
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
      ],
    );
  }
}
