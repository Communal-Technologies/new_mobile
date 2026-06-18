import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_event.dart';
import 'package:communal_mobile/blocs/auth/auth_state.dart';
import 'package:communal_mobile/core/constants/images.dart';
import 'package:communal_mobile/core/widgets/otp_input_field.dart';
import 'package:communal_mobile/core/widgets/app_elevated_button.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:go_router/go_router.dart';

class SetPinScreen extends StatefulWidget {
  const SetPinScreen({
    super.key,
    this.phone,
    this.userId,
  });

  /// Forwarded from the OTP-verify screen so we can hand them off to
  /// [CreatePasswordRequested]. Null when the user navigates here from
  /// outside the signup chain (we redirect back to /signup in that case).
  final String? phone;
  final String? userId;

  @override
  State<SetPinScreen> createState() => _SetPinScreenState();
}

class _SetPinScreenState extends State<SetPinScreen> {
  String _pin = '';
  String _confirmPin = '';
  String? _pinError;
  bool _submitting = false;

  void _validateAndContinue() {
    setState(() {
      _pinError = null;
    });

    if (_pin.isEmpty || _pin.length != 6) {
      setState(() {
        _pinError = 'Please enter a 6-digit PIN';
      });
      return;
    }

    if (_confirmPin.isEmpty || _confirmPin.length != 6) {
      setState(() {
        _pinError = 'Please re-enter your PIN';
      });
      return;
    }

    if (_pin != _confirmPin) {
      setState(() {
        _pinError = 'The first and second PIN do not match';
      });
      return;
    }

    final userId = widget.userId;
    if (userId == null || userId.isEmpty) {
      // Stale or direct-link entry — without a userId we can't call
      // create-account-password. Send them back to the start of the
      // signup chain so the OTP step mints a fresh user id.
      setState(() {
        _pinError = 'Please restart signup from the phone-verification screen.';
      });
      return;
    }

    setState(() => _submitting = true);
    // The bloc owns the network call (createPassword + getUserInfo +
    // emit AuthAuthenticated). We listen via BlocConsumer below for
    // success / failure rather than awaiting here.
    context.read<AuthBloc>().add(
          CreatePasswordRequested(
            userId: userId,
            password: _pin,
            confirmPassword: _confirmPin,
            contact: widget.phone,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    // BlocListener routes the post-create-password transitions so the
    // screen can stay declarative: on AuthAuthenticated the new account
    // is live, advance to the success screen; on AuthFailure surface the
    // backend error inline. AuthLoading is reflected via [_submitting].
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated && _submitting) {
          // The create-password handler emits AuthAuthenticated once
          // the new tokens are persisted and the user fetched. Navigate
          // straight to the success screen — the router gate I added
          // in routes/app_routes.dart will then bounce on to KYC.
          context.go('/account-success');
        } else if (state is AuthFailure && _submitting) {
          setState(() {
            _submitting = false;
            _pinError = state.error;
          });
        }
      },
      child: _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).cardColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _submitting ? null : () => context.pop(),
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
                  'Set your sign in PIN',
                  style: TextStyle(
                    fontSize: 28.sp,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),

              vSpace(12),

              // Subtitle
              Center(
                child: Text(
                  'Set a 6-digit PIN to sign in, for account security.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17.sp,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    height: 1.5,
                  ),
                ),
              ),

              vSpace(32),

              // Create PIN
              Text(
                'Create your PIN',
                style: TextStyle(
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              vSpace(12),
              OtpInputField(
                length: 6,
                onChanged: (code) {
                  setState(() {
                    _pin = code;
                    if (_pinError != null) {
                      _pinError = null;
                    }
                  });
                },
              ),

              vSpace(24),

              // Re-enter PIN
              Text(
                'Re-enter your PIN',
                style: TextStyle(
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              vSpace(12),
              OtpInputField(
                length: 6,
                onChanged: (code) {
                  setState(() {
                    _confirmPin = code;
                    if (_pinError != null) {
                      _pinError = null;
                    }
                  });
                },
              ),

              if (_pinError != null) ...[
                vSpace(8),
                Text(
                  _pinError!,
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 17.sp,
                  ),
                ),
              ],

              vSpace(32),

              // Continue button
              AppElevatedButton(
                title: _submitting ? 'Creating account...' : 'Continue',
                onPressed: _submitting ? null : _validateAndContinue,
              ),

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

