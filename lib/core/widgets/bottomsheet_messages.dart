import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:communal_mobile/core/widgets/apptext.dart';

class SuccessBottomSheet extends StatelessWidget {
  const SuccessBottomSheet({super.key, required this.title});
  final String title;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.5,
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SmallAppText(
            title,
            alignment: TextAlign.center,
            fontSize: 24.sp,
          ),
        ],
      ),
    );
  }
}
