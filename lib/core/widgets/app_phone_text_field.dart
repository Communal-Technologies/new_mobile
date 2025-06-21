import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';
import 'package:communal_mobile/core/utils/app_logger.dart';
import 'package:communal_mobile/core/utils/form_validator.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'apptext.dart';

class PhoneNumberInputField extends StatelessWidget {
  const PhoneNumberInputField({
    super.key,
    this.controller,
    this.label,
    this.hint,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textColor = theme.textTheme.bodyMedium?.color;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null)
          SmallAppText(label!, color: textColor, fontSize: 16.sp),
        vSpace(5),
        InternationalPhoneNumberInput(
          onInputChanged: (PhoneNumber number) {},
          onInputValidated: (bool value) {},
          selectorConfig: const SelectorConfig(
            selectorType: PhoneInputSelectorType.BOTTOM_SHEET,
            setSelectorButtonAsPrefixIcon: true,
            leadingPadding: 15,
          ),
          spaceBetweenSelectorAndTextField: 0,
          ignoreBlank: false,
          autoValidateMode: AutovalidateMode.onUserInteraction,
          selectorTextStyle: TextStyle(color: textColor),
          initialValue: PhoneNumber(dialCode: '+234', isoCode: 'NG'),
          textFieldController: controller,
          formatInput: true,
          validator: (val) {
            return FormValidator.isValidPhoneNumber(val);
          },
          searchBoxDecoration: InputDecoration(
            border: OutlineInputBorder(
              borderSide: BorderSide(color: colorScheme.outline),
              borderRadius: BorderRadius.circular(10),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: colorScheme.primary),
              borderRadius: BorderRadius.circular(10),
            ),
            hintText: hint,
            hintStyle: TextStyle(
              color: colorScheme.outlineVariant,
              fontSize: 12.sp,
            ),
            labelStyle: TextStyle(color: textColor),
          ),
          inputDecoration: InputDecoration(
            border: OutlineInputBorder(
              borderSide: BorderSide(color: colorScheme.outline),
              borderRadius: BorderRadius.circular(10),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: colorScheme.primary),
              borderRadius: BorderRadius.circular(10),
            ),
            hintText: hint,
            hintStyle: TextStyle(
              color: colorScheme.outlineVariant,
              fontSize: 12.sp,
            ),
            labelStyle: TextStyle(color: textColor),
          ),
          keyboardType: const TextInputType.numberWithOptions(
            signed: true,
            decimal: false,
          ),
          inputBorder: OutlineInputBorder(
            borderSide: BorderSide(color: colorScheme.outline),
            borderRadius: BorderRadius.circular(10),
          ),
          onSaved: (PhoneNumber number) {
            appLog('On Saved: $number');
          },
        ),
      ],
    );
  }
}
