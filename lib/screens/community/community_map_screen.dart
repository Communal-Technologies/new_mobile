import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:communal_mobile/core/widgets/space.dart';

class CommunityMapScreen extends StatelessWidget {
  const CommunityMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Community Map'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.map_outlined,
                size: 64,
                color: Color(0xFF7434FF),
              ),
              vSpace(12),
              Text(
                'Map view coming soon',
                style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w700),
              ),
              vSpace(8),
              Text(
                'We’ll display nearby cooperatives here so you can join in a tap.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14.sp, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
