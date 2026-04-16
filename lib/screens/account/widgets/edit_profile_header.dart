import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/screens/account/widgets/account_to_freeze_card.dart';

class EditProfileHeader extends StatelessWidget {
  final VoidCallback? onEditPicture;

  const EditProfileHeader({
    super.key,
    this.onEditPicture,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          children: [
            Container(
              width: 120.w,
              height: 120.w,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF7434FF), Color(0xFF1976D2)],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person,
                color: Colors.white,
                size: 60.sp,
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: GestureDetector(
                onTap: onEditPicture,
                child: Container(
                  width: 36.w,
                  height: 36.w,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade300, width: 2),
                  ),
                  child: Icon(
                    Icons.edit,
                    color: const Color(0xFF7434FF),
                    size: 18.sp,
                  ),
                ),
              ),
            ),
          ],
        ),
        vSpace(16),
        Text(
          'Pado Lebari',
          style: TextStyle(
            fontSize: 24.sp,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F1D40),
          ),
        ),
        vSpace(12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildBadge('BVN Verified', const Color(0xFF4CAF50)),
            hSpace(8),
            _buildBadge('Premium Account', const Color(0xFF7434FF)),
            hSpace(8),
            _buildBadge('Tier 3', Colors.grey.shade400),
          ],
        ),
        vSpace(20),
        const AccountToFreezeCard(),
      ],
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.sp,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}





