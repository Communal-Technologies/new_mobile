import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:communal_mobile/core/widgets/space.dart';

/// Compact "this is the account being frozen" card. Matches the visual
/// shape of [AccountToDeleteCard] so the freeze + delete flows read as
/// the same product. Caller supplies the values from auth state.
class AccountToFreezeCard extends StatelessWidget {
  const AccountToFreezeCard({
    super.key,
    required this.name,
    required this.contact,
    required this.avatarInitials,
  });

  /// Display name (first + middle + last, with sensible fallbacks).
  final String name;

  /// Secondary line under the name — phone or email.
  final String contact;

  /// 1–2 letter initials shown in the purple avatar circle.
  final String avatarInitials;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Account to be frozen',
          style: TextStyle(
            fontSize: 19.sp,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        vSpace(12),
        Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: theme.dividerColor,
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Row(
            children: [
              Container(
                width: 50.w,
                height: 50.w,
                decoration: const BoxDecoration(
                  color: Color(0xFF7434FF),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    avatarInitials,
                    style: TextStyle(
                      fontSize: 19.sp,
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
                      name,
                      style: TextStyle(
                        fontSize: 19.sp,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    if (contact.isNotEmpty) ...[
                      vSpace(4),
                      Text(
                        contact,
                        style: TextStyle(
                          fontSize: 17.sp,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
