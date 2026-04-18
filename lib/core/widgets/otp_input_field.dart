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

  void _emitCode() {
    final code = _getCode();
    widget.onChanged(code);
    if (code.length == widget.length) {
      widget.onCompleted?.call(code);
    }
  }

  /// Clipboard / autofill: multiple digits at once — fill boxes from the start.
  void _applyPastedDigits(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return;

    final take = digits.length > widget.length
        ? digits.substring(0, widget.length)
        : digits;

    for (var i = 0; i < widget.length; i++) {
      final ch = i < take.length ? take[i] : '';
      _controllers[i].text = ch;
      _previousValues[i] = ch;
    }

    if (take.length >= widget.length) {
      _focusNodes[widget.length - 1].unfocus();
    } else {
      _focusNodes[take.length].requestFocus();
    }

    _emitCode();
  }

  void _onChanged(int index, String value, String previousValue) {
    if (value.length == 1 && index < widget.length - 1) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && previousValue.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    _emitCode();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AutofillGroup(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(widget.length, (index) {
          final hasValue = _controllers[index].text.isNotEmpty;

          return SizedBox(
            width: 48.w,
            height: 56.h,
            child: TextField(
              controller: _controllers[index],
              focusNode: _focusNodes[index],
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              autofillHints: index == 0
                  ? const [AutofillHints.oneTimeCode]
                  : null,
              // No per-cell maxLength — paste must deliver all digits to one field;
              // we split in onChanged.
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
                    color:
                        hasValue ? theme.primaryColor : Colors.grey.shade300,
                    width: 1.5,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide(
                    color:
                        hasValue ? theme.primaryColor : Colors.grey.shade300,
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
                final digitsOnly = value.replaceAll(RegExp(r'\D'), '');

                if (digitsOnly.length > 1) {
                  // Paste (or OS autofill) delivered multiple digits into this cell.
                  setState(() {
                    _applyPastedDigits(digitsOnly);
                  });
                  return;
                }

                final previousValue = _previousValues[index];
                if (digitsOnly.length == 1 &&
                    value.isNotEmpty &&
                    _controllers[index].text != digitsOnly) {
                  _controllers[index].text = digitsOnly;
                  _controllers[index].selection = TextSelection.collapsed(
                    offset: digitsOnly.length,
                  );
                }

                setState(() {
                  _previousValues[index] =
                      digitsOnly.isNotEmpty ? digitsOnly : '';
                });

                _onChanged(
                  index,
                  digitsOnly.isNotEmpty ? digitsOnly : '',
                  previousValue,
                );
              },
              onTap: () {
                if (_controllers[index].text.isEmpty) {
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
          );
        }),
      ),
    );
  }
}
