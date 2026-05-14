import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:communal_mobile/core/constants/constants.dart';
import 'package:communal_mobile/core/constants/images.dart';
import 'package:communal_mobile/core/widgets/otp_input_field.dart';
import 'package:communal_mobile/core/widgets/app_elevated_button.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/data/repositories/auth_repository.dart';
import 'package:communal_mobile/injection.dart';
import 'package:go_router/go_router.dart';

enum VerificationMethod { sms, whatsapp, call }

class PhoneVerificationScreen extends StatefulWidget {
  const PhoneVerificationScreen({
    super.key,
    required this.phoneNumber,
    this.method = VerificationMethod.sms,
    this.userId,
  });

  final String phoneNumber;
  final VerificationMethod method;

  /// Pre-fetched on the signup screen by an OTP-send call there. When
  /// supplied we skip the automatic send in [initState] (the OTP has
  /// already been issued); when null we issue the send ourselves so
  /// other entry points (legacy navigation, deep links) keep working.
  final String? userId;

  @override
  State<PhoneVerificationScreen> createState() =>
      _PhoneVerificationScreenState();
}

class _PhoneVerificationScreenState extends State<PhoneVerificationScreen> {
  final AuthRepository _authRepository = getIt<AuthRepository>();
  String _code = '';
  int _resendTimer = 300;
  Timer? _timer;
  Timer? _deliveryPollTimer;
  int _deliveryPollAttempts = 0;

  /// Set on first successful OTP send and used in /create-account-password
  /// later in the chain. Hydrated from the route arg when the signup
  /// screen pre-issued the OTP, or set after our own send.
  String? _userId;

  /// True while an in-flight network request would make a tap a no-op
  /// (sending OTP, verifying OTP, resending). Disables the button so
  /// rapid taps can't fire two requests.
  bool _busy = false;

  /// Inline error message shown below the OTP field. Cleared when the
  /// user starts typing a new code or hits Resend.
  String? _error;
  String? _deliveryInfo;

  @override
  void initState() {
    super.initState();
    _userId = widget.userId;
    _startTimer();
    // The signup screen now owns the first OTP send so the existence
    // check (HTTP 409 -> account_exists) surfaces *there* instead of
    // landing the user on this screen with an error. Only auto-send
    // when no userId was passed in — keeps non-signup entry paths and
    // deep links working without a duplicate send when there isn't.
    if (_userId == null || _userId!.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _sendOtp());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _deliveryPollTimer?.cancel();
    super.dispose();
  }

  String _deliveryMethodForRequest() {
    switch (widget.method) {
      case VerificationMethod.call:
        return 'voice_call';
      case VerificationMethod.sms:
      case VerificationMethod.whatsapp:
        return 'sms';
    }
  }

  void _startDeliveryStatusPolling() {
    _deliveryPollTimer?.cancel();
    _deliveryPollAttempts = 0;
    _deliveryPollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      _deliveryPollAttempts++;
      if (_deliveryPollAttempts > 20) {
        timer.cancel();
        return;
      }
      try {
        final data = await _authRepository.getOtpDeliveryStatus(
          widget.phoneNumber,
          purpose: 'signup',
        );
        if (!mounted || data == null) return;
        final status = (data['status']?.toString() ?? '').toLowerCase();
        final note = data['delivery_note']?.toString();
        if (note != null && note.isNotEmpty) {
          setState(() {
            _deliveryInfo = note;
          });
        }
        if (status == 'sent' || status == 'failed') {
          timer.cancel();
        }
      } catch (_) {
        // Keep polling; transient failures are common on weak networks.
      }
    });
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendTimer > 0) {
        setState(() {
          _resendTimer--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _sendOtp() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final id = await _authRepository.requestOtpForSignup(
        widget.phoneNumber,
        deliveryMethod: _deliveryMethodForRequest(),
      );
      if (!mounted) return;
      setState(() {
        _userId = id;
        _busy = false;
        _deliveryInfo = null;
      });
      _startDeliveryStatusPolling();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _resendCode() async {
    setState(() {
      _resendTimer = 300;
      _error = null;
      _deliveryInfo = null;
    });
    _startTimer();
    await _sendOtp();
  }

  String get _maskedPhone {
    if (widget.phoneNumber.length >= 11) {
      final prefix = widget.phoneNumber.substring(0, 7);
      final suffix = widget.phoneNumber.substring(widget.phoneNumber.length - 4);
      return '$prefix****$suffix';
    }
    return widget.phoneNumber;
  }

  String get _title {
    switch (widget.method) {
      case VerificationMethod.sms:
        return 'Verify Phone via SMS';
      case VerificationMethod.whatsapp:
        return 'Verify Phone via Whatsapp';
      case VerificationMethod.call:
        return 'Verify Phone via Call';
    }
  }

  String get _instruction {
    switch (widget.method) {
      case VerificationMethod.sms:
        return 'Enter the code we sent to your phone number (SMS)';
      case VerificationMethod.whatsapp:
        return 'Enter the code we sent to you on Whatsapp';
      case VerificationMethod.call:
        return 'Enter the code you heard on the Voice Call';
    }
  }

  List<String> get _howToCheckSteps {
    switch (widget.method) {
      case VerificationMethod.sms:
        return [
          'Open your messaging app on your phone',
          'Check for a message from PalmPayInfo',
          'Enter the 6-digit code in the box above',
        ];
      case VerificationMethod.whatsapp:
        return [
          'Open your whatsapp app on your phone',
          'Check for a message from PalmPayInfo',
          'Enter the 6-digit code in the box above',
        ];
      case VerificationMethod.call:
        return [
          'You will receive a call from us',
          'Enter the 6-digit code you hear in the box above',
        ];
    }
  }

  List<Widget> get _alternativeMethods {
    final methods = <Widget>[];

    if (widget.method != VerificationMethod.sms) {
      methods.add(
        _MethodButton(
          icon: Icons.sms_outlined,
          label: 'SMS',
          onTap: () {
            context.pushReplacement('/verify-phone', extra: {
              'phone': widget.phoneNumber,
              'method': 'sms',
            });
          },
        ),
      );
    }

    if (widget.method != VerificationMethod.whatsapp) {
      methods.add(
        _MethodButton(
          icon: Icons.chat_bubble_outline,
          label: 'Whatsapp',
          iconColor: Colors.green,
          onTap: () {
            context.pushReplacement('/verify-phone', extra: {
              'phone': widget.phoneNumber,
              'method': 'whatsapp',
            });
          },
        ),
      );
    }

    if (widget.method != VerificationMethod.call) {
      methods.add(
        _MethodButton(
          icon: Icons.phone_outlined,
          label: 'Voice Call',
          onTap: () {
            context.pushReplacement('/verify-phone', extra: {
              'phone': widget.phoneNumber,
              'method': 'call',
            });
          },
        ),
      );
    }

    return methods;
  }

  Future<void> _verifyCode() async {
    if (_busy) return;
    if (_code.length != AppConstants.otpLength) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await _authRepository.verifyOtpForSignup(
        widget.phoneNumber,
        _code,
      );
      if (!mounted) return;
      if (!result.success) {
        setState(() {
          _busy = false;
          _error = 'That code did not match. Try again or tap Resend.';
        });
        return;
      }
      // Prefer the userId surfaced on /otp/verify (always populated
      // server-side for purpose=signup). Fall back to the one captured
      // on /otp/send so a verify response without it still works.
      final userId = result.userId ?? _userId;
      if (userId == null || userId.isEmpty) {
        setState(() {
          _busy = false;
          _error = 'Could not start your signup. Please tap Resend.';
        });
        return;
      }
      // GoRouter's `push` returns a Future for any value the destination
      // pops back; the signup chain doesn't pop, so we intentionally
      // discard it.
      unawaited(context.push('/set-pin', extra: {
        'phone': widget.phoneNumber,
        'userId': userId,
      }));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Theme.of(context).cardColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
              vSpace(20),

              // Logo
              Center(
                child: Image.asset(
                  Images.coloredLogo,
                  width: 180.w,
                ),
              ),

              vSpace(40),

              // Title
              Center(
                child: Text(
                  _title,
                  style: TextStyle(
                    fontSize: 28.sp,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),

              vSpace(12),

              // Instruction
              Center(
                child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 17.sp,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      height: 1.5,
                    ),
                    children: [
                      TextSpan(text: _instruction),
                      TextSpan(
                        text: '\n$_maskedPhone',
                        style: TextStyle(
                          color: theme.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              vSpace(32),

              // OTP Input
              OtpInputField(
                length: 6,
                onChanged: (code) {
                  setState(() {
                    _code = code;
                    if (_error != null) _error = null;
                  });
                },
              ),

              vSpace(16),

              // Resend code
              Center(
                child: _resendTimer > 0
                    ? Text(
                        'Resend code in ${_resendTimer ~/ 60}:${(_resendTimer % 60).toString().padLeft(2, '0')}',
                        style: TextStyle(
                          fontSize: 17.sp,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Didn\'t receive the code?',
                            style: TextStyle(
                              fontSize: 17.sp,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                          hSpace(4),
                          TextButton(
                            onPressed: _resendCode,
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'Resend',
                              style: TextStyle(
                                fontSize: 17.sp,
                                color: theme.brightness == Brightness.dark
                                    ? Colors.white
                                    : theme.primaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),

              if (_error != null) ...[
                vSpace(12),
                Text(
                  _error!,
                  style: TextStyle(
                    fontSize: 16.sp,
                    color: const Color(0xFFE74C3C),
                  ),
                ),
              ],

              if (_deliveryInfo != null) ...[
                vSpace(10),
                Text(
                  _deliveryInfo!,
                  style: TextStyle(
                    fontSize: 16.sp,
                    color: const Color(0xFF0F8B8D),
                  ),
                ),
              ],

              vSpace(24),

              // Continue button
              AppElevatedButton(
                title: _busy ? 'Please wait...' : 'Continue',
                onPressed: (!_busy && _code.length == AppConstants.otpLength)
                    ? _verifyCode
                    : null,
              ),

              vSpace(32),

              // How to check code box
              CustomPaint(
                painter: DashedBorderPainter(
                  color: const Color(0xFF00BCD4),
                  strokeWidth: 1.5,
                  dashWidth: 5,
                  dashSpace: 3,
                  borderRadius: 12.r,
                ),
                child: Container(
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F7FA), // Light blue/teal background
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.method == VerificationMethod.call
                            ? 'Check the Code'
                            : 'How to check the Code',
                        style: TextStyle(
                          fontSize: 19.sp,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      vSpace(12),
                      ..._howToCheckSteps.map((step) => Padding(
                            padding: EdgeInsets.only(bottom: 8.h),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '• ',
                                  style: TextStyle(
                                    fontSize: 17.sp,
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    step,
                                    style: TextStyle(
                                      fontSize: 17.sp,
                                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )),
                    ],
                  ),
                ),
              ),

              vSpace(24),

              // Alternative methods
              if (_alternativeMethods.isNotEmpty) ...[
                Center(
                  child: Text(
                    'Or Send Code via',
                    style: TextStyle(
                      fontSize: 17.sp,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
                vSpace(16),
                Row(
                  children: _alternativeMethods
                      .expand((widget) => [
                            Expanded(child: widget),
                            if (widget != _alternativeMethods.last) hSpace(12),
                          ])
                      .toList(),
                ),
              ],

              vSpace(40),
                    ],
                  ),
                ),
              ),

              // Footer - regulatory info (CBN / NDIC) — hidden for now per design.
              // Restore the Row below if/when the licensing copy returns.
              // vSpace(16),
              // Center(
              //   child: Row(
              //     mainAxisAlignment: MainAxisAlignment.center,
              //     children: [
              //       Text('Licensed by CBN', style: TextStyle(fontSize: 16.sp,
              //         color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
              //       hSpace(4),
              //       Container(width: 20.w, height: 20.w,
              //         decoration: BoxDecoration(color: Colors.green.shade100, shape: BoxShape.circle),
              //         child: Center(child: Text('CBN',
              //           style: TextStyle(fontSize: 6.sp, color: Colors.green.shade800, fontWeight: FontWeight.bold)))),
              //       hSpace(8),
              //       Text('|', style: TextStyle(fontSize: 16.sp,
              //         color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4))),
              //       hSpace(8),
              //       Text('Deposits insured by', style: TextStyle(fontSize: 16.sp,
              //         color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
              //       hSpace(4),
              //       Container(width: 40.w, height: 20.w,
              //         decoration: BoxDecoration(color: Colors.blue.shade100, borderRadius: BorderRadius.circular(4.r)),
              //         child: Center(child: Text('NDIC',
              //           style: TextStyle(fontSize: 8.sp, color: Colors.blue.shade800, fontWeight: FontWeight.bold)))),
              //     ],
              //   ),
              // ),
              vSpace(24),
            ],
          ),
        ),
      ),
    );
  }
}

class _MethodButton extends StatelessWidget {
  const _MethodButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 14.h),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).dividerColor,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20.sp,
              color: iconColor ?? Colors.black87,
            ),
            hSpace(8),
            Text(
              label,
              style: TextStyle(
                fontSize: 19.sp,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom painter for dashed border
class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;
  final double borderRadius;

  DashedBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.dashWidth,
    required this.dashSpace,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(borderRadius),
      ));

    final dashPath = _createDashedPath(path, dashWidth, dashSpace);
    canvas.drawPath(dashPath, paint);
  }

  Path _createDashedPath(Path source, double dashWidth, double dashSpace) {
    final Path dest = Path();
    for (final PathMetric metric in source.computeMetrics()) {
      double distance = 0;
      bool draw = true;
      while (distance < metric.length) {
        final double length = draw ? dashWidth : dashSpace;
        if (distance + length > metric.length) {
          if (draw) {
            dest.addPath(
              metric.extractPath(distance, metric.length),
              Offset.zero,
            );
          }
          break;
        }
        if (draw) {
          dest.addPath(
            metric.extractPath(distance, distance + length),
            Offset.zero,
          );
        }
        distance += length;
        draw = !draw;
      }
    }
    return dest;
  }

  @override
  bool shouldRepaint(DashedBorderPainter oldDelegate) => false;
}

