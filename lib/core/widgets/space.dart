import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

Widget vSpace(double height) {
  return SizedBox(
    height: height.h,
  );
}

Widget hSpace(double width) {
  return SizedBox(
    width: width.w,
  );
}

Widget vBar() {
  return SizedBox(
    height: 40.h,
    child: VerticalDivider(
      thickness: 1.0,
      width: 10.w,
    ),
  );
}

EdgeInsetsGeometry simPad(double v, double h) {
  return EdgeInsets.symmetric(vertical: v, horizontal: h);
}
