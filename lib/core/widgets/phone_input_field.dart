import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';
import 'package:communal_mobile/data/models/region_model.dart';

/// Phone field with country selector limited to backend [regions].
class PhoneInputField extends StatefulWidget {
  const PhoneInputField({
    super.key,
    required this.controller,
    required this.regions,
    this.initialValue,
    this.errorText,
    this.onChanged,
    this.onPhoneNumberChanged,
    this.focusNode,
    this.keyboardAction,
    this.onFieldSubmitted,
  });

  final TextEditingController controller;
  final List<RegionModel> regions;
  final PhoneNumber? initialValue;
  final String? errorText;
  final VoidCallback? onChanged;
  final void Function(PhoneNumber phone, bool isValid)? onPhoneNumberChanged;
  final FocusNode? focusNode;
  final TextInputAction? keyboardAction;
  final void Function(String value)? onFieldSubmitted;

  static PhoneNumber seedFromRegions(List<RegionModel> regions) {
    if (regions.isEmpty) {
      return PhoneNumber(isoCode: 'NG', dialCode: '+234');
    }
    final r = regions.first;
    return PhoneNumber(
      isoCode: r.countryIso,
      dialCode: r.dialCodeWithPlus,
    );
  }

  @override
  State<PhoneInputField> createState() => _PhoneInputFieldState();
}

class _PhoneInputFieldState extends State<PhoneInputField> {
  PhoneNumber? _current;
  bool _valid = false;

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null && widget.errorText!.isNotEmpty;
    final isos = widget.regions
        .map((r) => r.countryIso.toUpperCase())
        .where((e) => e.length == 2)
        .toList();

    if (isos.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(14.w),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: Colors.orange.shade300, width: 1.5),
            ),
            child: Text(
              'Allowed countries could not be loaded. Check your connection and try again.',
              style: TextStyle(fontSize: 15.sp, color: Colors.grey.shade800),
            ),
          ),
        ],
      );
    }

    final initial =
        widget.initialValue ?? PhoneInputField.seedFromRegions(widget.regions);

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
            color: Colors.white,
          ),
          clipBehavior: Clip.antiAlias,
          child: InternationalPhoneNumberInput(
            key: ValueKey<String>(
              '${initial.isoCode}_${initial.phoneNumber}_${widget.regions.length}',
            ),
            countries: isos,
            onInputChanged: (PhoneNumber phone) {
              _current = phone;
              widget.onPhoneNumberChanged?.call(phone, _valid);
              widget.onChanged?.call();
            },
            onInputValidated: (bool valid) {
              _valid = valid;
              if (_current != null) {
                widget.onPhoneNumberChanged?.call(_current!, valid);
              }
            },
            selectorConfig: const SelectorConfig(
              selectorType: PhoneInputSelectorType.BOTTOM_SHEET,
              setSelectorButtonAsPrefixIcon: true,
              leadingPadding: 12,
              trailingSpace: false,
            ),
            spaceBetweenSelectorAndTextField: 0,
            ignoreBlank: true,
            autoValidateMode: AutovalidateMode.onUserInteraction,
            initialValue: initial,
            textFieldController: widget.controller,
            focusNode: widget.focusNode,
            keyboardAction: widget.keyboardAction,
            onFieldSubmitted: widget.onFieldSubmitted,
            formatInput: true,
            hintText: 'Phone number',
            maxLength: 15,
            keyboardType: const TextInputType.numberWithOptions(
              signed: false,
              decimal: false,
            ),
            inputDecoration: InputDecoration(
              hintText: 'Phone number',
              hintStyle: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 18.sp,
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12.w,
                vertical: 14.h,
              ),
            ),
            searchBoxDecoration: InputDecoration(
              hintText: 'Search country',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.r),
              ),
            ),
            selectorTextStyle: TextStyle(
              fontSize: 18.sp,
              color: Colors.black87,
            ),
            textStyle: TextStyle(
              fontSize: 18.sp,
              color: Colors.black,
            ),
          ),
        ),
        if (hasError) ...[
          SizedBox(height: 4.h),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              widget.errorText!,
              style: TextStyle(
                color: Colors.red,
                fontSize: 15.sp,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
