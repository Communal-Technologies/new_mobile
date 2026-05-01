import 'package:communal_mobile/core/widgets/space.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

/// Entry surface for the bill-payments feature. Two rows × two columns,
/// each tile in its own brand accent so the page reads at a glance.
class BillsLandingScreen extends StatelessWidget {
  const BillsLandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pay bills'),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 24.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHero(theme),
              vSpace(20),
              _buildGrid(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHero(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20.w, 22.h, 20.w, 22.h),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7434FF), Color(0xFF5B8DFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(Iconsax.receipt_2, color: Colors.white, size: 22.sp),
              ),
              hSpace(12),
              Text(
                'Pay anything',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          vSpace(10),
          Text(
            'Top up phones, recharge meters, renew TV plans — all from your Communal wallet.',
            style: TextStyle(
              fontSize: 15.sp,
              color: Colors.white.withValues(alpha: 0.9),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 14.w,
      mainAxisSpacing: 14.h,
      childAspectRatio: 1.0,
      children: [
        _BillTile(
          icon: Iconsax.call_calling,
          title: 'Airtime',
          subtitle: 'MTN, Airtel, Glo, 9mobile, NTEL.',
          accent: const Color(0xFFFF7B3D),
          onTap: () => context.goNamed('bills-airtime'),
        ),
        _BillTile(
          icon: Iconsax.global,
          title: 'Data',
          subtitle: 'Daily, weekly or monthly bundles.',
          accent: const Color(0xFF2BA6FF),
          onTap: () => context.goNamed('bills-data'),
        ),
        _BillTile(
          icon: Iconsax.flash_1,
          title: 'Electricity',
          subtitle: 'Recharge prepaid or pay postpaid.',
          accent: const Color(0xFFFFB627),
          onTap: () => context.goNamed('bills-electricity'),
        ),
        _BillTile(
          icon: Iconsax.monitor,
          title: 'Cable TV',
          subtitle: 'DSTV, GoTV, StarTimes plans.',
          accent: const Color(0xFF22C55E),
          onTap: () => context.goNamed('bills-television'),
        ),
      ],
    );
  }
}

class _BillTile extends StatelessWidget {
  const _BillTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20.r),
        child: Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.6),
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44.w,
                height: 44.w,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: Icon(icon, color: accent, size: 22.sp),
              ),
              const Spacer(),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              vSpace(4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
