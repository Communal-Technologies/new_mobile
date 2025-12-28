import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class PhoneInputField extends StatelessWidget {
  const PhoneInputField({
    super.key,
    required this.controller,
    this.onCountryTap,
    this.errorText,
    this.onChanged,
  });

  final TextEditingController controller;
  final VoidCallback? onCountryTap;
  final String? errorText;
  final void Function(String)? onChanged;

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null && errorText!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: hasError ? Colors.red : Colors.grey.shade300,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              // Country code selector
              InkWell(
                onTap: onCountryTap,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12.r),
                  bottomLeft: Radius.circular(12.r),
                ),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Nigeria flag emoji
                      Text(
                        '🇳🇬',
                        style: TextStyle(fontSize: 24.sp),
                      ),
                      SizedBox(width: 8.w),
                      Icon(
                        Icons.keyboard_arrow_down,
                        size: 20.sp,
                        color: Colors.grey.shade600,
                      ),
                    ],
                  ),
                ),
              ),
              
              // Divider
              Container(
                height: 48.h,
                width: 1,
                color: Colors.grey.shade300,
              ),

              // Phone number input
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.phone,
                  onChanged: onChanged,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(11),
                  ],
                  style: TextStyle(
                    fontSize: 16.sp,
                    color: Colors.black,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter your phone number',
                    hintStyle: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 16.sp,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 14.h,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (hasError) ...[
          SizedBox(height: 4.h),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              errorText!,
              style: TextStyle(
                color: Colors.red,
                fontSize: 12.sp,
              ),
            ),
          ),
        ],
      ],
    );
  }
}


