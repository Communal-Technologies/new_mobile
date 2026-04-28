import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:communal_mobile/core/widgets/space.dart';

class SocialMediaSection extends StatelessWidget {
  const SocialMediaSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _SocialMediaIcon(
            icon: Icons.play_circle_filled,
            label: 'YouTube',
            color: Colors.red,
          ),
          _SocialMediaIcon(
            icon: Icons.facebook,
            label: 'Facebook',
            color: const Color(0xFF1877F2),
          ),
          _SocialMediaIcon(
            icon: Icons.alternate_email,
            label: 'X',
            color: const Color(0xFF1DA1F2),
          ),
          _SocialMediaIcon(
            icon: Icons.business,
            label: 'LinkedIn',
            color: const Color(0xFF0077B5),
          ),
          _SocialMediaIcon(
            icon: Icons.camera_alt,
            label: 'Instagram',
            color: const Color(0xFFE4405F),
          ),
        ],
      ),
    );
  }
}

class _SocialMediaIcon extends StatelessWidget {
  const _SocialMediaIcon({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  void _openSocialMedia(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Opening $label...')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _openSocialMedia(context),
      borderRadius: BorderRadius.circular(30.r),
      child: Column(
        children: [
          Container(
            width: 56.w,
            height: 56.w,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 28.sp,
            ),
          ),
          vSpace(8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13.sp,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}

