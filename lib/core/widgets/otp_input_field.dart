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
      (index) => FocusNode(
        onKeyEvent: (node, event) => _handleOtpKey(index, event),
      ),
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

  /// Backspace on an empty cell: move to previous and clear its digit (OTP UX).
  KeyEventResult _handleOtpKey(int index, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey != LogicalKeyboardKey.backspace) {
      return KeyEventResult.ignored;
    }
    if (_controllers[index].text.isNotEmpty) {
      return KeyEventResult.ignored;
    }
    if (index <= 0) {
      return KeyEventResult.handled;
    }
    setState(() {
      _controllers[index - 1].clear();
      _previousValues[index - 1] = '';
    });
    _focusNodes[index - 1].requestFocus();
    _emitCode();
    return KeyEventResult.handled;
  }

  /// Paste / autofill: place digits starting at [startIndex] (focused box).
  void _applyPastedDigits(String raw, int startIndex) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return;

    final maxLen = widget.length - startIndex;
    if (maxLen <= 0) return;

    final take = digits.length > maxLen
        ? digits.substring(0, maxLen)
        : digits;

    for (var i = 0; i < widget.length; i++) {
      if (i < startIndex) {
        continue;
      }
      final rel = i - startIndex;
      if (rel < take.length) {
        final ch = take[rel];
        _controllers[i].text = ch;
        _previousValues[i] = ch;
      } else {
        _controllers[i].clear();
        _previousValues[i] = '';
      }
    }

    final filledEnd = startIndex + take.length;
    if (filledEnd >= widget.length) {
      _focusNodes[widget.length - 1].requestFocus();
    } else {
      _focusNodes[filledEnd].requestFocus();
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
              enableInteractiveSelection: true,
              autofillHints: index == 0
                  ? const [AutofillHints.oneTimeCode]
                  : null,
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
                  setState(() {
                    _applyPastedDigits(digitsOnly, index);
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
