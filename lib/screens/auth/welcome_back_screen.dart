import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:communal_mobile/core/constants/images.dart';
import 'package:communal_mobile/core/widgets/app_elevated_button.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/core/utils/biometric_service.dart';
import 'package:go_router/go_router.dart';

enum SignInMethod { pin, fingerprint, password }

class WelcomeBackScreen extends StatefulWidget {
  const WelcomeBackScreen({
    super.key,
    required this.phoneNumber,
    this.method = SignInMethod.pin,
  });

  final String phoneNumber;
  final SignInMethod method;

  @override
  State<WelcomeBackScreen> createState() => _WelcomeBackScreenState();
}

class _WelcomeBackScreenState extends State<WelcomeBackScreen> {
  final _pinController = TextEditingController();
  String _pin = '';
  bool _isBiometricAvailable = false;
  String _biometricName = 'Fingerprint';

  @override
  void initState() {
    super.initState();
    _checkBiometricAvailability();
  }

  Future<void> _checkBiometricAvailability() async {
    final isAvailable = await BiometricService.isBiometricAvailable();
    final biometricName = await BiometricService.getBiometricName();
    
    if (mounted) {
      setState(() {
        _isBiometricAvailable = isAvailable;
        _biometricName = biometricName;
      });
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  String get _maskedPhone {
    if (widget.phoneNumber.length >= 11) {
      final prefix = widget.phoneNumber.substring(0, 7);
      final suffix = widget.phoneNumber.substring(widget.phoneNumber.length - 4);
      return '$prefix****$suffix';
    }
    return widget.phoneNumber;
  }

  void _onNumberTap(String number) {
    if (_pin.length < 6) {
      setState(() {
        _pin += number;
        _pinController.text = _pin;
      });

      if (_pin.length == 6) {
        _signIn();
      }
    }
  }

  void _onBackspace() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
        _pinController.text = _pin;
      });
    }
  }

  void _signIn() {
    // TODO: Implement actual sign in
    context.go('/home');
  }

  void _switchMethod(SignInMethod method) {
    context.pushReplacement('/welcome-back', extra: {
      'phone': widget.phoneNumber,
      'method': method == SignInMethod.pin
          ? 'pin'
          : method == SignInMethod.fingerprint
              ? 'fingerprint'
              : 'password',
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () => context.pop(),
            ),
          ],
        ),
        leadingWidth: 80.w,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            children: [
              vSpace(10),

              // Logo
              Center(
                child: Image.asset(
                  Images.coloredLogo,
                  width: 130.w,
                ),
              ),

              vSpace(24),

              // Profile picture
              Center(
                child: Container(
                  width: 80.w,
                  height: 80.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey.shade200,
                    image: const DecorationImage(
                      image: AssetImage('assets/images/demo_user.png'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),

              vSpace(16),

              // Welcome back
              Center(
                child: Text(
                  'Welcome Back',
                  style: TextStyle(
                    fontSize: 24.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              ),

              vSpace(6),

              // Phone number
              Center(
                child: Text(
                  _maskedPhone,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: theme.primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              vSpace(32),

              // Content based on sign-in method
              if (widget.method == SignInMethod.fingerprint && _isBiometricAvailable) ...[
                _buildFingerprintContent(theme),
              ] else if (widget.method == SignInMethod.pin) ...[
                _buildPinContent(theme),
              ] else if (widget.method == SignInMethod.fingerprint && !_isBiometricAvailable) ...[
                // If fingerprint was selected but not available, fallback to PIN
                _buildPinContent(theme),
              ],

              vSpace(40),

              // Logout option
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Want to switch account? ',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      context.go('/welcome');
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Logout',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: theme.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              vSpace(24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFingerprintContent(ThemeData theme) {
    return Column(
      children: [
        // Fingerprint icon
        Icon(
          Icons.fingerprint,
          size: 120.sp,
          color: theme.primaryColor,
        ),

        vSpace(40),

        // Sign in with fingerprint button
        AppElevatedButton(
          title: 'Sign in with $_biometricName',
          onPressed: () {
            // TODO: Implement fingerprint auth
            _signIn();
          },
        ),

        vSpace(16),

        // Alternative: PIN
        AppSecondaryButton(
          title: 'Sign in with PIN',
          isDark: false,
          onPressed: () => _switchMethod(SignInMethod.pin),
        ),
      ],
    );
  }

  Widget _buildPinContent(ThemeData theme) {
    return Column(
      children: [
        // PIN input field
        Container(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.grey.shade300,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(6, (index) {
              final hasValue = index < _pin.length;
              return Container(
                width: 16.w,
                height: 16.w,
                margin: EdgeInsets.symmetric(horizontal: 8.w),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hasValue ? theme.primaryColor : Colors.grey.shade300,
                ),
              );
            }),
          ),
        ),

        vSpace(12),

        // Forgot password link
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {
              context.push('/forgot-password');
            },
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Forgot Password?',
              style: TextStyle(
                fontSize: 14.sp,
                color: theme.primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),

        vSpace(24),

        // Numeric keypad
        _buildNumericKeypad(theme),

        vSpace(20),

        // Alternative: Fingerprint (only show if available)
        if (_isBiometricAvailable)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              InkWell(
                onTap: () => _switchMethod(SignInMethod.fingerprint),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.fingerprint,
                      color: theme.primaryColor,
                      size: 24.sp,
                    ),
                    hSpace(8),
                    Text(
                      'Use $_biometricName Instead',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: theme.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildNumericKeypad(ThemeData theme) {
    return Column(
      children: [
        // Row 1: 1, 2, 3
        _buildKeypadRow(['1', '2', '3'], theme),
        vSpace(12),
        // Row 2: 4, 5, 6
        _buildKeypadRow(['4', '5', '6'], theme),
        vSpace(12),
        // Row 3: 7, 8, 9
        _buildKeypadRow(['7', '8', '9'], theme),
        vSpace(12),
        // Row 4: empty, 0, Backspace
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            SizedBox(width: 70.w, height: 70.w), // Empty space
            _buildKeypadButton(
              label: '0',
              onTap: () => _onNumberTap('0'),
              theme: theme,
            ),
            _buildKeypadButton(
              icon: Icons.backspace_outlined,
              onTap: _onBackspace,
              theme: theme,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKeypadRow(List<String> numbers, ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: numbers
          .map((number) => _buildKeypadButton(
                label: number,
                onTap: () => _onNumberTap(number),
                theme: theme,
              ))
          .toList(),
    );
  }

  Widget _buildKeypadButton({
    String? label,
    IconData? icon,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(50.r),
      child: Container(
        width: 70.w,
        height: 70.w,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(50.r),
        ),
        child: Center(
          child: icon != null
              ? Icon(
                  icon,
                  size: 24.sp,
                  color: Colors.black87,
                )
              : Text(
                  label!,
                  style: TextStyle(
                    fontSize: 24.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
        ),
      ),
    );
  }
}

