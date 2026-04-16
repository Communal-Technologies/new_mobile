import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class OtpInputField extends StatefulWidget {
  const OtpInputField({
    super.key,
    required this.length,
    required this.onChanged,
    this.onCompleted,
  });

  final int length;
  final Function(String) onChanged;
  final Function(String)? onCompleted;

  @override
  State<OtpInputField> createState() => _OtpInputFieldState();
}

class _OtpInputFieldState extends State<OtpInputField> {
  late List<TextEditingController> _controllers;
  late List<FocusNode> _focusNodes;
  late List<String> _previousValues;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      widget.length,
      (index) => TextEditingController(),
    );
    _focusNodes = List.generate(
      widget.length,
      (index) => FocusNode(),
    );
    _previousValues = List.generate(
      widget.length,
      (index) => '',
    );
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  String _getCode() {
    return _controllers.map((c) => c.text).join();
  }

  void _onChanged(int index, String value, String previousValue) {
    if (value.length == 1 && index < widget.length - 1) {
      // Move to next field when a digit is entered
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && previousValue.isEmpty && index > 0) {
      // Move to previous field when backspace is pressed on already empty field
      _focusNodes[index - 1].requestFocus();
    }

    final code = _getCode();
    widget.onChanged(code);

    if (code.length == widget.length) {
      widget.onCompleted?.call(code);
    }
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(widget.length, (index) {
        final hasValue = _controllers[index].text.isNotEmpty;

        return SizedBox(
          width: 48.w,
          height: 56.h,
          child: RawKeyboardListener(
            focusNode: FocusNode(),
            onKey: (RawKeyEvent event) {
              if (event is RawKeyDownEvent) {
                if (event.logicalKey == LogicalKeyboardKey.backspace) {
                  if (_controllers[index].text.isEmpty && index > 0) {
                    // Move to previous field when backspace is pressed on empty field
                    _focusNodes[index - 1].requestFocus();
                  }
                }
              }
            },
            child: TextField(
              controller: _controllers[index],
              focusNode: _focusNodes[index],
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              maxLength: 1,
              style: TextStyle(
                fontSize: 24.sp,
                fontWeight: FontWeight.w600,
                color: theme.primaryColor,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: InputDecoration(
                counterText: '',
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide(
                    color: hasValue ? theme.primaryColor : Colors.grey.shade300,
                    width: 1.5,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide(
                    color: hasValue ? theme.primaryColor : Colors.grey.shade300,
                    width: 1.5,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide(
                    color: theme.primaryColor,
                    width: 2,
                  ),
                ),
              ),
              onChanged: (value) {
                final previousValue = _previousValues[index];
                setState(() {
                  _previousValues[index] = value;
                });
                _onChanged(index, value, previousValue);
              },
              onTap: () {
                if (_controllers[index].text.isEmpty) {
                  // Find the first empty field and focus it
                  for (int i = 0; i < widget.length; i++) {
                    if (_controllers[i].text.isEmpty) {
                      _focusNodes[i].requestFocus();
                      break;
                    }
                  }
                }
              },
              onEditingComplete: () {
                if (index < widget.length - 1) {
                  _focusNodes[index + 1].requestFocus();
                }
              },
            ),
          ),
        );
      }),
    );
  }
}

