import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_state.dart';
import 'package:communal_mobile/core/widgets/space.dart';

/// Header rendered above the personal-info form on the edit-profile
/// screen: avatar, the user's name, and the KYC tier chip. Previously
/// hardcoded "Pado Lebari" with placeholder badges and embedded an
/// AccountToFreezeCard (wrong widget — that belongs to the freeze-
/// account flow), so the compile broke when the freeze card grew
/// required props.
class EditProfileHeader extends StatelessWidget {
  const EditProfileHeader({super.key, this.onEditPicture});

  final VoidCallback? onEditPicture;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        final user = authState is AuthAuthenticated ? authState.user : null;
        final name = user?.name.trim().isNotEmpty == true
            ? user!.name.trim()
            : 'Your account';
        final tierLabel = _tierLabel(user?.communalTier);

        return Column(
          children: [
            Stack(
              children: [
                Container(
                  width: 120.w,
                  height: 120.w,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF7434FF), Color(0xFF1976D2)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.person, color: Colors.white, size: 60.sp),
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
                        color: Theme.of(context).cardColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).dividerColor,
                          width: 2,
                        ),
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
              name,
              style: TextStyle(
                fontSize: 24.sp,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            vSpace(12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8.w,
              runSpacing: 8.h,
              children: [
                _Badge(label: tierLabel, color: const Color(0xFF7434FF)),
                if (user?.kycStep1Submitted == true)
                  _Badge(
                    label: 'KYC submitted',
                    color: const Color(0xFF4CAF50),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  String _tierLabel(String? tier) {
    final t = tier?.trim().toLowerCase();
    if (t == 'tier_1') return 'Tier 1';
    if (t == 'tier_2') return 'Tier 2';
    if (t == 'tier_3') return 'Tier 3';
    return 'Not verified';
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 16.sp,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
