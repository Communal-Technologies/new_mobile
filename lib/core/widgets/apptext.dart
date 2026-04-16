import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'ui.dart';

class SmallAppText extends StatelessWidget {
  final String data;
  final Color? color;
  final double? fontSize;
  final FontWeight? fontWeight;
  final TextAlign? alignment;
  final bool? canCopy;
  final TextOverflow? overflow;
  final int? maxLines;

  const SmallAppText(
    this.data, {
    super.key,
    this.color,
    this.fontSize,
    this.fontWeight,
    this.alignment,
    this.overflow,
    this.maxLines,
    this.canCopy,
  });

  @override
  Widget build(BuildContext context) {
    final defaultStyle = Theme.of(context).textTheme.bodyMedium;

    return GestureDetector(
      onLongPress: () {
        if (canCopy == true) {
          Clipboard.setData(ClipboardData(text: data));
          UiService().showSuccessSnackBar(context, 'Copied $data to clipboard');
        }
      },
      child: Text(
        data,
        textAlign: alignment,
        overflow: overflow ?? TextOverflow.ellipsis,
        maxLines: maxLines ?? 999,
        style: defaultStyle?.copyWith(
          color: color ?? defaultStyle.color,
          fontSize: fontSize?.sp ?? defaultStyle.fontSize,
          fontWeight: fontWeight ?? defaultStyle.fontWeight,
        ),
      ),
    );
  }
}

class MedAppText extends StatelessWidget {
  final String data;
  final Color? color;
  final double? fontSize;
  final FontWeight? fontWeight;
  final TextAlign? alignment;
  final TextOverflow? overflow;
  final int? maxLines;
  final bool? canCopy;

  const MedAppText(
    this.data, {
    super.key,
    this.color,
    this.fontSize,
    this.fontWeight,
    this.alignment,
    this.overflow,
    this.maxLines,
    this.canCopy,
  });

  @override
  Widget build(BuildContext context) {
    final defaultStyle = Theme.of(context).textTheme.bodyLarge;

    return GestureDetector(
      onLongPress: () {
        if (canCopy == true) {
          Clipboard.setData(ClipboardData(text: data));
          UiService().showSuccessSnackBar(context, 'Copied $data to clipboard');
        }
      },
      child: Text(
        data,
        textAlign: alignment,
        overflow: overflow ?? TextOverflow.ellipsis,
        maxLines: maxLines ?? 999,
        style: defaultStyle?.copyWith(
          color: color ?? defaultStyle.color,
          fontSize: fontSize?.sp ?? defaultStyle.fontSize,
          fontWeight: fontWeight ?? defaultStyle.fontWeight,
        ),
      ),
    );
  }
}

class BigAppText extends StatelessWidget {
  final String data;
  final Color? color;
  final double? fontSize;
  final FontWeight? fontWeight;
  final TextAlign? textAlign;
  final FontStyle? fontStyle;
  final bool? canCopy;
  final TextOverflow? overflow;
  final int? maxLines;

  const BigAppText(
    this.data, {
    super.key,
    this.color,
    this.fontSize,
    this.fontWeight,
    this.textAlign,
    this.fontStyle,
    this.canCopy,
    this.overflow,
    this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    final defaultStyle = Theme.of(context).textTheme.headlineSmall;

    return GestureDetector(
      onLongPress: () {
        if (canCopy == true) {
          Clipboard.setData(ClipboardData(text: data));
          UiService().showSuccessSnackBar(context, 'Copied $data to clipboard');
        }
      },
      child: Text(
        data,
        textAlign: textAlign ?? TextAlign.left,
        overflow: overflow ?? TextOverflow.ellipsis,
        maxLines: maxLines ?? 999,
        style: defaultStyle?.copyWith(
          color: color ?? defaultStyle.color,
          fontStyle: fontStyle ?? FontStyle.normal,
          fontSize: fontSize?.sp ?? defaultStyle.fontSize,
          fontWeight: fontWeight ?? defaultStyle.fontWeight,
        ),
      ),
    );
  }
}
