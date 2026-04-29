import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:communal_mobile/core/widgets/space.dart';

class ShareViaSection extends StatelessWidget {
  const ShareViaSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Share Via',
            style: TextStyle(
              fontSize: 17.sp,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          vSpace(16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _ShareOption(
                icon: Icons.chat,
                iconColor: const Color(0xFF25D366),
                label: 'WhatsApp',
                onTap: () {
                  // TODO: Share via WhatsApp
                },
              ),
              _ShareOption(
                icon: Icons.facebook,
                iconColor: const Color(0xFF1877F2),
                label: 'Facebook',
                onTap: () {
                  // TODO: Share via Facebook
                },
              ),
              _ShareOption(
                icon: Icons.alternate_email,
                iconColor: const Color(0xFF1DA1F2),
                label: 'Twitter',
                onTap: () {
                  // TODO: Share via Twitter
                },
              ),
              _ShareOption(
                icon: Icons.email,
                iconColor: const Color(0xFFFF9800),
                label: 'Email',
                onTap: () {
                  // TODO: Share via Email
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShareOption extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

  const _ShareOption({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60.w,
            height: 60.w,
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              shape: BoxShape.circle,
              border: Border.all(color: iconColor, width: 2),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 28.sp,
            ),
          ),
          vSpace(8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14.sp,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}





