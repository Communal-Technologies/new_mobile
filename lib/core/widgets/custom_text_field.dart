import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class CustomTextField extends StatelessWidget {
  const CustomTextField({
    super.key,
    required this.controller,
    this.hintText,
    this.labelText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.focusNode,
    this.onFieldSubmitted,
    this.validator,
    this.onChanged,
    this.errorText,
    this.enabled = true,
    this.maxLength,
    this.inputFormatters,
  });

  final TextEditingController controller;
  final String? hintText;
  final String? labelText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;
  final void Function(String value)? onFieldSubmitted;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final String? errorText;
  final bool enabled;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null && errorText!.isNotEmpty;
    final theme = Theme.of(context);
    // Theme-aware fill / border / hint so the field works on both
    // light and dark scaffolds. Was hard-coded white + grey.shade300
    // — looked white on dark mode and ate the value text.
    final fillColor = theme.colorScheme.surfaceContainerHighest;
    final borderColor = theme.dividerColor;
    final hintColor = theme.colorScheme.onSurface.withValues(alpha: 0.5);
    final textColor = theme.colorScheme.onSurface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (labelText != null) ...[
          Text(
            labelText!,
            style: TextStyle(
              fontSize: 19.sp,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
          ),
          SizedBox(height: 8.h),
        ],
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          onFieldSubmitted: onFieldSubmitted,
          enabled: enabled,
          maxLength: maxLength,
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          style: TextStyle(
            fontSize: 19.sp,
            color: textColor,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(
              color: hintColor,
              fontSize: 17.sp,
            ),
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: fillColor,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 14.w,
              vertical: 14.h,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(
                color: hasError ? Colors.red : borderColor,
                width: 1.5,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(
                color: hasError ? Colors.red : borderColor,
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(
                color: hasError ? Colors.red : theme.primaryColor,
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(
                color: Colors.red,
                width: 1.5,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(
                color: Colors.red,
                width: 1.5,
              ),
            ),
            counterText: '',
          ),
          validator: validator,
        ),
        if (hasError) ...[
          SizedBox(height: 4.h),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              errorText!,
              style: TextStyle(
                color: Colors.red,
                fontSize: 17.sp,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

